# Description: This PowerShell script will create 4 application pools 
# (Search, Secure Store, all Service Applications, and the Web Applications)

Start-SPAssignment -Global
############################## UPDATE FOR YOUR FARM ########################################
$searchAppPoolName = "SharePoint - Search"
$searchAppPoolAccount = "xxxxxx\xxxxxx_SEARCH"
$secureStoreAppPoolName = "SharePoint - Secure Store"
$secureStoreAppPoolAccount = "xxxxx\xxxxxxx_SECURESTORE"
$svcAppPoolName = "SharePoint - Service Applications"
$svcAppPoolAccount = "xxxxxxx\xxxxxx_SERVICEAPP"
$webAppPoolName = "SharePoint - Web Applications"
$webAppPoolAccount = "xxxxx\xxxxxx_APP"
############################## DO NOT EDIT ANYTHING BELOW THIS LINE ########################

Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue 

try{
    # Creates search service application pool
    New-SPServiceApplicationPool -Name $searchAppPoolName -Account $searchAppPoolAccount

    # Creates secure store service application pool
    New-SPServiceApplicationPool -Name $secureStoreAppPoolName -Account $secureStoreAppPoolAccount
    
    # Creates an app pool to be used for all service apps
    New-SPServiceApplicationPool -Name $svcAppPoolName -Account $svcAppPoolAccount

    # Creates an app pool to be used for all web apps
    New-SPServiceApplicationPool -Name $webAppPoolName -Account $webAppPoolAccount
    
}# ends try
    catch [system.exception]
    {
        $($_.Exception.Message)
    } 
    
Stop-SPAssignment -Global 