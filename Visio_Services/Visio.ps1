################################################################################################################################
# Creates the SharePoint 2013 Visio Service Application. 
# Note: DO NOT USE THE FQDN OF THE SERVER IN THE XML FILE, JUST USE THE SERVER NAME ONLY (ex "sandox" not "sandbox.domain.com").
# Note: In order to make SCOM (SCCM) 2010/2012 work this service app must be called "Visio Services Service Application" 
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
$xmlConfig = @($configFile.Visio.ServiceApplication)

#maps XML tags with variable names
$serviceApplicationName = $xmlConfig.ServiceApplicationName
$startServicesOnServers = @($xmlConfig.StartServicesOnServer.Server)
$appPoolName = $xmlConfig.AppPoolName
$appPoolAccount = $xmlConfig.AppPoolAccount
$farmAccount = $xmlConfig.SecureStoreTarget.FarmAccount #SP2013 farm admin account (domain\user)
$unattendedSvcAcct = $xmlConfig.SecureStoreTarget.UnattendedServiceAccount  #secure store unattended service account to be used for excel services
$unattendedSvcPass = $xmlConfig.SecureStoreTarget.UnattendedServiceAccountPassword #password for the secure store unattended service account
$targetAppEmail = $xmlConfig.SecureStoreTarget.TargetApplicationEmail  #email address to be used for secure store target application
$serviceName = "Visio Graphics Service"

#############################################################
# Checks for an existing service application and app pool
#############################################################
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
			Write-Host -ForegroundColor Cyan "The application pool '$appPoolName' does not exist, creating it"
        	New-SPServiceApplicationPool -Name $appPoolName -Account $managedAccount | Out-Null
			Start-Sleep 30
        }
    
	#######################################		
	# Creates the service application.      
	#######################################
	try{
	
	    #gets service app
        try{
            $svcApp = Get-SPVisioServiceApplication $serviceApplicationName -ErrorAction SilentlyContinue
        }catch { }

        #creates the Visio service app if it doesn't exist  
        if($svcApp -eq $null)
        {
		try{ 
			Write-Host -ForegroundColor Cyan "Creating the '$serviceApplicationName' Service Application"
            $visioSvcApp = New-SPVisioServiceApplication `
                           -ApplicationPool $appPoolName `
                           -Name $serviceApplicationName
            				Start-Sleep 15
			
			Write-Host -ForegroundColor Cyan "Creating the '$serviceApplicationName' Proxy"
			$visioSvcAppProxy = New-SPVisioServiceApplicationProxy `
			-Name "$ServiceApplicationName Proxy" `
			-ServiceApplication $ServiceApplicationName
			Start-Sleep 10
		
		}#ends try
	 catch [system.Exception]
	 {
		$errorMessage = $_.Exception.Message
		Write-Host -ForegroundColor Red "Could not create the service application." $errorMessage
	 }		
												
         ####################################################
         # Configure Visio performance
         ####################################################
         Write-Host -ForegroundColor Cyan "Configuring the Visio Service Application"
         $visioSvcApp | Set-SPVisioPerformance -MaxCacheSize 5120 `
		 				-MaxRecalcDuration 60 -MaxDiagramCacheAge 60 `
                        -MaxDiagramSize 5 -MinDiagramCacheAge 5        
         				Start-Sleep -Seconds 30                                                    
                     
        }#ends if
        else {Write-Host -ForegroundColor Red "'$ServiceApplicationName' is aready enabled"}
		
	 }#ends try
	 catch [system.Exception]
	 {
		$errorMessage = $_.Exception.Message
		Write-Host -ForegroundColor Red "Could not create the service application." $errorMessage
	 }	
	 
	##############################################
	# Starts service instances on servers in farm
	##############################################
	try{
        Write-Host -ForegroundColor Cyan "Starting service instances on servers"
		
        foreach ($server in $startServicesOnServers) 
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
	}#ends try
		
	catch [system.Exception]
	{
			$errorMessage = $_.Exception.Message
			write-host -ForegroundColor Red "Couldn't start services on servers." $errorMessage
	}
             
	}#ends first else
}#ends first try
catch [system.Exception]
{
	$errorMessage = $_.Exception.Message
	$errorMessage
}
 
