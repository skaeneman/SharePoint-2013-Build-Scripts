################################################################################################################################
# Creates the SharePoint 2013 Managed Metadata Service Application. 
# Note: DO NOT USE THE FQDN OF THE SERVER IN THE XML FILE, JUST USE THE SERVER NAME ONLY (ex "sandox" not "sandbox.domain.com")
#################################################################################################################################

#allows "-XmlFilePath" to be passed as a parameter in the shell (must be first line in script)
param([Parameter(Mandatory=$true, Position=0)]
      [ValidateNotNullOrEmpty()]
	  [string]$XmlFilePath)

#loads PowerShell cmdlets for SharePoint
Write-Host -ForegroundColor Cyan "Enabling SharePoint PowerShell cmdlets..."
Add-PsSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue

Start-SPAssignment -Global | Out-Null

#loads XML config file that user entered
[xml]$configFile = Get-Content $XmlFilePath
$xmlConfig = @($configFile.ManagedMetadata.ServiceApplication)

#maps XML tags with variable names
$serviceApplicationName = $xmlConfig.ServiceApplicationName
$serversToActivate = @($xmlConfig.StartServicesOnServer.Server)
$databaseName = $xmlConfig.DatabaseName
$databaseServer = $xmlConfig.DatabaseServer
$appPoolName = $xmlConfig.AppPoolName
$appPoolAccount = $xmlConfig.AppPoolAccount
$serviceName = "Managed Metadata Web Service"

##############################################
# Checks for an existing service application
##############################################
try
{
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
			Write-Host -ForegroundColor Cyan "the application pool '$appPoolName' does not exist, creating it"
        	New-SPServiceApplicationPool -Name $appPoolName -Account $managedAccount | Out-Null
        }
    
	############################################		
	# Creates the service application    
	############################################
	Write-Host -ForegroundColor Cyan "Creating the '$ServiceApplicationName' Service Application"
	try{	
	 	$serviceApp = New-SPMetadataServiceApplication `
		-Name $ServiceApplicationName `
		-ApplicationPool $appPoolName `
		-DatabaseServer $databaseServer `
		-DatabaseName $databaseName
		 Start-Sleep 5	 
	 }
	 catch [system.Exception]
	 {
		$errorMessage = $_.Exception.Message
		Write-Host -ForegroundColor Red "Could not create the service application." $errorMessage
	 }	
	 
	############################################# 
	# Creates the service application proxy 
	#############################################
	try{	
        Write-Host -ForegroundColor Cyan "Creating '$ServiceApplicationName' proxy"
        $serviceAppProxy = New-SPMetadataServiceApplicationProxy `
		-name "$ServiceApplicationName Proxy" `
		-ServiceApplication $serviceApp	`
		-DefaultProxyGroup	
     }
	 catch [system.Exception]{
		$errorMessage = $_.Exception.Message
		Write-Host -ForegroundColor Red "Could not create the service application proxy." $errorMessage
	 }	
	 
	#################################################
	# Starts service instances on servers in farm
	#################################################
	try{
        Write-Host -ForegroundColor Cyan "Starting service instances on servers"
		
        foreach ($server in $serversToActivate) 
        {					
            #Gets the service to determine its status
            $service = $(Get-SPServiceInstance | where {$_.TypeName -match $serviceName} | where {$_.Server -match "SPServer Name="+$server.name})
            
            If (($service.Status -eq "Disabled") -or ($service.Status -ne "Online")) 
            {
               	Write-Host -ForegroundColor Cyan "Starting" $service.Service "on" $server.Name
                Start-SPServiceInstance -Identity $service.ID | Out-Null
            }
			else {Write-Host -ForegroundColor red $service.Service "is already enabled or could not be started on" $server.Name}
        }#ends foreach
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
 
 Stop-SPAssignment -Global | Out-Null