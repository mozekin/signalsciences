
$TMP = $env:temp
$WAFINSTALLER = "$TMP\sigsci.msi"
$WAFIISMODULE = "$TMP\sigsci-iis.msi"
$AGENTCONF = "C:\Program Files\Signal Sciences\Agent\agent.conf"


Write-Host "Downloading Signal Sciences MSI installer to $WAFINSTALLER..."
Invoke-WebRequest https://dl.signalsciences.net/sigsci-agent/sigsci-agent_latest.msi -OutFile $WAFINSTALLER

Write-Host "Downloading Signal Sciences IIS Module to $WAFIISMODULE..."
Invoke-WebRequest https://dl.signalsciences.net/sigsci-module-iis/sigsci-module-iis_latest.msi  -OutFile $WAFIISMODULE


Write-Host "Installing $WAFINSTALLER..."
$WAFINSTALLER = Start-Process msiexec "/i $WAFINSTALLER /quiet" -Wait -PassThru
if ($WAFINSTALLER.ExitCode -gt 0) {
    throw "Signal Sciences installer failed with exit code $($WAFINSTALLER.ExitCode)"
}


$INPUT = Read-Host "Before installing the sigsci IIS module, IIS needs to be stopped, would you like to perform an IISReset stop? (Y), (N)?"

If ($INPUT -eq 'Y') {

    Write-Host 'Stopping IIS...'
    Invoke-Command { Set-Location C:\Windows\System32\; ./cmd.exe /c "iisreset /noforce /stop" }

    Write-Host 'Installing Signal Sciences IIS Module...'

    Write-Host "Installing $WAFIISMODULE..."
    $WAFIISMODULE = Start-Process msiexec "/i $WAFIISMODULE /quiet" -Wait -PassThru

if ($WAFIISMODULE.ExitCode -gt 0) {
    throw "Signal Sciences IIS installer failed with exit code $($WAFIISMODULE.ExitCode)"
    }
}

elseif ($INPUT -eq 'N') {
    Write-Warning "IIS has not been stopped, therefore the IIS module will not be installed!"
}


# Access keys for Signal Sciences agent activation and configuration

Set-Content -Path $AGENTCONF -Value @"
accesskeyid = "REDACTED"
secretaccesskey = "REDACTED"
rpc-address = "127.0.0.1:9999"
rpc-version = 1
"@

Write-Host 'Restarting IIS for agent config re-initialisation...'
Invoke-Command { Set-Location C:\Windows\System32\; ./cmd.exe /c "iisreset" }

Write-Host 'Restarting Signal Sciences Windows Service for agent config re-initialisation...'
Restart-Service sigsci-agent
