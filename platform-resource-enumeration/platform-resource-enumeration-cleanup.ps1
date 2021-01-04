## Delete Resource Group
$group = "offensivesec-rg"
Write-Host -ForegroundColor Green "Removing the resource group $group"
az group delete -n $group -y