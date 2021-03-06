###################################################################################################################################
# Creates the Secure Store Service Application using PowerShell in SharePoint 2013. 
# Note: DO NOT USE THE FQDN OF THE SERVER IN THE XML FILE, JUST USE THE SERVER NAME ONLY (ex "sandox" not "sandbox.domain.com")
# IMPORTANT: Run this script logged into the server as the farm admin service account, not your user account.
###################################################################################################################################

#allows "-XmlFilePath" to be passed as a parameter in the shell (must be first line in script)
param([Parameter(Mandatory=$true, Position=0)]
      [ValidateNotNullOrEmpty()]
	  [string]$XmlFilePath)

#loads PowerShell cmdlets for SharePoint
Write-Host -ForegroundColor Cyan "Enabling SharePoint PowerShell cmdlets..."
If ((Get-PsSnapin |?{$_.Name -eq "Microsoft.SharePoint.PowerShell"})-eq $null)
{
	Add-PsSnapin Microsoft.SharePoint.PowerShell | Out-Null
}
Start-SPAssignment -Global | Out-Null

#loads XML config file that user entered
[xml]$configFile = Get-Content $XmlFilePath
$xmlConfig = @($configFile.SecureStore.ServiceApplication)

#maps XML tags with variable names
$serviceApplicationName = $xmlConfig.ServiceApplicationName
$startServicesOnServer = @($xmlConfig.StartServicesOnServer.Server)
$appPoolName = $xmlConfig.AppPoolName
$appPoolAccount = $xmlConfig.AppPoolAccount
$databaseName = $xmlConfig.DatabaseName
$databaseServer = $xmlConfig.DatabaseServer
$secureStorePassPhrase = $xmlConfig.SecureStorePassPhrase

$serviceName = "Secure Store Service"
$secureStoreAppProxyName = "$ServiceApplicationName Proxy"

########################################################
# Checks for existing service app and app pool
########################################################
try
{
    #Checks for an existing service application
	Write-Host -ForegroundColor Cyan "Checking for existing Service Application called: $serviceApplicationName"
    $ExistingServiceApp = Get-SPServiceApplication | where-object {$_.Name -eq $serviceApplicationName}

	if ($ExistingServiceApp -ne $null)
	{
        Write-Host -ForegroundColor Red "'$ServiceApplicationName' already exists, stopping script!";break
    }
	else
    {			
		#tries to get managed account, script will error if one doesn't exist	
		$managedAccount = Get-SPManagedAccount -Identity $appPoolAccount
		
		#Checks if the application pool already exists, if not it creates one
        $applicationPool = Get-SPServiceApplicationPool -Identity $appPoolName -ErrorAction SilentlyContinue
        if ($applicationPool -eq $null)
        {
			Write-Host -ForegroundColor Cyan "The application pool '$appPoolName' does not exist, creating it"
        	New-SPServiceApplicationPool -Name $appPoolName -Account $managedAccount | Out-Null
			Start-Sleep 60
        }
	
	#####################################
	# Creates the service application  
	#####################################
	
	Write-Host -ForegroundColor Cyan "Creating the '$ServiceApplicationName' Service Application"
	try
	 {	
		$ssSvcApp = New-SPSecureStoreServiceapplication -Name $ServiceApplicationName `
		-Sharing:$false `
		-DatabaseServer $DatabaseServer `
		-DatabaseName $databaseName `
		-ApplicationPool $appPoolName `
		-auditingEnabled:$true `
		-auditlogmaxsize 30 
		Start-Sleep 30
     }
	 catch [system.Exception]{
		$errorMessage = $_.Exception.Message
		Write-Host -ForegroundColor Red "Could not create the service application." $errorMessage
	 }	
	 
	############################################# 
	# Creates the service application proxy 
	#############################################
	try{	
        Write-Host -ForegroundColor Cyan "Creating '$secureStoreAppProxyName'"
		
	    #need to get the svc application in order to create app proxy
	    $ssSvcApp = Get-SPServiceApplication | Where-Object {$_.Name -eq $ServiceApplicationName}
	    
		 #tries to get the service app proxy to see if it already exists
	     $ssSvcAppProxy = Get-SPServiceApplicationProxy | Where-Object {$_.Name -eq $secureStoreAppProxyName}
		 
		 #if proxy doesn't exist it creates the proxy
	     if ($ssSvcAppProxy -eq $null)
	     {
	        $ssSvcAppProxy = New-SPSecureStoreServiceApplicationProxy `
	        -ServiceApplication $ssSvcApp `
	        -Name $secureStoreAppProxyName `
	        -DefaultProxyGroup
			
	         #waits 60 seconds before generating the Secure Store Key
	         Start-Sleep -Seconds 60
	     }
	     else {Write-Host -ForegroundColor "Red" "The proxy $secureStoreAppProxyName already exists..."}
     }#ends try
	 catch [system.Exception]{
		$errorMessage = $_.Exception.Message
		Write-Host -ForegroundColor Red "Could not create the service application proxy." $errorMessage
	 }	
	 	 
	############################################ 
	# Starts service instances
	############################################
	try{
        Write-Host -ForegroundColor Cyan "Starting service instances on servers"
		
        foreach ($server in $startServicesOnServer) 
        {					
            #Gets the service to determine its status
            $service = $(Get-SPServiceInstance | where {$_.TypeName -match $serviceName} | where {$_.Server -match "SPServer Name="+$server.name})
            
            If (($service.Status -eq "Disabled") -or ($service.status -ne "Online")) 
            {
               	Write-Host -ForegroundColor Cyan "Starting" $service.Service "on" $server.name
                Start-SPServiceInstance -Identity $service.ID | Out-Null
            }
			else {Write-Host -ForegroundColor red $service.Service "is already enabled or could not be started on" $server.name}
        }#ends foreach
			Start-Sleep 10
	}#ends try
		
	catch [system.Exception]
	{
			$errorMessage = $_.Exception.Message
			write-host -ForegroundColor Red "Couldn't start services on servers." $errorMessage
	}
             
	}#ends first else
}#ends try
catch [system.Exception]
{
	$errorMessage = $_.Exception.Message
	$errorMessage
}
 
##################################################
#  Generates the Secure Store Service Key
##################################################
Start-Sleep 10
Write-Host -ForegroundColor "Cyan" "Generating the Secure Store Key."
#grabs the svc app proxy
$appProxy = Get-SPServiceApplicationProxy | Where-Object {$_.Name -eq $secureStoreAppProxyName}
#passes proxy and secure store passphrase
Update-SPSecureStoreMasterKey -ServiceApplicationProxy $appProxy -Passphrase $secureStorePassPhrase
#creates a loop that try's to update the key every 5 sec until successfull. has issues not updating on first try.
    while($true){
        try{
        Start-Sleep -Seconds 5
        Update-SPSecureStoreApplicationServerKey -ServiceApplicationProxy $appProxy -Passphrase $secureStorePassPhrase
    break
   }#ends try
   catch { }
 }#ends while
 
 Stop-SPAssignment -Global | Out-Null