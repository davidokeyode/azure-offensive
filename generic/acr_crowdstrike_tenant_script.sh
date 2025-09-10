#!/bin/bash

echo "=== Multi-Subscription ACR CrowdStrike Registration ==="

# Get CrowdStrike credentials once at the beginning
read -p "CrowdStrike Client ID: " cs_client_id
read -sp "CrowdStrike Client Secret: " cs_secret
echo

echo "=== Getting CrowdStrike Token ==="
falcon_token=$(curl -s -X POST "https://api.crowdstrike.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$cs_client_id&client_secret=$cs_secret" \
  | jq -r '.access_token')

if [ "$falcon_token" = "null" ]; then
  echo "Failed to get CrowdStrike token. Check credentials."
  exit 1
fi
echo "Got CrowdStrike token successfully"
echo

echo "=== Creating Service Principal at Root Level ==="
rootmgid=$(az account show --query tenantId --output tsv)
spname="crowdstrike-acr-sp"
sp_output=$(az ad sp create-for-rbac --name $spname --role acrpull --scopes "/providers/Microsoft.Management/managementGroups/$rootmgid")
sp_client_id=$(echo $sp_output | jq -r '.appId')
sp_secret=$(echo $sp_output | jq -r '.password')
echo "Service Principal: $sp_client_id"
echo

# Store current subscription to restore later
original_sub=$(az account show --query id --output tsv)

# Loop through all subscriptions
echo "=== Processing All Subscriptions ==="
for sub in $(az account list --query "[].id" --output tsv); do
  echo "--- Switching to subscription: $sub ---"
  az account set --subscription $sub
  
  sub_name=$(az account show --query name --output tsv)
  echo "Subscription: $sub_name"
  
  # Check if there are any ACRs in this subscription
  registries=$(az acr list --query "[].name" --output tsv)
  
  if [ -z "$registries" ]; then
    echo "No ACRs found in this subscription"
    echo
    continue
  fi
  
  echo "Found ACRs:"
  for registry in $registries; do
    repo_count=$(az acr repository list --name $registry --query "length(@)" --output tsv 2>/dev/null || echo "0")
    echo "  $registry: $repo_count repositories"
    
    # Register to CrowdStrike
    login_server="https://$registry.azurecr.io/"
    
    response=$(curl -s -X POST 'https://api.crowdstrike.com/container-security/entities/registries/v1' \
      -H 'Accept: application/json' \
      -H 'Content-Type: application/json' \
      -H "Authorization: bearer $falcon_token" \
      -d "{
        \"type\": \"acr\",
        \"url\": \"$login_server\",
        \"user_defined_alias\": \"$registry-$sub_name\",
        \"credential\": {
          \"details\": {
            \"username\": \"$sp_client_id\",
            \"password\": \"$sp_secret\"
          }
        }
      }")
    
    # Check if registration was successful
    if echo "$response" | jq -e '.resources[0].id' > /dev/null 2>&1; then
      echo "  ✓ Registered: $registry"
    else
      echo "  ✗ Failed to register: $registry"
      echo "    Error: $(echo $response | jq -r '.errors[0].message // "Unknown error"')"
    fi
  done
  echo
done

# Restore original subscription
az account set --subscription $original_sub
echo "=== Completed! Restored to original subscription ==="