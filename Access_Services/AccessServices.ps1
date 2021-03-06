#Creates the SP2013 Access Services Application. 
#Note: DO NOT USE THE FQDN OF THE SERVER IN THE XML FILE, JUST USE THE SERVER NAME ONLY (ex "sandox" not "sandbox.domain.com").

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
$xmlConfig = @($configFile.AccessServices.ServiceApplication)

#maps XML tags with variable names
$serviceApplicationName = $xmlConfig.ServiceApplicationName
$serversToActivate = @($xmlConfig.StartServicesOnServer.Server)
$appPoolName = $xmlConfig.AppPoolName
$appPoolAccount = $xmlConfig.AppPoolAccount

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
			Write-Host -ForegroundColor Cyan "the application pool '$appPoolName' does not exist, creating it"
        	New-SPServiceApplicationPool -Name $appPoolName -Account $managedAccount | Out-Null
        }    
			
	#creates the service application    
	Write-Host -ForegroundColor Cyan "Creating the '$ServiceApplicationName' Service Application"
	try
	 {	
		#Proxy gets created automatically by the Service App
        New-SPAccessServiceApplication -Name $serviceApplicationName -ApplicationPool $appPoolName | Out-Null
     }
	 catch [system.Exception]{
		$errorMessage = $_.Exception.Message
		Write-Host -ForegroundColor Red "Could not create the service application." $errorMessage
	 }	
	 
	try{
        #Starts service instances
        Write-Host -ForegroundColor Cyan "Starting service instances on servers"
		$serviceName = "Access Services"
		
        foreach ($server in $serversToActivate) 
        {					
            #Gets the service to determine its status
            $service = $(Get-SPServiceInstance | where {$_.TypeName -match $serviceName} | where {$_.Server -match "SPServer Name="+$server.name})
            
            If (($service.Status -eq "Disabled") -or ($service.status -ne "Online")) 
            {
               	Write-Host -ForegroundColor Cyan "Starting" $service.Service "on" $server.name
                Start-SPServiceInstance -Identity $service.ID | Out-Null
            }
			else {Write-Host -ForegroundColor red $service.ID "is already enabled or could not be started on $server"}
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