Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco install git vscode terraform httpie azure-cli az.powershell nodejs.install dotnet-6.0-sdk dotnet-sdk googlechrome setdefaultbrowser docker-desktop win-no-annoy -y
choco install vcredist-all -y
choco install miniconda3 -y
choco install microsoft-windows-terminal -y
choco install bot-framework-emulator --pre -y

pip install flask requests python-dotenv pylint matplotlib pillow
pip install --upgrade numpy

mkdir $HOME\Downloads\ai-projects
cd $HOME\Downloads\ai-projects
git clone https://github.com/davidokeyode/AI-102-AIEngineer.git
