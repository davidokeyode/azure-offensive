# Connect to Azure (allowing output to help with login issues)
Write-Host "Connecting to Azure..." -ForegroundColor Yellow
$loginResult = Connect-AzAccount -WarningAction SilentlyContinue
if ($loginResult) {
    Write-Host "Successfully connected to Azure!" -ForegroundColor Green
} else {
    Write-Host "Failed to connect to Azure" -ForegroundColor Red
    exit 1
}

# Get the current user context
$currentUser = (Get-AzContext).Account.Id
Write-Host "Connected as: $currentUser" -ForegroundColor Green

Write-Host "`n=== Checking All Subscriptions for Permissions and Activity Logs ===" -ForegroundColor Cyan

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Initialize result array
$results = @()

foreach ($subscription in $subscriptions) {
    # Set the active subscription
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null

    # Check if the user has Owner role
    $roleAssignments = Get-AzRoleAssignment -SignInName $currentUser -Scope "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
    $isOwner = $false  # Default to false

    # Only check for "Owner" role, output True or False
    if ($roleAssignments) {
        $isOwner = $roleAssignments | Where-Object { $_.RoleDefinitionName -eq "Owner" } | Select-Object -First 1
        if ($isOwner) {
            $isOwner = $true
        } else {
            $isOwner = $false
        }
    }

    # Get Activity Log Export Configurations
    $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId "/subscriptions/$($subscription.Id)" -ErrorAction SilentlyContinue
    $logCount = if ($diagnosticSettings) { ($diagnosticSettings | Measure-Object).Count } else { 0 }

    # Add results to array
    $results += [PSCustomObject]@{
        SubscriptionName      = $subscription.Name
        SubscriptionId        = $subscription.Id
        IsOwner              = $isOwner
        ActivityLogsExported = $logCount
    }
}

# Global Admin Check via Microsoft Graph API
$isGlobalAdmin = $false
$globalAdminRoleName = "Global Administrator"  # The display name of the Global Admin role

try {
    # Get an access token for Microsoft Graph API, suppressing warnings
    $token = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -WarningAction SilentlyContinue).Token

    # Set the request headers
    $headers = @{
        "Authorization" = "Bearer $token"
    }

    # Query Microsoft Graph API for user's group memberships
    $uri = "https://graph.microsoft.com/v1.0/me/memberOf"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get

    # Check if the user is a member of the Global Administrator role
    $globalAdminRole = $response.value | Where-Object { $_.displayName -eq $globalAdminRoleName }

    if ($globalAdminRole) {
        $isGlobalAdmin = $true
    }
} catch {
    Write-Host "Error checking Global Administrator status via Microsoft Graph: $_" -ForegroundColor Red
}

# Function to apply color to the 'True' isOwner values
function Get-ColoredOwner {
    param (
        [bool]$isOwner
    )

    if ($isOwner) {
        return "$($PSStyle::Foreground.Green)True$($PSStyle::Reset)"
    } else {
        return "False"
    }
}

# Output Results in Table Format with colored isOwner field inside the table
$results | ForEach-Object {
    $coloredOwner = Get-ColoredOwner -isOwner $_.IsOwner

    # Construct the final object with coloring logic
    [PSCustomObject]@{
        SubscriptionName      = $_.SubscriptionName
        SubscriptionId        = $_.SubscriptionId
        ActivityLogsExported  = $_.ActivityLogsExported
        isOwner               = $coloredOwner
    }
} | Format-Table -Property SubscriptionName, SubscriptionId, ActivityLogsExported, isOwner

# Output Global Admin status in color (green or red)
$globalAdminColor = if ($isGlobalAdmin) { "Green" } else { "Red" }
Write-Host "Global Administrator Status: $($isGlobalAdmin)" -ForegroundColor $globalAdminColor

# Now proceed with App Service Plan P0V3 quota checking
Write-Host "`n=== App Service Plan P0V3 Quota Checking ===" -ForegroundColor Cyan

# Show available subscriptions for reference
Write-Host "`nAvailable Subscriptions:" -ForegroundColor Yellow
$results | ForEach-Object {
    $ownerStatus = if ($_.IsOwner) { " (Owner)" } else { "" }
    Write-Host "  $($_.SubscriptionName) - $($_.SubscriptionId)$ownerStatus" -ForegroundColor White
}

# Prompt for subscription ID
Write-Host ""
$subscriptionId = Read-Host "Enter the Subscription ID for quota checking"

