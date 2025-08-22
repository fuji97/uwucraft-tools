[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Port for the packwiz serve command (if not specified, a random available port will be chosen)")]
    [int]$Port = 0,
    
    [Parameter(HelpMessage = "Skip downloading packwiz-installer-bootstrap.jar if it already exists")]
    [switch]$SkipDownload,
    
    [Parameter(HelpMessage = "Keep the packwiz serve process running after deployment")]
    [switch]$KeepServing,
    
    [Parameter(HelpMessage = "Installation directory name (relative to root, default: .server)")]
    [string]$InstallDir = ".server"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get the root directory (parent of scripts)
$RootDir = Split-Path -Parent $PSScriptRoot
$BinDir = Join-Path $RootDir ".bin"
$ServerDir = Join-Path $RootDir $InstallDir
$ServerFilesDir = Join-Path $RootDir "server"
$BootstrapJar = Join-Path $BinDir "packwiz-installer-bootstrap.jar"

Write-Host "=== UwUCraft 21 Server Deployment ===" -ForegroundColor Cyan
Write-Host "Root directory: $RootDir" -ForegroundColor Gray
Write-Host "Bin directory: $BinDir" -ForegroundColor Gray
Write-Host "Install directory: $ServerDir" -ForegroundColor Gray

# Function to cleanup background job
function Stop-PackwizServe {
    param($Job)
    if ($Job -and $Job.State -eq "Running") {
        Write-Host "Stopping packwiz serve..." -ForegroundColor Yellow
        Stop-Job $Job -ErrorAction SilentlyContinue
        Remove-Job $Job -ErrorAction SilentlyContinue
    }
}

# Comprehensive cleanup function
function Invoke-Cleanup {
    param(
        $ServeJob,
        [int]$Port
    )
    
    Write-Host "`nPerforming cleanup..." -ForegroundColor Yellow
    
    # Always stop the serve job first
    if ($ServeJob) {
        Stop-PackwizServe $ServeJob
    }

}

# Function to extract manual download info from packwiz installer output
function Get-ManualDownloads {
    param($OutputText)
    $ManualMods = @()
    $Lines = $OutputText -split "`n"
    
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $Line = $Lines[$i].Trim()
        # Look for the java.lang.Exception line
        if ($Line -match "java\.lang\.Exception: This mod is excluded from the CurseForge API") {
            # Look for the URL in the next few lines
            for ($j = $i + 1; $j -lt [Math]::Min($i + 5, $Lines.Count); $j++) {
                if ($Lines[$j] -match "Please go to (https://[^\s]+) and save this file to .+\\([^\\]+\.(jar|zip))") {
                    $Url = $Matches[1]
                    $FileName = $Matches[2]
                    # Extract mod name from filename (remove version and extension)
                    $ModName = $FileName -replace '-[\d\.]+.*\.(jar|zip)$', '' -replace '_[\d\.x]+.*\.(jar|zip)$', ''
                    
                    # Check if we already have this mod (to avoid duplicates)
                    if (-not ($ManualMods | Where-Object { $_.Name -eq $ModName })) {
                        $ManualMods += [PSCustomObject]@{
                            Name = $ModName
                            FileName = $FileName
                            Url = $Url
                        }
                    }
                    break
                }
            }
        }
    }
    return $ManualMods
}

# Function to check if port is in use
function Test-PortInUse {
    param([int]$Port)
    try {
        $Connection = New-Object System.Net.Sockets.TcpClient
        $Connection.Connect("127.0.0.1", $Port)
        $Connection.Close()
        return $true
    } catch {
        return $false
    }
}

