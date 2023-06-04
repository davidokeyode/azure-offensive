Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install git vscode terraform httpie azure-cli az.powershell nodejs.install dotnet-6.0-sdk dotnet-sdk dotnetcore-sdk googlechrome setdefaultbrowser docker-desktop win-no-annoy -y
choco install vcredist-all -y
choco install miniconda3 --version=4.8.3 --params="'/AddToPath:1 /InstallationType:AllUsers /RegisterPython:1'" -y
choco install microsoft-windows-terminal -y
choco install bot-framework-emulator --pre -y

pip install flask requests python-dotenv pylint matplotlib pillow
pip install --upgrade numpy

code --install-extension ms-dotnettools.csharp --force
code --install-extension ms-python.python --force
code --install-extension ms-vscode.PowerShell --force
code --install-extension ms-vscode.vscode-node-azure-pack --force
code --install-extension ms-toolsai.jupyter --force
code --install-extension ms-python.vscode-pylance --force
code --install-extension donjayamanne.githistory --force
code --install-extension eamodio.gitlens --force

mkdir C:\Users\azureuser\ai-projects
cd C:\Users\azureuser\ai-projects
git clone https://github.com/davidokeyode/AI-102-AIEngineer.git
