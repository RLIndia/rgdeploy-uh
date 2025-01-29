# Redirect stdout and stderr to a log file and the console
$scriptPath = "C:\Users\Administrator\log\provision-windows.log"
Start-Transcript -Path $scriptPath -Append  

# Add mount script and set-user-token to startup folder
Write-Host "Moving mount-s3.bat and set-user-token.bat to startup folder"
if (Test-Path -Path "C:\Program Files\ResearchGateway\mount_s3.bat") {
	Copy-Item -Path "C:\Program Files\ResearchGateway\mount_s3.bat" -Destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\"
 -Force
} elseif (Test-Path -Path "C:\Users\Administrator\mount_s3.bat") {
	// This is only to support older pipelines which expect this location of the file
	Copy-Item -Path "C:\Users\Administrator\mount_s3.bat" -Destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\"
 -Force
}else {
	Write-Host "Error: Could not find mount_s3.bat. Study mounting might not work correctly."		
}
if (Test-Path -Path "C:\Program Files\ResearchGateway\set_user_token.bat") {
	Copy-Item -Path "C:\Program Files\ResearchGateway\set_user_token.bat" -Destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\"
 -Force
} elseif (Test-Path -Path "C:\Users\Administrator\set_user_token.bat") {
	// This is only to support older pipelines which expect this location of the file
	Copy-Item -Path "C:\Users\Administrator\set_user_token.bat" -Destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\"
 -Force
}else {
	Write-Host "Error: Could not find set_user_token.bat. Launch URL might not work correctly."		
}



# Set Administrator password
net user Administrator Admin@123

# Set environment variable
setx PARAMNAMEPREFIX /RL/RG/secure-desktop/auth-token/

# Download and install Microsoft Visual C++ Redistributable for Visual Studio 2017
Write-Host "Downloading Microsoft Visual C++ Redistributable for Visual Studio 2017..."
$downloadsuccesful = $false
Invoke-WebRequest -Uri "https://aka.ms/vs/15/release/vc_redist.x64.exe" -OutFile "$env:TEMP\vc_redist.x64.exe"
$downloadsuccesful = Test-Path -Path "$env:TEMP\vc_redist.x64.exe"

if ($downloadsuccesful) {
	Write-Host "Installing Microsoft Visual C++ Redistributable for Visual Studio 2017"
	Start-Process -FilePath "$env:TEMP\vc_redist.x64.exe" -ArgumentList "/install /quiet /norestart" -Wait
	Remove-Item -Path "$env:TEMP\vc_redist.x64.exe" -Force
} else {
	Write-Host "Failed to download Microsoft Visual C++ Redistributable for Visual Studio 2017"
	Exit 1
}
Write-Host "Installing Miniconda and JupyterLab..."

# Define Miniconda installer URL
$minicondaUrl = "https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"

# Define paths for Miniconda installer and the desktop shortcuts
$minicondaInstallerPath = "C:\Users\Administrator\Downloads\Miniconda3-latest-Windows-x86_64.exe"
$anacondaPromptShortcutPath = [System.Environment]::GetFolderPath("Desktop") + "\Anaconda Prompt.lnk"
$jupyterLabShortcutPath = [System.Environment]::GetFolderPath("Desktop") + "\JupyterLab.lnk"

# Download Miniconda installer
try {
    Invoke-WebRequest -Uri $minicondaUrl -OutFile $minicondaInstallerPath
    Write-Host "Miniconda downloaded successfully."
} catch {
    Write-Host "Failed to download Miniconda. Please check the URL."
    exit
}

# Install Miniconda
if (Test-Path $minicondaInstallerPath) {
    Start-Process -FilePath $minicondaInstallerPath -ArgumentList '/InstallationType=JustMe /RegisterPython=1 /S /D=C:\Miniconda3' -Wait
    Write-Host "Miniconda installed successfully."
} else {
    Write-Host "Miniconda installer not found."
    exit
}

# Initialize Conda in the terminal (optional)
Start-Process -FilePath "C:\Miniconda3\condabin\conda.bat" -ArgumentList 'init' -Wait