# Function to find a random available port
function Get-RandomAvailablePort {
    param(
        [int]$MinPort = 8000,
        [int]$MaxPort = 9999
    )
    
    $MaxAttempts = 100
    $Attempt = 0
    
    do {
        $Attempt++
        $TestPort = Get-Random -Minimum $MinPort -Maximum $MaxPort
        
        if (-not (Test-PortInUse $TestPort)) {
            return $TestPort
        }
        
        if ($Attempt -ge $MaxAttempts) {
            throw "Could not find an available port after $MaxAttempts attempts"
        }
    } while ($true)
}
function Stop-ProcessOnPort {
    param([int]$Port)
    try {
        $ProcessIds = netstat -ano | Select-String ":$Port " | ForEach-Object {
            ($_ -split '\s+')[-1]
        } | Sort-Object -Unique
        
        foreach ($ProcessId in $ProcessIds) {
            if ($ProcessId -and $ProcessId -ne "0") {
                Write-Host "Stopping process $ProcessId using port $Port..." -ForegroundColor Gray
                Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "Warning: Could not stop processes on port $Port" -ForegroundColor Yellow
    }
}

try {
    # Choose port - either specified or find random available
    if ($Port -eq 0) {
        $Port = Get-RandomAvailablePort
        Write-Host "Using randomly selected port: $Port" -ForegroundColor Gray
    } else {
        Write-Host "Using specified port: $Port" -ForegroundColor Gray
    }
    
    $PackTomlUrl = "http://localhost:$Port/pack.toml"
    
    # Change to root directory
    Push-Location $RootDir
    
    # Step 1: Create directories if they don't exist
    Write-Host "`n[1/5] Creating directories..." -ForegroundColor Green
    
    if (-not (Test-Path $BinDir)) {
        New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
        Write-Host "Created directory: $BinDir" -ForegroundColor Gray
    } else {
        Write-Host "Directory already exists: $BinDir" -ForegroundColor Gray
    }
    
    if (-not (Test-Path $ServerDir)) {
        New-Item -ItemType Directory -Path $ServerDir -Force | Out-Null
        Write-Host "Created directory: $ServerDir" -ForegroundColor Gray
    } else {
        Write-Host "Directory already exists: $ServerDir" -ForegroundColor Gray
    }
    
    # Step 2: Download packwiz-installer-bootstrap.jar if needed
    Write-Host "`n[2/5] Downloading packwiz-installer-bootstrap.jar..." -ForegroundColor Green
    if (-not $SkipDownload -or -not (Test-Path $BootstrapJar)) {
        $DownloadUrl = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar"
        Write-Host "Downloading from: $DownloadUrl" -ForegroundColor Gray
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $BootstrapJar -UseBasicParsing
        Write-Host "Downloaded to: $BootstrapJar" -ForegroundColor Gray
    } else {
        Write-Host "Skipping download, file already exists: $BootstrapJar" -ForegroundColor Gray
    }
    
    # Step 3: Start packwiz serve in background
    Write-Host "`n[3/5] Starting packwiz serve..." -ForegroundColor Green
    
    # Check if port is already in use
    if (Test-PortInUse $Port) {
        Write-Host "Port $Port is already in use. Attempting to free it..." -ForegroundColor Yellow
        Stop-ProcessOnPort $Port
        
        # Check again after cleanup
        if (Test-PortInUse $Port) {
            throw "Port $Port is still in use after cleanup attempt. Please choose a different port or manually stop the process."
        }
    }
    
    $ServeJob = Start-Job -ScriptBlock {
        param($RootDir, $Port)
        Set-Location $RootDir
        packwiz serve --port $Port
    } -ArgumentList $RootDir, $Port
    
    # Wait a moment for the server to start
    Start-Sleep -Seconds 3
    
    # Check if the job is still running
    if ($ServeJob.State -ne "Running") {
        $JobOutput = Receive-Job $ServeJob -ErrorAction SilentlyContinue
        throw "Failed to start packwiz serve. Output: $JobOutput"
    }
    
    Write-Host "Packwiz serve started on port $Port (Job ID: $($ServeJob.Id))" -ForegroundColor Gray
    
    # Step 4: Test if the server is responding
    Write-Host "`n[4/5] Testing packwiz server availability..." -ForegroundColor Green
    $MaxRetries = 10
    $RetryCount = 0
    $ServerReady = $false
    
    while ($RetryCount -lt $MaxRetries -and -not $ServerReady) {
        try {
            $Response = Invoke-WebRequest -Uri $PackTomlUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($Response.StatusCode -eq 200) {
                $ServerReady = $true
                Write-Host "Packwiz server is ready!" -ForegroundColor Gray
            }
        } catch {
            $RetryCount++
            Write-Host "Waiting for server... (attempt $RetryCount/$MaxRetries)" -ForegroundColor Gray
            Start-Sleep -Seconds 2
        }
    }
    
    if (-not $ServerReady) {
        throw "Packwiz server did not become available after $MaxRetries attempts"
    }
    
    # Step 5: Run packwiz-installer-bootstrap
    Write-Host "`n[5/5] Running packwiz-installer-bootstrap..." -ForegroundColor Green
    
    # Calculate relative path from .bin to install directory
    $RelativeInstallPath = [System.IO.Path]::GetRelativePath($BinDir, $ServerDir)
    
    $JavaArgs = @(
        "-jar", "packwiz-installer-bootstrap.jar",
        "-g", "-s", "server",
        "--pack-folder", $RelativeInstallPath,
        $PackTomlUrl
    )
    
    Write-Host "Executing from $BinDir`: java $($JavaArgs -join ' ')" -ForegroundColor Gray
    Push-Location $BinDir
    
    # Capture output for analysis
    $TempOutFile = [System.IO.Path]::GetTempFileName()
    $TempErrFile = [System.IO.Path]::GetTempFileName()
    try {
        $Process = Start-Process -FilePath "java" -ArgumentList $JavaArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $TempOutFile -RedirectStandardError $TempErrFile
        $InstallerOutput = (Get-Content $TempOutFile -Raw) + (Get-Content $TempErrFile -Raw)
        Write-Host $InstallerOutput
        
        if ($Process.ExitCode -ne 0) {
            Write-Host "`nError: packwiz-installer-bootstrap failed with exit code $($Process.ExitCode)" -ForegroundColor Red
            Write-Host "This usually means some mods are excluded from CurseForge API and need manual download." -ForegroundColor Yellow
            
            # Parse manual downloads
            $ManualMods = Get-ManualDownloads $InstallerOutput
            if ($ManualMods.Count -gt 0) {
                Write-Host "`nMods requiring manual download:" -ForegroundColor Yellow
                foreach ($Mod in $ManualMods) {
                    Write-Host "  - $($Mod.Name) ($($Mod.FileName)): $($Mod.Url)" -ForegroundColor Gray
                }
            }
            
            # Stop execution and let the catch block handle cleanup
            throw "packwiz-installer-bootstrap failed. Please download the required mods manually and try again."
        }
    } finally {
        Remove-Item $TempOutFile -ErrorAction SilentlyContinue
        Remove-Item $TempErrFile -ErrorAction SilentlyContinue
    }
    
    Pop-Location
    Write-Host "Server package created successfully!" -ForegroundColor Gray
    
    # Step 6: Override with server files
    if (Test-Path $ServerFilesDir) {
        Write-Host "`n[6/6] Copying server override files..." -ForegroundColor Green
        $ServerFiles = Get-ChildItem -Path $ServerFilesDir -Recurse
        if ($ServerFiles.Count -gt 0) {
            Copy-Item -Path "$ServerFilesDir\*" -Destination $ServerDir -Recurse -Force
            Write-Host "Copied $($ServerFiles.Count) files from server/ to $InstallDir/" -ForegroundColor Gray
        } else {
            Write-Host "No files found in server/ directory to copy" -ForegroundColor Gray
        }
    } else {
        Write-Host "`n[6/6] No server/ directory found, skipping file override" -ForegroundColor Yellow
    }
    
    Write-Host "`n=== Deployment Complete! ===" -ForegroundColor Green
    Write-Host "Server files are ready in: $ServerDir" -ForegroundColor Cyan
    Write-Host "Installer artifacts preserved in: $BinDir" -ForegroundColor Cyan
    
    # Handle packwiz serve cleanup
    if ($KeepServing) {
        Write-Host "`nPackwiz serve is still running on port $Port (Job ID: $($ServeJob.Id))" -ForegroundColor Yellow
        Write-Host "To stop it manually, run: Stop-Job $($ServeJob.Id); Remove-Job $($ServeJob.Id)" -ForegroundColor Gray
    } else {
        # Cleanup serve process only
        Invoke-Cleanup -ServeJob $ServeJob -Port $Port
    }
    
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    # Always cleanup on error, regardless of parameters
    if ($ServeJob) {
        Invoke-Cleanup -ServeJob $ServeJob -Port $Port
    }
    exit 1
} finally {
    Pop-Location
}

Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
