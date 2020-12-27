New-ADOrganizationalUnit -Name "OrgUsers" -Path "DC=az500lab,DC=com"
New-ADOrganizationalUnit -Name "Finance" -Path "OU=OrgUsers,DC=az500lab,DC=com"
New-ADOrganizationalUnit -Name "IT" -Path "OU=OrgUsers,DC=az500lab,DC=com"

New-ADGroup -Name "FinanceUsers" -SamAccountName FinanceUsers -GroupCategory Security -GroupScope Global -DisplayName "FinanceUsers" -Path "OU=Finance,OU=OrgUsers,DC=az500lab,DC=com" -Description "Members of this group are Finance Users"

New-ADGroup -Name "ITUsers" -SamAccountName ITUsers -GroupCategory Security -GroupScope Global -DisplayName "ITUsers" -Path "OU=IT,OU=OrgUsers,DC=az500lab,DC=com" -Description "Members of this group are IT Users"

$password = Read-Host -AsSecureString "Input Password"

New-ADUser -Name "Jack Robinson" -GivenName "Jack" -Surname "Robinson" -SamAccountName "jack" -UserPrincipalName "jack@az500lab.com" -Path "OU=Finance,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Kerri Ondrich" -GivenName "Kerri" -Surname "Ondrich" -SamAccountName "kerri" -UserPrincipalName "kerri@az500lab.com" -Path "OU=Finance,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Lanie	Cominotti" -GivenName "Lanie" -Surname "Cominotti" -SamAccountName "lanie" -UserPrincipalName "lanie@az500lab.com" -Path "OU=Finance,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Octavius Mohun" -GivenName "Octavius" -Surname "Mohun" -SamAccountName "octavius" -UserPrincipalName "octavius@az500lab.com" -Path "OU=Finance,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Davy Flury" -GivenName "Davy" -Surname "Flury" -SamAccountName "davy" -UserPrincipalName "davy@az500lab.com" -Path "OU=Finance,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Nat Ortner" -GivenName "Nat" -Surname "Ortner" -SamAccountName "nat" -UserPrincipalName "nat@az500lab.com" -Path "OU=IT,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Galina Armer" -GivenName "Galina" -Surname "Armer" -SamAccountName "galina" -UserPrincipalName "galina@az500lab.com" -Path "OU=IT,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Kendrick Axtonne" -GivenName "Kendrick" -Surname "Axtonne" -SamAccountName "kendrick" -UserPrincipalName "kendrick@az500lab.com" -Path "OU=IT,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Jonah	Lerohan" -GivenName "Jonah" -Surname "Lerohan" -SamAccountName "jonah" -UserPrincipalName "jonah@az500lab.com" -Path "OU=IT,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

New-ADUser -Name "Jefferson Pinchen" -GivenName "Jefferson" -Surname "Pinchen" -SamAccountName "jefferson" -UserPrincipalName "jefferson@az500lab.com" -Path "OU=IT,OU=OrgUsers,DC=az500lab,DC=com" -AccountPassword $password -Enabled $true

Add-ADGroupMember -Identity FinanceUsers -Members davy,octavius,lanie,kerri,jack
Add-ADGroupMember -Identity ITUsers -Members jefferson,jonah,kendrick,galina,nat