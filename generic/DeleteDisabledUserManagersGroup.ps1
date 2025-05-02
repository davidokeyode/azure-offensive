# Define the group name
$groupName = "Managers"

# Get the group object
$group = Get-ADGroup -Identity $groupName

# Get all members of the group
$members = Get-ADGroupMember -Identity $groupName -Recursive

foreach ($member in $members) {
    # Check if the member is a user and disabled
    if ($member.objectClass -eq "user") {
        $user = Get-ADUser -Identity $member.DistinguishedName -Properties Enabled
        if (-not $user.Enabled) {
            # Remove disabled user from group
            Remove-ADGroupMember -Identity $groupName -Members $user -Confirm:$false
            Write-Host "Removed disabled user: $($user.SamAccountName)"
        }
    }
}
