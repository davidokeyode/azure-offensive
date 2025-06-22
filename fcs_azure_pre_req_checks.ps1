# Suppress the output and warnings from Connect-AzAccount
Connect-AzAccount -WarningAction SilentlyContinue | Out-Null

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

# Now proceed with Premium0V3 quota checking
Write-Host "`n=== Premium0V3 Quota Checking ===" -ForegroundColor Cyan

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
    
    Write-Host "`nChecking VM quota usage in region '$region'..." -ForegroundColor Yellow
    
    # Get VM usage/quota information for the specified region
    $vmUsage = Get-AzVMUsage -Location $region -ErrorAction Stop
    
    # Filter for Premium0V3 instances
    $premium0V3Usage = $vmUsage | Where-Object { 
        $_.Name.Value -like "*Premium0V3*" -or 
        $_.Name.LocalizedValue -like "*Premium0V3*" -or
        $_.Name.Value -eq "standardPremium0V3Family" -or
        $_.Name.LocalizedValue -like "*Standard Premium0V3*"
    }
    
    # Also check for general vCPU limits that might affect Premium0V3 deployments
    $vcpuUsage = $vmUsage | Where-Object { 
        $_.Name.Value -like "*cores*" -or 
        $_.Name.LocalizedValue -like "*cores*" -or
        $_.Name.LocalizedValue -like "*vCPUs*"
    }
    
    Write-Host "`n=== Premium0V3 Quota Information ===" -ForegroundColor Cyan
    Write-Host "Subscription: $($subscription.Name)" -ForegroundColor White
    Write-Host "Region: $region" -ForegroundColor White
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    
    if ($premium0V3Usage) {
        Write-Host "`nPremium0V3 Specific Quotas:" -ForegroundColor Green
        $premium0V3Usage | ForEach-Object {
            $used = $_.CurrentValue
            $limit = $_.Limit
            $available = $limit - $used
            $percentUsed = if ($limit -gt 0) { [math]::Round(($used / $limit) * 100, 1) } else { 0 }
            
            $color = switch ($percentUsed) {
                { $_ -lt 50 } { "Green" }
                { $_ -lt 80 } { "Yellow" }
                default { "Red" }
            }
            
            Write-Host "  $($_.Name.LocalizedValue):" -ForegroundColor White
            Write-Host "    Used: $used / $limit ($percentUsed%)" -ForegroundColor $color
            Write-Host "    Available: $available" -ForegroundColor $color
        }
    } else {
        Write-Host "`nNo Premium0V3 specific quotas found." -ForegroundColor Yellow
        Write-Host "This could mean:" -ForegroundColor Yellow
        Write-Host "  - Premium0V3 instances use general vCPU quotas" -ForegroundColor Yellow
        Write-Host "  - The quota name format is different than expected" -ForegroundColor Yellow
    }
    
    Write-Host "`nGeneral vCPU/Core Quotas (may affect Premium0V3 deployments):" -ForegroundColor Green
    $vcpuUsage | ForEach-Object {
        $used = $_.CurrentValue
        $limit = $_.Limit
        $available = $limit - $used
        $percentUsed = if ($limit -gt 0) { [math]::Round(($used / $limit) * 100, 1) } else { 0 }
        
        $color = switch ($percentUsed) {
            { $_ -lt 50 } { "Green" }
            { $_ -lt 80 } { "Yellow" }
            default { "Red" }
        }
        
        Write-Host "  $($_.Name.LocalizedValue):" -ForegroundColor White
        Write-Host "    Used: $used / $limit ($percentUsed%)" -ForegroundColor $color
        Write-Host "    Available: $available" -ForegroundColor $color
    }
    
    # Summary
    Write-Host "`n=== Quota Summary ===" -ForegroundColor Cyan
    $totalVcpuUsage = $vcpuUsage | Where-Object { $_.Name.LocalizedValue -like "*Total Regional vCPUs*" } | Select-Object -First 1
    if ($totalVcpuUsage) {
        $available = $totalVcpuUsage.Limit - $totalVcpuUsage.CurrentValue
        if ($available -gt 0) {
            Write-Host "✓ You have $available vCPUs available in $region" -ForegroundColor Green
        } else {
            Write-Host "✗ No vCPUs available in $region. Current usage: $($totalVcpuUsage.CurrentValue)/$($totalVcpuUsage.Limit)" -ForegroundColor Red
        }
    }
    
    if ($premium0V3Usage) {
        $availablePremium0V3 = ($premium0V3Usage | Measure-Object -Property { $_.Limit - $_.CurrentValue } -Sum).Sum
        if ($availablePremium0V3 -gt 0) {
            Write-Host "✓ Premium0V3 quota available" -ForegroundColor Green
        } else {
            Write-Host "✗ No Premium0V3 quota available" -ForegroundColor Red
        }
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
    
    if ($totalVcpuUsage) {
        $quotaStatus = if (($totalVcpuUsage.Limit - $totalVcpuUsage.CurrentValue) -gt 0) { "Available" } else { "Exhausted" }
        Write-Host "VM Quota Status in $region`: $quotaStatus" -ForegroundColor $(if ($quotaStatus -eq "Available") { "Green" } else { "Red" })
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
    }
}