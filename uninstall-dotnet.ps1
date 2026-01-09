# Comprehensive .NET 6 cleanup and .NET 9 installation script
# Run as Administrator
# Does NOT reboot the VM

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  .NET 6 EOL Cleanup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Function to safely manage IIS
function Stop-IISSafely {
    try {
        $iisService = Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue
        if ($iisService) {
            if ($iisService.Status -eq "Running") {
                Write-Host "Stopping IIS..." -ForegroundColor Yellow
                net stop was /y 2>$null
                return $true
            } else {
                Write-Host "IIS is not running" -ForegroundColor Gray
                return $true
            }
        } else {
            Write-Host "IIS is not installed on this server" -ForegroundColor Gray
            return $false
        }
    } catch {
        Write-Host "Could not check IIS status: $_" -ForegroundColor Yellow
        return $false
    }
}

function Start-IISSafely {
    param([bool]$wasRunning)
    
    if ($wasRunning) {
        try {
            Write-Host "Starting IIS..." -ForegroundColor Yellow
            net start w3svc 2>$null
            Write-Host "  IIS started successfully" -ForegroundColor Green
        } catch {
            Write-Host "  Could not start IIS: $_" -ForegroundColor Yellow
        }
    }
}

# Function to remove .NET 6 shared runtime folders
function Remove-DotNet6Runtimes {
    Write-Host "`n[1/3] Removing .NET 6 runtime folders..." -ForegroundColor Yellow
    
    $pathsToClean = @(
        "C:\Program Files\dotnet\shared\Microsoft.AspNetCore.App\6.*",
        "C:\Program Files\dotnet\shared\Microsoft.NETCore.App\6.*",
        "C:\Program Files (x86)\dotnet\shared\Microsoft.AspNetCore.App\6.*",
        "C:\Program Files (x86)\dotnet\shared\Microsoft.NETCore.App\6.*",
        "C:\Program Files\dotnet\sdk\6.*"
    )
    
    $removedCount = 0
    foreach ($pattern in $pathsToClean) {
        $folders = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach ($folder in $folders) {
            try {
                Write-Host "  Removing: $($folder.FullName)" -ForegroundColor Cyan
                Remove-Item -Path $folder.FullName -Recurse -Force
                Write-Host "    Deleted successfully" -ForegroundColor Green
                $removedCount++
            } catch {
                Write-Host "    Failed: $_" -ForegroundColor Red
            }
        }
    }
    
    if ($removedCount -eq 0) {
        Write-Host "  No .NET 6 folders found to remove" -ForegroundColor Gray
    } else {
        Write-Host "  Removed $removedCount folder(s)" -ForegroundColor Green
    }
}

# Function to uninstall .NET 6 packages
function Uninstall-DotNet6Packages {
    Write-Host "`n[2/3] Uninstalling .NET 6 packages..." -ForegroundColor Yellow
    
    # Check if any .NET 6 is installed
    $hasOldDotnet = Test-Path "C:\Program Files\dotnet\shared\*\6.*"
    if (-not $hasOldDotnet) {
        Write-Host "  No .NET 6 packages found" -ForegroundColor Gray
        return
    }
    
    Write-Host "  Checking for .NET 6 in registry..." -ForegroundColor Gray
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $foundEntries = 0
    foreach ($path in $uninstallPaths) {
        $entries = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -like "*NET*6.0*" }
        
        foreach ($entry in $entries) {
            $foundEntries++
            Write-Host "  Found: $($entry.DisplayName)" -ForegroundColor Cyan
            if ($entry.QuietUninstallString) {
                try {
                    Write-Host "    Uninstalling..." -ForegroundColor Cyan
                    Start-Process cmd.exe -ArgumentList "/c $($entry.QuietUninstallString)" -Wait -NoNewWindow
                    Write-Host "    Uninstalled successfully" -ForegroundColor Green
                } catch {
                    Write-Host "    Failed: $_" -ForegroundColor Red
                }
            }
        }
    }
    
    if ($foundEntries -eq 0) {
        Write-Host "  No registry entries found" -ForegroundColor Gray
    }
}

