#!/bin/bash

echo "=== Listing ACRs and Repository Counts ==="
for registry in $(az acr list --query "[].name" --output tsv); do
  repo_count=$(az acr repository list --name $registry --query "length(@)" --output tsv)
  echo "$registry: $repo_count repositories"
done
echo

echo "=== Creating Service Principal ==="
rootmgid=$(az account show --query tenantId --output tsv)
spname="crowdstrike-acr-sp"
sp_output=$(az ad sp create-for-rbac --name $spname --role acrpull --scopes "/providers/Microsoft.Management/managementGroups/$rootmgid")
sp_client_id=$(echo $sp_output | jq -r '.appId')
sp_secret=$(echo $sp_output | jq -r '.password')
echo "Service Principal: $sp_client_id"
echo

read -p "CrowdStrike Client ID: " cs_client_id
read -sp "CrowdStrike Client Secret: " cs_secret
echo

echo "=== Getting CrowdStrike Token ==="
falcon_token=$(curl -s -X POST "https://api.crowdstrike.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$cs_client_id&client_secret=$cs_secret" \
  | jq -r '.access_token')

echo "=== Registering ACRs to CrowdStrike ==="
for registry in $(az acr list --query "[].name" --output tsv); do
  login_server="https://$registry.azurecr.io/"
  
  curl -s -X POST 'https://api.crowdstrike.com/container-security/entities/registries/v1' \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -H "Authorization: bearer $falcon_token" \
    -d "{
      \"type\": \"acr\",
      \"url\": \"$login_server\",
      \"user_defined_alias\": \"$registry\",
      \"credential\": {
        \"details\": {
          \"username\": \"$sp_client_id\",
          \"password\": \"$sp_secret\"
        }
      }
    }" | jq .
  
  echo "Registered: $registry"
done

echo "Done!"