# Install JupyterLab using Conda
Start-Process -FilePath "C:\Miniconda3\condabin\conda.bat" -ArgumentList 'install -y jupyterlab' -Wait
Write-Host "JupyterLab installed successfully."

# Create Anaconda Prompt shortcut on the desktop
$WshShell = New-Object -ComObject WScript.Shell
$AnacondaShortcut = $WshShell.CreateShortcut($anacondaPromptShortcutPath)
$AnacondaShortcut.TargetPath = "C:\Windows\System32\cmd.exe"
$AnacondaShortcut.Arguments = "/K C:\Miniconda3\Scripts\activate.bat C:\Miniconda3"
$AnacondaShortcut.IconLocation = "C:\Miniconda3\Menu\anaconda.ico"
$AnacondaShortcut.Save()
Write-Host "Anaconda Prompt shortcut created on Desktop."

# Create JupyterLab shortcut on the desktop
$JupyterShortcut = $WshShell.CreateShortcut($jupyterLabShortcutPath)
$JupyterShortcut.TargetPath = "C:\Windows\System32\cmd.exe"
$JupyterShortcut.Arguments = "/K C:\Miniconda3\Scripts\activate.bat C:\Miniconda3 && jupyter lab"
$JupyterShortcut.IconLocation = "C:\Program Files\ResearchGateway\jupyterLab.ico"
$JupyterShortcut.Save()
Write-Host "JupyterLab shortcut created on Desktop."

# Clean up: Remove the Miniconda installer after installation
Remove-Item -Path $minicondaInstallerPath -Force
Write-Host "Installation completed successfully."

Write-Host "Installing RStudio..."

# Define URLs for R and RStudio
$rInstallerUrl = "https://cran.r-project.org/bin/windows/base/R-4.4.2-win.exe"  # Replace with the correct URL
$rStudioInstallerUrl = "https://download1.rstudio.org/electron/windows/RStudio-2024.04.2-764.exe"  # Replace with the correct URL

# Define file paths for download
$rInstallerPath = "C:\Users\Administrator\Downloads\R-4.4.2-win.exe"
$rStudioInstallerPath = "C:\Users\Administrator\Downloads\RStudio-2024.04.2-764.exe"
$rStudioShortcutPath = [System.Environment]::GetFolderPath("Desktop") + "\RStudio.lnk"

# Download R Installer
try {
    Invoke-WebRequest -Uri $rInstallerUrl -OutFile $rInstallerPath
    Write-Host "R downloaded successfully."
} catch {
    Write-Host "Failed to download R. Please check the URL."
    exit
}

# Download RStudio Installer
try {
    Invoke-WebRequest -Uri $rStudioInstallerUrl -OutFile $rStudioInstallerPath
    Write-Host "RStudio downloaded successfully."
} catch {
    Write-Host "Failed to download RStudio. Please check the URL."
    exit
}

# Install R silently
if (Test-Path $rInstallerPath) {
    Start-Process -FilePath $rInstallerPath -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES' -Wait
    Write-Host "R installed successfully."
} else {
    Write-Host "R installer not found."
    exit
}

# Install RStudio silently
if (Test-Path $rStudioInstallerPath) {
    Start-Process -FilePath $rStudioInstallerPath -ArgumentList '/S' -Wait  # /S for silent install
    Write-Host "RStudio installed successfully."
} else {
    Write-Host "RStudio installer not found."
    exit
}

# Path to Rscript.exe
$rScriptPath = "C:\Program Files\R\R-4.4.2\bin\Rscript.exe"

# List of R packages
$packages = @('ggplot2', 'tidyverse', 'treemap')

# Install each package using Rscript
foreach ($package in $packages) {
    & $rScriptPath -e "install.packages('$package', repos='https://cloud.r-project.org')"
}

Write-Host "R packages installed successfully."

# AWS CLI Installer URL
$awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"

# Download AWS CLI MSI
Write-Host "Downloading AWS-CLI...$awsCliUrl"
$downloadsuccesful = $false
Invoke-WebRequest -Uri $awsCliUrl -OutFile "$env:TEMP\AWSCLIV2.msi"
$downloadsuccesful = Test-Path -Path "$env:TEMP\AWSCLIV2.msi"

