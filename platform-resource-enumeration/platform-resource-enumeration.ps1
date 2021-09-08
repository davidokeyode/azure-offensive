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

## Set variables and create resource group
$random = Get-Random -Maximum 100000 -Minimum 10000
$customappname = "customapp"
$containerappname = "containerapp"

az group create --name $group --location $location

## obtain subscription id
$subid=$(az account show --query id --output tsv)

## create service principals with contributor permissions
$customapp=$(az ad sp create-for-rbac -n $customappname --role Reader --scopes /subscriptions/$subid)
$containerapp=$(az ad sp create-for-rbac -n $containerappname --role Reader --scopes /subscriptions/$subid)

## Get the app id and user id
$customappid=$(az ad app list --display-name $customappname --query [].appId -o tsv)
$containerappid=$(echo $containerapp | jq -r .appId)
$containerappsecret=$(echo $containerapp | jq -r .password)
$tenantid=$(echo $containerapp | jq -r .tenant)

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

## Container registry and import container images
az acr create --resource-group $group --name $name --sku Standard
az acr update --name $name --anonymous-pull-enabled
az acr import -n $name --source docker.io/library/nginx:latest -t littlecloudnginx:v1
az acr import -n $name --source docker.io/library/nginx:latest -t littlecloudnginx:v2
az acr import -n $name --source docker.io/library/nginx:latest -t littlecloudnginx:v3
az acr import -n $name --source docker.io/library/nginx:latest -t littlecloudnginx:v4
az acr import -n $name --source docker.io/library/nginx:latest -t littlecloudnginx:v1
az acr import -n $name --source docker.io/library/nginx:latest -t littlecloudnginx:v1

Invoke-WebRequest -Uri https://raw.githubusercontent.com/PacktPublishing/Penetration-Testing-Azure-for-Ethical-Hackers/main/chapter-4/resources/Dockerfile -OutFile Dockerfile

## Modify Docker file
sed -i 's/"$containerappid"/"'"$containerappid"'"/' Dockerfile
sed -i 's/"$containerappsecret"/"'"$containerappsecret"'"/' Dockerfile
sed -i 's/"$tenantid"/"'"$tenantid"'"/' Dockerfile

az acr build --resource-group $group --registry $acrname --image nodeapp-web:v1 .

## Function App
az functionapp create -g $group  -p $name -n $name -s $name

echo "Created Storage Account:" $storagename1
echo "Created Blob Container:" $container1
echo "Created Blob Container:" $container2
echo "Created Blob Container:" $container3
echo "Created Web App:" http://$name.azurewebsites.net
echo "Created Key Vault:" http://$name.vault.azure.net
echo "Created Container Registry:" $name.azurecr.io




