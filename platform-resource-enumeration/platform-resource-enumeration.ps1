## Create Storage account with SAS token
$group = "offensivesec-rg"
$location = "uksouth"
az group create --name $group --location $location

$name = Read-Host "Please enter a basename"
$container1 = "private"
$container2 = "public"
$container3 = "archived"

git clone https://github.com/microsoft/Windows-universal-samples.git
wget https://raw.githubusercontent.com/davidokeyode/azure-offensive/master/sensitive_customer_private_information.csv

az storage account create --name $name --resource-group $group --location $location --sku Standard_LRS --allow-blob-public-access true --https-only false

az storage container create --account-name $name --name $container1 --public-access container
az storage container create --account-name $name --name $container2 --public-access container
az storage container create --account-name $name --name $container3 --public-access container

az storage blob upload-batch --account-name $name -d $container3 -s Windows-universal-samples/SharedContent
az storage blob upload-batch --account-name $name -d $container2 -s Windows-universal-samples/archived/CameraFaceDetection
az storage blob upload --account-name $name --container-name $container1 --name sensitive_customer_private_information.csv --file sensitive_customer_private_information.csv 


## App Service
$gitrepo = "https://github.com/Azure-Samples/php-docs-hello-world"

# Create a resource group.
az group create --location $location --name $group

# Create an App Service plan in `FREE` tier.
az appservice plan create --name $name --resource-group $group --sku FREE

# Create a web app.
az webapp create --name $name --resource-group $group --plan $name

# Deploy code from a public GitHub repository. 
az webapp deployment source config --name $name --resource-group $group --repo-url $gitrepo --branch master --manual-integration

## Key Vault
az keyvault create --name $name --resource-group $group --location $location

## Container Registry
az acr create --resource-group $group --name $name --sku Basic

## Function App
az functionapp create -g $group  -p $name -n $name -s $name

echo "Created Storage Account:" $storagename1
echo "Created Blob Container:" $container1
echo "Created Blob Container:" $container2
echo "Created Blob Container:" $container3
echo "Created Web App:" http://$name.azurewebsites.net
echo "Created Key Vault:" http://$name.vault.azure.net
echo "Created Container Registry:" $name.azurecr.io