# Install AWS CLI silently
if ($downloadsuccesful) {
	Write-Host "Installing AWS-CLI" 
	Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$env:TEMP\AWSCLIV2.msi`" /quiet /qn /norestart" -Wait	
	Remove-Item -Path "$env:TEMP\AWSCLIV2.msi" -Force
} else {
	Write-Host "AWS CLI download failed"
	Exit 1
}

# Download Nice-Dcv Server
Write-Host "Downloading Nice-Dcv"
$downloadsuccesful = $false
$niceDcvServerURL = "https://d1uj6qtbmh3dt5.cloudfront.net/2023.1/Servers/nice-dcv-server-x64-Release-2023.1-16388.msi"
Invoke-WebRequest -Uri $niceDcvServerURL -OutFile "$env:TEMP\nice-dcv-server-x64-Release-2023.1-16388.msi"
$downloadsuccesful = Test-Path -Path "$env:TEMP\nice-dcv-server-x64-Release-2023.1-16388.msi"
$restartdcv = $false
if (!$downloadsuccesful){
	Write-Host "Failed to download NICE DCV Server"
	Exit 1
}	
# Install Nice-Dcv Server
Write-Host "Installing Nice-Dcv Server"
Start-Process msiexec.exe -ArgumentList "/i `"$env:TEMP\nice-dcv-server-x64-Release-2023.1-16388.msi`" ADDLOCAL=ALL /quiet /norestart /l*v 	dcv_install_msi.log" -Wait
Remove-Item -Path "$env:TEMP\nice-dcv-server-x64-Release-2023.1-16388.msi" -Force
Write-Host "Moving default.perm to location C:\Program Files\NICE\DCV\Server\conf\default.perm"
if (Test-Path -Path "C:\Program Files\ResearchGateway\default.perm") {
	Copy-Item -Path "C:\Program Files\ResearchGateway\default.perm" -Destination "C:\Program Files\NICE\DCV\Server\conf\default.perm" -Force
	$restartdcv = $true
} elseif (Test-Path -Path "C:\Users\Administrator\default.perm") {
	// This is only to support older pipelines which expect this location of the file
	Copy-Item -Path "C:\Users\Administrator\default.perm" -Destination "C:\Program Files\NICE\DCV\Server\conf\default.perm" -Force
	$restartdcv = $true
}else {
	Write-Host "Error: Could not find default.perm. NICE DCV might not be configured correctly."		
}

if ($restartdcv) {
	Write-Host "Restarting DCV server"
	Restart-Service "dcvserver"
	$svcstatus= ((Get-Service -Name 'dcvserver').Status )
	Write-Host "DCV service status:  $svcstatus"
}

# Download and install rclone
Write-Host "Downloading rclone..."
mkdir C:\rclone
$rcloneURL = "https://downloads.rclone.org/v1.65.2/rclone-v1.65.2-windows-amd64.zip"
$downloadsuccesful = $false
Invoke-WebRequest -Uri $rcloneURL -OutFile "$env:TEMP\rclone-v1.65.2-windows-amd64.zip"
$downloadsuccesful = Test-Path -Path "$env:TEMP\rclone-v1.65.2-windows-amd64.zip"
if (!$downloadsuccesful) {
	Write-Host "Failed to download rclone. Mounting studies may not work."
	Exit 1
}
Write-Host "Installing rclone..."
Expand-Archive -Path "$env:TEMP\rclone-v1.65.2-windows-amd64.zip" -DestinationPath "C:\rclone\"
Remove-Item -Path "$env:TEMP\rclone-v1.65.2-windows-amd64.zip" -Force
# Download and install RStudio
Write-Host "Downloading RStudio..."
$RVersion = "R-4.4.1-win.exe"
$rstudioURL = "https://cran.rstudio.com/bin/windows/base/$RVersion"
$downloadsuccesful = $false
Invoke-WebRequest -Uri $rstudioURL -OutFile "$env:TEMP\$RVersion"
$downloadsuccesful = Test-Path -Path "$env:TEMP\$RVersion"

if ($downloadsuccesful) {
	Write-Host "Installing RStudio..."
	Start-Process -FilePath "$env:TEMP\$RVersion" -ArgumentList "/VERYSILENT /NORESTART" -Wait
	Remove-Item -Path "$env:TEMP\$RVersion" -Force
} else {
	Write-Host "Failed to download RStudio"
}

# Install Chocolatey and winfsp
Write-Host "Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
iex ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
choco install winfsp -y

# Install cx_Freeze
Write-Host "Installing cx_Freeze..."
cmd /c start powershell -ExecutionPolicy RemoteSigned {
    pip install cx_Freeze
}


# Install Node.js
Write-Host "Downloading Node.js..."
$nodeURL = "https://nodejs.org/dist/v18.20.2/node-v18.20.2-x64.msi"
$downloadsuccesful = $false
Invoke-WebRequest -Uri $nodeURL -OutFile "$env:TEMP\node-v18.20.2-x64.msi"
$downloadsuccesful = Test-Path -Path "$env:TEMP\node-v18.20.2-x64.msi"
if ($downloadsuccesful) {
	Write-Host "Installing node.js"
	Start-Process -FilePath msiexec.exe -ArgumentList "/i `"$env:TEMP\node-v18.20.2-x64.msi`" /qn"
	Remove-Item -Path "$env:TEMP\node-v18.20.2-x64.msi" -Force
} else {
	Write-Host "Failed to download Node.js."
}

# Define log function
function Write-Log {
    param (
        [string]$Message,
        [string]$LogLevel = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$LogLevel] $Message"
    Write-Output $logMessage
    Add-Content -Path "$PSScriptRoot\installation_log.txt" -Value $logMessage
}

# Check if running as administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "You need to run this script as an administrator." "WARNING"
    Start-Sleep -Seconds 3
    Start-Process powershell.exe -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"")
    return
}

# Install LibreOffice

# Define URLs for software installers
$LibreOfficeURL = 'https://tdf.mirror.garr.it/libreoffice/stable/24.2.7/win/x86_64/LibreOffice_24.2.7_Win_x86-64.msi'

# Define installation paths (adjust as needed)
$installPathLibreOffice = 'C:\Program Files\LibreOffice'

# Change working directory to the script's directory
Set-Location -Path $PSScriptRoot

# Downloading the LibreOffice installer
try {
    Write-Log 'Downloading LibreOffice installer...'
    Invoke-WebRequest -Uri $LibreOfficeURL -OutFile 'LibreOffice_24.2.7_Win_x86-64.msi' -ErrorAction Stop
    Write-Log 'LibreOffice installer downloaded successfully.'
} catch {
    Write-Log "Error downloading LibreOffice installer: $_" "ERROR"
}

# Installing LibreOffice
try {
    Write-Log 'Installing LibreOffice...'
    Start-Process 'msiexec.exe' -ArgumentList "/i LibreOffice_24.2.7_Win_x86-64.msi /qn INSTALLDIR=`"$installPathLibreOffice`"" -NoNewWindow -Wait
    Write-Log 'LibreOffice installation initiated.'
} catch {
    Write-Log "Error starting LibreOffice installation: $_" "ERROR"
}

# Confirm installation
if (Get-Command "$installPathLibreOffice\program\soffice.exe" -ErrorAction SilentlyContinue) {
    Write-Log 'Installation completed successfully.'
} else {
    Write-Log 'Installation failed.' "ERROR"
}

# Delete the downloaded installer after installation
try {
    Write-Log 'Deleting LibreOffice installer...'
    Remove-Item 'LibreOffice_24.2.7_Win_x86-64.msi' -Force -ErrorAction Stop
    Write-Log 'Installer deleted. Installation process is complete.'
} catch {
    Write-Log "Error deleting LibreOffice installer: $_" "ERROR"
}


# Edit registry entry for auth-token-verifier
New-ItemProperty -Force -Path "Microsoft.PowerShell.Core\Registry::\HKEY_USERS\S-1-5-18\Software\GSettings\com\nicesoftware\dcv\security" -Name "auth-token-verifier" -PropertyType "String" -Value "http://127.0.0.1:8445"
Stop-Transcript