# Function to install .NET 9 Hosting Bundle with better download
function Install-DotNet9HostingBundle {
    Write-Host "`n[3/3] Installing .NET 9 Hosting Bundle..." -ForegroundColor Yellow
    
    $tempDir = "$env:TEMP\dotnet_hosting"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    $installer = "$tempDir\dotnet-hosting-9.0.1-win.exe"
    
    # Multiple download URLs to try
    $downloadUrls = @(
        "https://download.visualstudio.microsoft.com/download/pr/7ab0bc25-5b00-42c3-b7cc-bb8e08f05135/91528a790a28c1f0fe39845decf40e10/dotnet-hosting-9.0.1-win.exe",
        "https://dotnetcli.azureedge.net/dotnet/aspnetcore/Runtime/9.0.1/dotnet-hosting-9.0.1-win.exe"
    )
    
    $downloaded = $false
    
    foreach ($url in $downloadUrls) {
        try {
            Write-Host "  Attempting download from: $($url.Split('/')[2])..." -ForegroundColor Cyan
            
            # Use Invoke-WebRequest with TLS 1.2
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 300
            
            if (Test-Path $installer) {
                $fileSize = (Get-Item $installer).Length / 1MB
                $fileSizeRounded = [math]::Round($fileSize, 2)
                Write-Host "    Downloaded successfully - Size: $fileSizeRounded MB" -ForegroundColor Green
                $downloaded = $true
                break
            }
        } catch {
            Write-Host "    Download failed: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }
    }
    
    if (-not $downloaded) {
        Write-Host "  All download attempts failed" -ForegroundColor Red
        Write-Host "`n  MANUAL INSTALLATION REQUIRED:" -ForegroundColor Yellow
        Write-Host "  1. Download from: https://dotnet.microsoft.com/download/dotnet/9.0" -ForegroundColor White
        Write-Host "  2. Look for 'Hosting Bundle' under Windows" -ForegroundColor White
        Write-Host "  3. Run installer with: /install /quiet /norestart" -ForegroundColor White
        return
    }
    
    # Install the hosting bundle
    try {
        Write-Host "  Installing .NET 9 Hosting Bundle..." -ForegroundColor Cyan
        Write-Host "  (This may take 5-10 minutes, please wait...)" -ForegroundColor Gray
        
        $process = Start-Process -FilePath $installer -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
        
        Write-Host "  Installation exit code: $($process.ExitCode)" -ForegroundColor Gray
        
        if ($process.ExitCode -eq 0) {
            Write-Host "    .NET 9 Hosting Bundle installed successfully" -ForegroundColor Green
        } elseif ($process.ExitCode -eq 3010) {
            Write-Host "    .NET 9 Hosting Bundle installed - restart recommended" -ForegroundColor Green
        } elseif ($process.ExitCode -eq 1638) {
            Write-Host "    .NET 9 Hosting Bundle already installed" -ForegroundColor Green
        } elseif ($process.ExitCode -eq 1641) {
            Write-Host "    .NET 9 Hosting Bundle installed - restart initiated" -ForegroundColor Green
        } else {
            Write-Host "    Installation completed with exit code: $($process.ExitCode)" -ForegroundColor Yellow
        }
        
    } catch {
        Write-Host "    Installation exception: $_" -ForegroundColor Red
    } finally {
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Function to verify results
function Verify-Installation {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Verification Results" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Check if dotnet is available
    $dotnetPath = "C:\Program Files\dotnet\dotnet.exe"
    if (Test-Path $dotnetPath) {
        Write-Host "`nInstalled .NET Runtimes:" -ForegroundColor Yellow
        & $dotnetPath --list-runtimes
    } else {
        Write-Host "`ndotnet.exe not found in expected location" -ForegroundColor Yellow
    }
    
    # Check for .NET 6 folders
    Write-Host "`nChecking for .NET 6 installations..." -ForegroundColor Yellow
    $remaining6 = Get-ChildItem "C:\Program Files\dotnet\shared\*\6.*" -ErrorAction SilentlyContinue
    if ($remaining6) {
        Write-Host "  WARNING: Found remaining .NET 6 folders:" -ForegroundColor Red
        $remaining6 | ForEach-Object { Write-Host "    - $($_.FullName)" -ForegroundColor Red }
    } else {
        Write-Host "  No .NET 6 folders found" -ForegroundColor Green
    }
    
    # Check for .NET 9
    Write-Host "`nChecking for .NET 9..." -ForegroundColor Yellow
    $net9Runtime = Get-ChildItem "C:\Program Files\dotnet\shared\Microsoft.AspNetCore.App\9.*" -ErrorAction SilentlyContinue
    if ($net9Runtime) {
        Write-Host "  .NET 9 runtime found:" -ForegroundColor Green
        $net9Runtime | ForEach-Object { Write-Host "    - $($_.Name)" -ForegroundColor Green }
    } else {
        Write-Host "  .NET 9 runtime NOT found" -ForegroundColor Red
    }
    
    # Check IIS module
    if (Test-Path "C:\Windows\System32\inetsrv\aspnetcore.dll") {
        Write-Host "`n  ASP.NET Core Module found in IIS" -ForegroundColor Green
    } else {
        Write-Host "`n  ASP.NET Core Module NOT found in IIS" -ForegroundColor Yellow
    }
}

# Main execution
$iisWasRunning = $false

try {
    Write-Host "`nStarting cleanup process...`n" -ForegroundColor Green
    
    $iisWasRunning = Stop-IISSafely
    
    Remove-DotNet6Runtimes
    Uninstall-DotNet6Packages
    Install-DotNet9HostingBundle
    
    Start-IISSafely -wasRunning $iisWasRunning
    
    Verify-Installation
    
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  Script Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "`nNote: VM reboot is NOT required" -ForegroundColor Cyan
    
} catch {
    Write-Host "`nError occurred: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    
    if ($iisWasRunning) {
        Write-Host "Attempting to restart IIS..." -ForegroundColor Yellow
        Start-IISSafely -wasRunning $true
    }
    
    exit 1
}