# Validate subscription ID format (basic GUID validation)
if (-not ($subscriptionId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
    Write-Host "Invalid subscription ID format. Please enter a valid GUID." -ForegroundColor Red
    exit 1
}

# Check if the provided subscription ID is in our list
$selectedSubscription = $results | Where-Object { $_.SubscriptionId -eq $subscriptionId }
if (-not $selectedSubscription) {
    Write-Host "Warning: The specified subscription ID was not found in your accessible subscriptions." -ForegroundColor Yellow
    Write-Host "Attempting to check quota anyway..." -ForegroundColor Yellow
}

# Prompt for deployment region
$region = Read-Host "Enter the deployment region (e.g., eastus, westus2, uksouth)"

try {
    # Set the active subscription
    Write-Host "`nSetting subscription context..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscriptionId | Out-Null
    
    # Get subscription details
    $subscription = Get-AzSubscription -SubscriptionId $subscriptionId
    Write-Host "Subscription: $($subscription.Name)" -ForegroundColor Green
    
    # Check if the region is valid by getting available locations
    Write-Host "Validating region..." -ForegroundColor Yellow
    $availableLocations = Get-AzLocation | Select-Object -ExpandProperty Location
    if ($region -notin $availableLocations) {
        Write-Host "Warning: '$region' may not be a valid Azure region." -ForegroundColor Yellow
        Write-Host "Available regions include: $($availableLocations -join ', ')" -ForegroundColor Yellow
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "`nChecking App Service Plan P0V3 quota usage in region '$region'..." -ForegroundColor Yellow
    
    #region Premium P0v3 quota lookup --------------------------------------------
    $quotaApiVersion = "2024-11-01"
    $quotaUri = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$region/usages?api-version=$quotaApiVersion"
    try {
        Write-Host "Querying Azure Web quota API..." -ForegroundColor Yellow
        $usageJson = Invoke-AzRestMethod -Method GET -Path $quotaUri -WarningAction SilentlyContinue
        $usageData = ($usageJson.Content | ConvertFrom-Json).value
        $p0v3 = $usageData |
                Where-Object { $_.name.value -match '(?i)p0v3|premium0v3' } |
                Select-Object -First 1
        
        if ($p0v3) {
            $limit     = [int]$p0v3.limit
            $inUse     = [int]$p0v3.currentValue
            $available = $limit - $inUse
            $quotaFound = $true
        } else {
            $quotaFound = $false
        }
        
        # Also get general App Service Plan information for context
        $existingAppServicePlans = Get-AzAppServicePlan | Where-Object { $_.Location -eq $region }
        $appServiceQuotaInfo = @{
            ExistingPlans = $existingAppServicePlans.Count
            PremiumV3Plans = ($existingAppServicePlans | Where-Object { $_.Sku.Tier -like "*Premium*V3*" }).Count
            P0V3Plans = ($existingAppServicePlans | Where-Object { $_.Sku.Name -eq "P0V3" }).Count
        }
        
    } catch {
        Write-Host "Failed to query quota information: $($_.Exception.Message)" -ForegroundColor Red
        $quotaFound = $false
        $appServiceQuotaInfo = $null
    }
    #endregion
    
    Write-Host "`n=== App Service Plan P0V3 Quota Information ===" -ForegroundColor Cyan
    Write-Host "Subscription: $($subscription.Name)" -ForegroundColor White
    Write-Host "Region: $region" -ForegroundColor White
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    
    # P0V3 Quota Information from REST API
    if ($quotaFound) {
        Write-Host ""
        Write-Host "----------- Premium P0v3 quota in $region -----------" -ForegroundColor Cyan
        Write-Host "Limit     : $limit" -ForegroundColor White
        Write-Host "In use    : $inUse" -ForegroundColor White
        Write-Host "Available : $available" -ForegroundColor $(if ($available -gt 0) { "Green" } else { "Red" })
        
        $percentUsed = if ($limit -gt 0) { [math]::Round(($inUse / $limit) * 100, 1) } else { 0 }
        Write-Host "Usage     : $percentUsed%" -ForegroundColor $(if ($percentUsed -lt 80) { "Green" } elseif ($percentUsed -lt 95) { "Yellow" } else { "Red" })
    } else {
        Write-Host ""
        Write-Host "No P0v3 quota entry found for $region." -ForegroundColor Yellow
        Write-Host "This may mean P0v3 is available without specific limits in this region." -ForegroundColor Yellow
    }
    
    # Additional App Service Plan context
    if ($appServiceQuotaInfo) {
        Write-Host ""
        Write-Host "Current App Service Plans in $region`:" -ForegroundColor Green
        Write-Host "  Total App Service Plans: $($appServiceQuotaInfo.ExistingPlans)" -ForegroundColor White
        Write-Host "  Premium V3 Plans: $($appServiceQuotaInfo.PremiumV3Plans)" -ForegroundColor White
        Write-Host "  P0V3 Plans specifically: $($appServiceQuotaInfo.P0V3Plans)" -ForegroundColor White
        
        if ($existingAppServicePlans) {
            Write-Host ""
            Write-Host "Existing plans:" -ForegroundColor White
            $existingAppServicePlans | ForEach-Object {
                $color = if ($_.Sku.Name -eq "P0V3") { "Yellow" } elseif ($_.Sku.Tier -like "*Premium*V3*") { "Cyan" } else { "White" }
                Write-Host "  - $($_.Name): $($_.Sku.Name) ($($_.Sku.Tier))" -ForegroundColor $color
            }
        }
    }
    
    
    # Summary
    Write-Host "`n=== App Service Plan Quota Summary ===" -ForegroundColor Cyan
    
    if ($quotaFound) {
        if ($available -gt 0) {
            Write-Host "[SUCCESS] You have $available P0V3 plans available in $region" -ForegroundColor Green
            Write-Host "You can proceed with deploying your P0V3 hosting plan." -ForegroundColor Green
        } elseif ($available -eq 0) {
            Write-Host "[WARNING] P0V3 quota is at limit in $region ($inUse/$limit used)" -ForegroundColor Red
            Write-Host "You may need to delete existing P0V3 plans or request quota increase." -ForegroundColor Red
        } else {
            Write-Host "[ERROR] P0V3 quota exceeded in $region" -ForegroundColor Red
        }
    } else {
        Write-Host "[INFO] P0V3 quota information not available" -ForegroundColor Yellow
        Write-Host "This typically means P0V3 plans can be created without specific limits." -ForegroundColor Yellow
        Write-Host "You can likely proceed with deployment." -ForegroundColor Green
    }
    
    if ($appServiceQuotaInfo) {
        Write-Host ""
        Write-Host "Additional context:" -ForegroundColor White
        Write-Host "  Current P0V3 plans in region: $($appServiceQuotaInfo.P0V3Plans)" -ForegroundColor White
        Write-Host "  Total PremiumV3 plans in region: $($appServiceQuotaInfo.PremiumV3Plans)" -ForegroundColor White
        Write-Host "  Total App Service plans in region: $($appServiceQuotaInfo.ExistingPlans)" -ForegroundColor White
    }

    # Final comprehensive summary
    Write-Host "`n=== Complete Assessment Summary ===" -ForegroundColor Magenta
    Write-Host "User: $currentUser" -ForegroundColor White
    Write-Host "Global Admin: $isGlobalAdmin" -ForegroundColor $(if ($isGlobalAdmin) { "Green" } else { "Red" })
    Write-Host "Total Subscriptions Accessible: $($results.Count)" -ForegroundColor White
    Write-Host "Subscriptions with Owner Access: $(($results | Where-Object { $_.IsOwner }).Count)" -ForegroundColor White
    
    if ($selectedSubscription) {
        Write-Host "Selected Subscription Owner Status: $($selectedSubscription.IsOwner)" -ForegroundColor $(if ($selectedSubscription.IsOwner) { "Green" } else { "Yellow" })
    }
    
    if ($quotaFound) {
        $planStatus = if ($available -gt 0) { "Available ($available slots)" } else { "At Limit" }
        Write-Host "P0V3 Plan Status in $region`: $planStatus" -ForegroundColor $(if ($available -gt 0) { "Green" } else { "Red" })
    } else {
        Write-Host "P0V3 Plan Status in $region`: Likely Available (no quota limit found)" -ForegroundColor Green
    }

} catch {
    Write-Host "`nError occurred during quota checking: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Message -like "*subscription*not found*") {
        Write-Host "Please verify the subscription ID is correct and you have access to it." -ForegroundColor Yellow
    } elseif ($_.Exception.Message -like "*location*") {
        Write-Host "Please verify the region name is correct. Use 'Get-AzLocation' to see available regions." -ForegroundColor Yellow
    } elseif ($_.Exception.Message -like "*Forbidden*" -or $_.Exception.Message -like "*Unauthorized*") {
        Write-Host "You may not have sufficient permissions to check quota in this subscription." -ForegroundColor Yellow
        if ($selectedSubscription -and -not $selectedSubscription.IsOwner) {
            Write-Host "Note: You are not an Owner of this subscription, which may limit quota visibility." -ForegroundColor Yellow
        }
        Write-Host "`nFor App Service Plans (P0V3), you can still try to create one through:" -ForegroundColor Cyan
        Write-Host "- Azure Portal > Create App Service Plan > Premium V3 tier" -ForegroundColor White
        Write-Host "- Azure CLI: az appservice plan create --name myplan --resource-group rg --sku P0V3" -ForegroundColor White
        Write-Host "- PowerShell: New-AzAppServicePlan -ResourceGroupName rg -Name myplan -Location $region -Tier PremiumV3 -WorkerSize Small" -ForegroundColor White
    }
}
