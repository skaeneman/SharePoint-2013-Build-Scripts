﻿<# 
Description: The following PowerShell script will start the claims to windows token service (C2WTS) on servers in the farm.
#>
Start-SPAssignment -Global
Add-PSSnapin "Microsoft.SharePoint.PowerShell" -erroraction SilentlyContinue 

############################ UPDATE THESE VARIABLES BEFORE RUNNING THE SCRIPT #####################################

# list any servers that should have the C2WTS service enabled on it below
$server1 = "XXXXXXXXXX"; $server2 = "XXXXXXXXXXXX"; $server3 = "XXXXXXXXXXXXX"
$server4 = "XXXXXXXXXXX"; $server5 = "XXXXXXXXXXXXX"; $server6 = "XXXXXXXXXX"
$server7 = "XXXXXXXXXXXXX"

# add any server (server1,server2,etc...) into the array to enable the c2wts service on that particular server
$array = @($server1, $server2, $server3, $server4, $server5, $server6, $server7)
############################ DO NOT EDIT ANYTHING BELOW THIS LINE!!!!! ##############################################

####################################################################################################################
# This function will start the C2WTS Service if it is disabled.
####################################################################################################################
Function StartSvcOnServers{
#loops through array of servers and checks to see if service is enabled, if not it starts the service
    foreach ($i in $array)
    {   
        $svc = ( Get-SPServiceInstance -Server $i | Where-Object {$_.TypeName -eq "Claims to Windows Token Service"} )
         if(($svc.status -eq "Disabled") -or ($svc.status -ne "Online"))
         {
            $svc | Start-SPServiceInstance
            Write-Host -ForegroundColor "Cyan" "Enabling service on:" $i.ToString()
            Start-Sleep -Seconds 15  #waits 15 seconds for service to start
         }       
         else {Write-Host -ForegroundColor "red" "The service is already enabled or could not be started on:" $i.ToString()}
         
    }#closes foreach
}#closes StartSvcOnServers

#calls functions
StartSvcOnServers
