﻿# Description: This PowerShell script will create 7 managed accounts for your farm.

############################## UPDATE FOR YOUR FARM ########################################
$excelAcct = "domain\account"
$excelPass = "pass"

$appPoolAcct = "" 
$appPoolPass = ""

$crawlAcct = "" 
$crawlPass = ""

$mysitesAcct = "" 
$mysitesPass = ""

$svcAppPoolAcct = "" 
$svcAppPoolPass = ""

$searchAcct = "" 
$searchPass = ""

$userProfileAcct = "" 
$userProfilePass = ""
############################## DO NOT EDIT ANYTHING BELOW THIS LINE ########################

Add-PSSnapin Microsoft.SharePoint.PowerShell -erroraction SilentlyContinue 

<# credentials must be converted to a secureString in order to pass the credentials to New-SpManagedAccount #>

# excel account
$excelSecurePass = ConvertTo-SecureString -String $excelPass -AsPlainText -force
$excelCredentials = New-Object System.Management.Automation.PSCredential($excelAcct, $excelSecurePass)

# application pool account
$appPoolSecurePass = ConvertTo-SecureString -String $appPoolPass -AsPlainText -force
$appPoolCredentials = New-Object System.Management.Automation.PSCredential($appPoolAcct, $appPoolSecurePass)

# crawl account
$crawlSecurePass = ConvertTo-SecureString -String $crawlPass -AsPlainText -force
$crawlCredentials = New-Object System.Management.Automation.PSCredential($crawlAcct, $crawlSecurePass)

# mysites account
$mysitesSecurePass = ConvertTo-SecureString -String $mysitesPass -AsPlainText -force
$mysitesCredentials = New-Object System.Management.Automation.PSCredential($mysitesAcct, $mysitesSecurePass)

# application pool accpount for service application
$svcAppPoolSecurePass = ConvertTo-SecureString -String $svcAppPoolPass -AsPlainText -force
$svcAppPoolCredentials = New-Object System.Management.Automation.PSCredential($svcAppPoolAcct, $svcAppPoolSecurePass)

# search account
$searchSecurePass = ConvertTo-SecureString -String $searchPass -AsPlainText -force
$searchCredentials = New-Object System.Management.Automation.PSCredential($searchAcct, $searchSecurePass)

#user profiel account
$userProfileSecurePass = ConvertTo-SecureString -String $userProfilePass -AsPlainText -force
$userProfileCredentials = New-Object System.Management.Automation.PSCredential($userProfileAcct, $userProfileSecurePass)

#creates an array and loops through to create the managed accounts
$a = @($excelCredentials, $appPoolCredentials, $crawlCredentials, $mysitesCredentials, $svcAppPoolCredentials, $searchCredentials, $userProfileCredentials)
foreach ($i in $a){

$managedAccount = New-SpManagedAccount -Credential $i -ea SilentlyContinue
if ($managedAccount -eq $null)
{
    Write-Host "Account failed to register, or it may have already been added as a managed account." 
    $skip = $true
}
        else {Write-Host "Account added"}
        
}
        
   
