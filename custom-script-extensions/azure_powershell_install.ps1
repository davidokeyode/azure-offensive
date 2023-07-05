$env:chocolateyVersion = '1.4.0'
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install az.powershell messenger 7zip.install googlechrome setdefaultbrowser win-no-annoy -y

SetDefaultBrowser.exe HKLM "Google Chrome" 