##########################################################
# Creates the Secure Store target application for Visio
##########################################################
try{
#Get the Visio Service App
$svcApp = Get-SPServiceApplication | where {$_.TypeName -like "*Visio*"}
#Get the existing unattended account app ID
$unattendedServiceAccountApplicationID = ($svcApp | Get-SPVisioExternalData).UnattendedServiceAccountApplicationID

#If the account isn't already set then set it
if ([string]::IsNullOrEmpty($unattendedServiceAccountApplicationID)) { 
    #Get our credentials
    $unattendedSvcAcctSecure = ConvertTo-SecureString -String $unattendedSvcAcct -AsPlainText -force 
    $unattendedSvcPassSecure = ConvertTo-SecureString -String $unattendedSvcPass -AsPlainText -force 
    $unattendedAccount = New-Object -TypeName System.Management.Automation.PSCredential($unattendedSvcAcctSecure, $unattendedSvcPassSecure)
    
    #Set the Target App Name and create the Target App
    $name = "$($svcApp.DisplayName) - UnattendedAccount"
    Write-Host -ForegroundColor Cyan "Creating Secure Store Target Application $name..."
    $secureStoreTargetApp = New-SPSecureStoreTargetApplication -Name $name `
        -FriendlyName "Visio Services Target Application" -ContactEmail $targetAppEmail `
        -ApplicationType Group -TimeoutInMinutes 3

    #Set the group claim and admin principals
    $groupClaim = New-SPClaimsPrincipal -Identity "nt authority\authenticated users" -IdentityType WindowsSamAccountName
    $adminPrincipal = New-SPClaimsPrincipal -Identity $farmAccount -IdentityType WindowsSamAccountName

    #Set the account fields
    $usernameField = New-SPSecureStoreApplicationField -Name "User Name" -Type WindowsUserName -Masked:$false
    $passwordField = New-SPSecureStoreApplicationField -Name "Password" -Type WindowsPassword -Masked:$true
    $fields = $usernameField, $passwordField

    #Set the field values
    $secureUserName = ConvertTo-SecureString $unattendedAccount.UserName -AsPlainText -Force
    $securePassword = $unattendedAccount.Password
    $credentialValues = $secureUserName, $securePassword

    #Get the service context
    $subId = [Microsoft.SharePoint.SPSiteSubscriptionIdentifier]::Default
    $context = [Microsoft.SharePoint.SPServiceContext]::GetContext($svcApp.ServiceApplicationProxyGroup, $subId)

    #Check to see if the Secure Store App already exists
    $secureStoreApp = Get-SPSecureStoreApplication -ServiceContext $context -Name $name -ErrorAction SilentlyContinue
    if ($secureStoreApp -eq $null) {
        #Doesn't exist so create.
        Write-Host -ForegroundColor Cyan "Creating Secure Store Application for Visio..."
        $secureStoreApp = New-SPSecureStoreApplication -ServiceContext $context `
            -TargetApplication $secureStoreTargetApp `
            -Administrator $adminPrincipal `
            -CredentialsOwnerGroup $groupClaim `
            -Fields $fields
    }
    #Update the field values
    Write-Host -ForegroundColor Cyan "Updating Secure Store Group Credential Mapping for Visio..."
    Update-SPSecureStoreGroupCredentialMapping -Identity $secureStoreApp -Values $credentialValues

    #Set the unattended service account application ID
    $svcApp | Set-SPVisioExternalData -UnattendedServiceAccountApplicationID $name
}
}#ends try
catch [system.exception]
{ 
	$($_.Exception.Message) 
} 

Stop-SPAssignment -Global | Out-Null