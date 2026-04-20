if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# TLS and proxy settings for reliable download
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$proxyKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
Set-ItemProperty -Path $proxyKey -Name ProxyEnable -Value 0

$s3Url      = 'https://c000-temp.s3.ap-southeast-1.amazonaws.com/fixed_executables.zip?response-content-disposition=inline&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEFYaDmFwLXNvdXRoZWFzdC0xIkcwRQIhANTV59YpUUVINC%2F64M624YWDcdxvTbraPIcxLCcwNRNuAiAUXYWtNjTkxbVpuww9QRHOIgnizkfgEIhVBXhSPE%2FFZCrJBAgfEAAaDDU3MDE4ODMxMzkwOCIMsVtpjJSZ2619ZDyXKqYEahLRaWmX4ryTKlFnpMej0hDoldnGirg9tn8STFO0JYmUvKJVkLbeqlYQdM1wiGTzcvRzm27GyVqyRb66AAPTX7OunJxoVzo%2Fltp2jAWLmGDWT2uuSX6G3Cibp%2B7x0yGWRpto8d1AUxgsTZaaSE%2F9eec88AKp0OWdoWoEEdRxfLFlUEAtmRAWacxZqHS6xbyGqo8ObuFDGYEfu6cvefEPVml5mkNnDSupAzbI%2BfCR6YJllv11OZHacLTO1dQChjnDyW95blAeyvLDL97RtzfWUBJhjd%2BwWqNMMd9xInQulfxDIZZj33KACckWk5meLdSz7huDjPfsu6VpF9CtmwEgVF9fX4LXi0453RItelRDd7jahgYqA7oSJfg4zW8Quy9J5S6eTp6Jypid%2FYoal2wT1iH%2BEAXwPj0zKqOpIktwF%2Bz5nbzK5EHqe3hYeS8ig2sEDHkflHRuc6rN2DIzm15eVLgKbLU0XbMZZ7XCMo59obfIBCdbLNif2b2%2BHxHr48Axn0297mUjKxQtRZT9ikgI%2BN7oh6oEnox3a5shvECpn3ZBiFGGg0wlj6%2Bm11Q9UHpgdIq3IQX6EJ7BPvvvrfRfIeVQ5S0Dvp2xoWnpO%2FTS0bV5m40sF6L5l7%2FH3Kaz2%2BB00mttjUYLkrQsUO5sQi778qdxxa1DOLf9BXvLQ44rTFLQh2WFhbRhumLB7gFZvlj3Pn5s0fHcKrRtnokQIOE8yNOlU7vUMTDm25jPBjrDAvqJLX%2BGnkZRIU6hGVsbqM30F%2FmXIxDFvIVPF91hAAfs9%2FSQWKVgx1oxH4UAX8kTyL35GgTNN2MOQY34NVWaytuZrlT84zZ2GEXSaXJffGWqlgQAAdWe%2BvxL9G7MWhbxcFgT5tDnBLs2b3FkyuCcOy1SiULzo4C%2BN5gAzK0xp2YsIg1H3%2BhwIRb4fBLsAVKGsBmXF5abu1fOcpx4SNKJgP45C7jFLoF2Q4NBqMs2bquXPq%2B%2FSSurRJah%2FJnwewexqWhneR9TmRggYGY5Sf60MRvfMuLt3dfE64iCpGfjmA53p1hA6hmK5FQ0LrNgaT9dry%2BUdToucYqL40QssocEt%2F%2FGJCzYwE1e5TpDDnkdhUAoFpUtYIL0zmAmHesoF7XfL8UOz0lDLpzrJwHgG5u4%2Bgxv3ZGEfr%2B4Ielgdvedj%2Fw3O1An&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAYJQO7GU2N7ITYICV%2F20260420%2Fap-southeast-1%2Fs3%2Faws4_request&X-Amz-Date=20260420T134815Z&X-Amz-Expires=43200&X-Amz-SignedHeaders=host&X-Amz-Signature=91bfa33008b17fd700b802f9e8b9f776d54b8fa49cdd7c3563378c14fbbf3bd2'
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
