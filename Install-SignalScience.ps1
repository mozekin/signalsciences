
$TMP = $env:temp
$APPCMD = "C:\windows\system32\inetsrv\appcmd.exe"
$WAFINSTALLER = "$TMP\sigsci.msi"
$WAFIISMODULE = "$TMP\sigsci-iis.zip"
# $WAFIISMODULE = "$TMP\sigsci-iis.msi"
$AGENTCONF = "C:\Program Files\Signal Sciences\Agent\agent.conf"



Write-Host "Downloading Signal Sciences MSI installer to $WAFINSTALLER..."
Invoke-WebRequest https://dl.signalsciences.net/sigsci-agent/sigsci-agent_latest.msi -OutFile $WAFINSTALLER
# Invoke-WebRequest https://dl.signalsciences.net/sigsci-module-iis/sigsci-module-iis_latest.msi  -OutFile $WAFINSTALLER


Write-Host "Downloading Signal Sciences IIS Module to $WAFIISMODULE..."
Invoke-WebRequest https://dl.signalsciences.net/sigsci-module-iis/sigsci-module-iis_latest.zip -OutFile $WAFIISMODULE

Write-Host "Installing $WAFINSTALLER..."
$WAFINSTALLER = Start-Process msiexec "/i $WAFINSTALLER /quiet" -Wait -PassThru
if ($WAFINSTALLER.ExitCode -gt 0) {
    throw "Signal Sciences installer failed with exit code $($WAFINSTALLER.ExitCode)"
}


Write-Host 'Extracting Signal Sciences IIS module...'
# Required as Expand-Archive isn't available until PowerShell v5...
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::ExtractToDirectory($WAFIISMODULE, $TMP)


$INPUT = Read-Host "Before installing the sigsci IIS module, IIS needs to be stopped, would you like to perform an IISReset stop? (Y), (N)?"

If ($INPUT -eq 'Y') { 

    Invoke-Command { Set-Location C:\Windows\System32\; ./cmd.exe /c "iisreset /noforce /stop" }
    Write-Host 'Copying DLL for IIS module installation...'
    Copy-Item $TMP\SigSciIISModule.dll "C:\Program Files\Signal Sciences\" -Force -PassThru

    Write-Host 'Installing Signal Sciences IIS Module...'

    $APPCMDINSTALL = & $APPCMD 'install' 'module' '/name:SignalSciences' '/image:C:\Program Files\Signal Sciences\SigSciIISModule.dll' '/add:true' '/preCondition:bitness64'
    if ($APPCMDINSTALL.ExitCode -gt 0) {
        throw "Signal Sciences IIS module install failed with exit code $($APPCMDINSTALL.ExitCode)"
    }
} 
elseif ($INPUT -eq 'N') {
    Write-Warning "IIS has not been stopped, therefore the IIS module will not be installed!"
}


# Access keys for Signal Sciences agent activation and configuration

Set-Content -Path $AGENTCONF -Value @"
$(Get-Content $SIGSCIPARAMS)
"@

Write-Host 'Restarting Signal Sciences Windows Service for agent config re-initialisation...'
Restart-Service sigsci-agent