#!/usr/bin/env pwsh

<#
.SYNOPSIS
    UwUCraft Tools PowerShell Module - Unified mod and server management functions

.DESCRIPTION
    This module contains all the functions for managing mods and deploying servers
    for UwUCraft projects using packwiz. It combines functionality from:
    - Apply-CustomMods.ps1
    - Deploy-Server.ps1
    - Manage-CustomMods.ps1
    - Manage-PackwizMods.ps1

.NOTES
    Requires packwiz to be installed and available in PATH
    Some functions require powershell-yaml module
#>

#region Common Utilities

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info" { "White" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Success" { "Green" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

function Test-PackwizAvailable {
    try {
        $null = Get-Command packwiz -ErrorAction Stop
        return $true
    }
    catch {
        Write-Log "packwiz command not found. Please ensure packwiz is installed and in your PATH." -Level "Error"
        return $false
    }
}

function Invoke-PackwizCommand {
    param(
        [string]$Command,
        [string]$Description,
        [bool]$DryRun = $false,
        [bool]$Force = $false
    )
    
    if ($Force) {
        $Command += " -y"
    }
    
    Write-Log "$Description" -Level "Info"
    Write-Log "Command: $Command" -Level "Info"
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would execute: $Command" -Level "Warning"
        return $true
    }
    
    try {
        $result = Invoke-Expression $Command 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Successfully executed: $Description" -Level "Success"
            return $true
        }
        else {
            Write-Log "Failed to execute: $Description. Exit code: $LASTEXITCODE" -Level "Error"
            Write-Log "Output: $result" -Level "Error"
            return $false
        }
    }
    catch {
        Write-Log "Error executing command: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Install-RequiredModule {
    param([string]$ModuleName)
    
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Log "$ModuleName module not found. Installing..." -Level "Warning"
        try {
            Install-Module -Name $ModuleName -Force -Scope CurrentUser
            Write-Log "Successfully installed $ModuleName module" -Level "Success"
        }
        catch {
            Write-Log "Failed to install $ModuleName module. Please install it manually: Install-Module -Name $ModuleName" -Level "Error"
            throw
        }
    }
    
    try {
        Import-Module $ModuleName
        Write-Log "Successfully imported $ModuleName module" -Level "Success"
    }
    catch {
        Write-Log "Failed to import $ModuleName module: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

#endregion

#region YAML Parsing Functions

function ConvertFrom-SimpleYaml {
    param([string]$YamlContent)
    
    $result = @{}
    $lines = $YamlContent -split "`n"
    $currentSection = $result
    $sectionStack = @()
    
    foreach ($line in $lines) {
        $trimmedLine = $line.Trim()
        
        # Skip empty lines and comments
        if ($trimmedLine -eq "" -or $trimmedLine.StartsWith("#")) {
            continue
        }
        
        # Count indentation
        $indent = ($line -replace '^(\s*)', '').Length
        $indent = $line.Length - $indent
        
        # Handle sections
        if ($trimmedLine.EndsWith(":") -and -not $trimmedLine.Contains(" ")) {
            $sectionName = $trimmedLine.TrimEnd(":")
            
            # Adjust section stack based on indentation
            while ($sectionStack.Count -gt 0 -and $sectionStack[-1].Indent -ge $indent) {
                $sectionStack = $sectionStack[0..($sectionStack.Count - 2)]
            }
            
            # Navigate to parent section
            $currentSection = $result
            foreach ($stackItem in $sectionStack) {
                $currentSection = $currentSection[$stackItem.Name]
            }
            
            # Create new section
            if (-not $currentSection.ContainsKey($sectionName)) {
                $currentSection[$sectionName] = @{}
            }
            
            # Add to stack
            $sectionStack += @{ Name = $sectionName; Indent = $indent }
        }
        # Handle list items
        elseif ($trimmedLine.StartsWith("- ")) {
            $itemContent = $trimmedLine.Substring(2).Trim()
            
            # Navigate to current section
            $currentSection = $result
            foreach ($stackItem in $sectionStack) {
                $currentSection = $currentSection[$stackItem.Name]
            }
            
            # Initialize array if needed
            if (-not $currentSection.ContainsKey("items")) {
                $currentSection["items"] = @()
            }
            
            # Parse item
            if ($itemContent.Contains(":")) {
                $itemObj = @{}
                $parts = $itemContent -split ":", 2
                $key = $parts[0].Trim()
                $value = $parts[1].Trim().Trim('"').Trim("'")
                $itemObj[$key] = $value
                $currentSection["items"] += $itemObj
            }
            else {
                $currentSection["items"] += $itemContent
            }
        }
        # Handle key-value pairs
        elseif ($trimmedLine.Contains(":")) {
            $parts = $trimmedLine -split ":", 2
            $key = $parts[0].Trim()
            $value = $parts[1].Trim().Trim('"').Trim("'")
            
            # Navigate to current section
            $currentSection = $result
            foreach ($stackItem in $sectionStack) {
                $currentSection = $currentSection[$stackItem.Name]
            }
            
            $currentSection[$key] = $value
        }
    }
    
    return $result
}

function Parse-CustomYaml {
    param([string]$FilePath = ".\custom.yml")
    
    if (!(Test-Path $FilePath)) {
        throw "Configuration file not found: $FilePath"
    }
    
    try {
        # Try using powershell-yaml if available
        if (Get-Module -ListAvailable -Name powershell-yaml) {
            Install-RequiredModule -ModuleName "powershell-yaml"
            $yamlContent = Get-Content $FilePath -Raw
            return ConvertFrom-Yaml $yamlContent
        }
        else {
            # Fall back to simple parser
            $yamlContent = Get-Content $FilePath -Raw
            return ConvertFrom-SimpleYaml $yamlContent
        }
    }
    catch {
        Write-Log "Failed to parse YAML config: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

#endregion

#region Mod Management Functions

function Add-CurseForgeMod {
    param(
        [string]$Name,
        [string]$Url,
        [bool]$DryRun = $false,
        [bool]$Force = $false
    )
    
    $command = "packwiz curseforge add `"$Url`""
    $description = "Adding CurseForge mod: $Name"
    
    return Invoke-PackwizCommand -Command $command -Description $description -DryRun $DryRun -Force $Force
}

function Add-ModrinthMod {
    param(
        [string]$Name,
        [string]$Url,
        [bool]$DryRun = $false,
        [bool]$Force = $false
    )
    
    $command = "packwiz modrinth add `"$Url`""
    $description = "Adding Modrinth mod: $Name"
    
    return Invoke-PackwizCommand -Command $command -Description $description -DryRun $DryRun -Force $Force
}

function Remove-Mod {
    param(
        [string]$Name,
        [bool]$DryRun = $false,
        [bool]$Force = $false
    )
    
    # Convert name to a likely filename (lowercase, spaces to hyphens)
    $modFileName = $Name.ToLower() -replace '[^a-z0-9\-_]', '-' -replace '-+', '-'
    
    $command = "packwiz remove `"$modFileName`""
    $description = "Removing mod: $Name (trying filename: $modFileName)"
    
    return Invoke-PackwizCommand -Command $command -Description $description -DryRun $DryRun -Force $Force
}

function Get-CurseForgeProjectId {
    param([string]$Url)
    
    if ($Url -match "curseforge\.com/minecraft/mc-mods/([^/\?]+)") {
        return $matches[1]
    }
    return $null
}

function Get-ExistingMods {
    try {
        $existingMods = @()
        
        if (Test-Path ".\index.toml") {
            $indexContent = Get-Content ".\index.toml" -Raw
            $indexData = ConvertFrom-Toml $indexContent -ErrorAction SilentlyContinue
            
            if ($indexData.files) {
                foreach ($file in $indexData.files) {
                    if ($file.file -like "mods/*.pw.toml") {
                        $modFile = $file.file
                        if (Test-Path $modFile) {
                            try {
                                $modContent = Get-Content $modFile -Raw
                                $modData = ConvertFrom-Toml $modContent -ErrorAction SilentlyContinue
                                if ($modData.name) {
                                    $existingMods += @{
                                        Name = $modData.name
                                        File = $modFile
                                        ProjectId = $modData.update.curseforge.'project-id'
                                    }
                                }
                            }
                            catch {
                                Write-Warning "Could not parse mod file: $modFile"
                            }
                        }
                    }
                }
            }
        }
        
        # Alternative method if index.toml doesn't work
        if ($existingMods.Count -eq 0 -and (Test-Path ".\mods\*.pw.toml")) {
            Get-ChildItem ".\mods\*.pw.toml" | ForEach-Object {
                try {
                    $content = Get-Content $_.FullName -Raw
                    if ($content -match 'name\s*=\s*"([^"]+)"') {
                        $name = $matches[1]
                        $projectId = $null
                        if ($content -match 'project-id\s*=\s*(\d+)') {
                            $projectId = $matches[1]
                        }
                        $existingMods += @{
                            Name = $name
                            File = $_.Name
                            ProjectId = $projectId
                        }
                    }
                }
                catch {
                    Write-Warning "Could not parse: $($_.Name)"
                }
            }
        }
        
        return $existingMods
    }
    catch {
        Write-Warning "Could not read existing mods: $_"
        return @()
    }
}

function ConvertFrom-Toml {
    param([string]$Content)
    
    # Basic TOML parser - for production use, consider a proper TOML module
    $result = @{}
    $lines = $Content -split "`n"
    $currentSection = $result
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        
        if ($line -match '^\[(.+)\]$') {
            $sectionPath = $matches[1] -split '\.'
            $currentSection = $result
            foreach ($section in $sectionPath) {
                if (!$currentSection.ContainsKey($section)) {
                    $currentSection[$section] = @{}
                }
                $currentSection = $currentSection[$section]
            }
        }
        elseif ($line -match '^([^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim(' "')
            $currentSection[$key] = $value
        }
    }
    
    return $result
}

function Invoke-ModOperations {
    param(
        [string]$ConfigFile = "./custom.yml",
        [bool]$DryRun = $false,
        [bool]$Force = $false,
        [ValidateSet("add", "remove", "both")]
        [string]$Action = "both"
    )
    
    Write-Log "Starting mod operations (Action: $Action)" -Level "Info"
    
    # Check if packwiz is available
    if (-not (Test-PackwizAvailable)) {
        return $false
    }
    
    # Check if config file exists
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Config file not found: $ConfigFile" -Level "Error"
        return $false
    }
    
    # Parse YAML config
    try {
        $config = Parse-CustomYaml -FilePath $ConfigFile
        Write-Log "Successfully parsed config file: $ConfigFile" -Level "Success"
    }
    catch {
        Write-Log "Failed to parse YAML config: $($_.Exception.Message)" -Level "Error"
        return $false
    }
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No actual changes will be made" -Level "Warning"
    }
    
    $successCount = 0
    $failureCount = 0
    
    # Process additions
    if ($Action -eq "add" -or $Action -eq "both") {
        if ($config.add) {
            Write-Log "Processing mod additions..." -Level "Info"
            
            # Add CurseForge mods
            if ($config.add.curseforge -and $config.add.curseforge.Count -gt 0) {
                Write-Log "Adding $($config.add.curseforge.Count) CurseForge mod(s)" -Level "Info"
                foreach ($mod in $config.add.curseforge) {
                    if (Add-CurseForgeMod -Name $mod.name -Url $mod.url -DryRun $DryRun -Force $Force) {
                        $successCount++
                    }
                    else {
                        $failureCount++
                    }
                }
            }
            
            # Add Modrinth mods
            if ($config.add.modrinth -and $config.add.modrinth.Count -gt 0) {
                Write-Log "Adding $($config.add.modrinth.Count) Modrinth mod(s)" -Level "Info"
                foreach ($mod in $config.add.modrinth) {
                    if (Add-ModrinthMod -Name $mod.name -Url $mod.url -DryRun $DryRun -Force $Force) {
                        $successCount++
                    }
                    else {
                        $failureCount++
                    }
                }
            }
        }
    }
    
    # Process removals
    if ($Action -eq "remove" -or $Action -eq "both") {
        if ($config.remove) {
            Write-Log "Processing mod removals..." -Level "Info"
            
            # Remove CurseForge mods
            if ($config.remove.curseforge -and $config.remove.curseforge.Count -gt 0) {
                Write-Log "Removing $($config.remove.curseforge.Count) CurseForge mod(s)" -Level "Info"
                foreach ($modName in $config.remove.curseforge) {
                    if (Remove-Mod -Name $modName -DryRun $DryRun -Force $Force) {
                        $successCount++
                    }
                    else {
                        $failureCount++
                    }
                }
            }
            
            # Remove Modrinth mods
            if ($config.remove.modrinth -and $config.remove.modrinth.Count -gt 0) {
                Write-Log "Removing $($config.remove.modrinth.Count) Modrinth mod(s)" -Level "Info"
                foreach ($modName in $config.remove.modrinth) {
                    if (Remove-Mod -Name $modName -DryRun $DryRun -Force $Force) {
                        $successCount++
                    }
                    else {
                        $failureCount++
                    }
                }
            }
        }
    }
    
    # Refresh the index if any changes were made and not in dry run mode
    if (($successCount -gt 0) -and (-not $DryRun)) {
        Write-Log "Refreshing packwiz index..." -Level "Info"
        Invoke-PackwizCommand -Command "packwiz refresh" -Description "Refreshing mod index" -Force $Force
    }
    
    # Summary
    Write-Log "Operation completed!" -Level "Success"
    Write-Log "Successful operations: $successCount" -Level "Success"
    if ($failureCount -gt 0) {
        Write-Log "Failed operations: $failureCount" -Level "Warning"
    }
    
    if ($DryRun) {
        Write-Log "DRY RUN completed - no actual changes were made" -Level "Warning"
    }
    
    return $true
}

function Invoke-SimpleModManagement {
    param(
        [ValidateSet("add", "remove", "both")]
        [string]$Action = "both",
        [bool]$Force = $false
    )
    
    # Check if powershell-yaml is available
    try {
        Install-RequiredModule -ModuleName "powershell-yaml"
    } catch {
        Write-Status "ERROR: Failed to install/import powershell-yaml module" "Red"
        return $false
    }
    
    # Check if packwiz is available
    if (-not (Test-PackwizAvailable)) {
        return $false
    }
    
    # Parse custom.yml
    if (-not (Test-Path "./custom.yml")) {
        Write-Status "ERROR: custom.yml not found in current directory." "Red"
        return $false
    }
    
    try {
        $config = Get-Content "./custom.yml" -Raw | ConvertFrom-Yaml
        Write-Status "Loaded custom.yml configuration" "Green"
    } catch {
        Write-Status "ERROR: Failed to parse custom.yml: $($_.Exception.Message)" "Red"
        return $false
    }
    
    $forceFlag = if ($Force) { " -y" } else { "" }
    
    # Add mods
    if ($Action -eq "add" -or $Action -eq "both") {
        if ($config.add -and $config.add.curseforge -and $config.add.curseforge.Count -gt 0) {
            Write-Status "Adding $($config.add.curseforge.Count) CurseForge mods..." "Cyan"
            foreach ($mod in $config.add.curseforge) {
                Write-Status "  Adding: $($mod.name)" "White"
                $cmd = "packwiz curseforge add `"$($mod.url)`"$forceFlag"
                Invoke-Expression $cmd
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "    Failed to add $($mod.name)" "Red"
                } else {
                    Write-Status "    Successfully added $($mod.name)" "Green"
                }
            }
        }

        if ($config.add -and $config.add.modrinth -and $config.add.modrinth.Count -gt 0) {
            Write-Status "Adding $($config.add.modrinth.Count) Modrinth mods..." "Cyan"
            foreach ($mod in $config.add.modrinth) {
                Write-Status "  Adding: $($mod.name)" "White"
                $cmd = "packwiz modrinth add `"$($mod.url)`"$forceFlag"
                Invoke-Expression $cmd
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "    Failed to add $($mod.name)" "Red"
                } else {
                    Write-Status "    Successfully added $($mod.name)" "Green"
                }
            }
        }
    }
    
    # Remove mods
    if ($Action -eq "remove" -or $Action -eq "both") {
        if ($config.remove -and $config.remove.curseforge -and $config.remove.curseforge.Count -gt 0) {
            Write-Status "Removing $($config.remove.curseforge.Count) CurseForge mods..." "Cyan"
            foreach ($modName in $config.remove.curseforge) {
                Write-Status "  Removing: $modName" "White"
                $modFileName = $modName.ToLower() -replace '[^a-z0-9\-_]', '-' -replace '-+', '-'
                $cmd = "packwiz remove `"$modFileName`"$forceFlag"
                Invoke-Expression $cmd
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "    Failed to remove $modName" "Red"
                } else {
                    Write-Status "    Successfully removed $modName" "Green"
                }
            }
        }

        if ($config.remove -and $config.remove.modrinth -and $config.remove.modrinth.Count -gt 0) {
            Write-Status "Removing $($config.remove.modrinth.Count) Modrinth mods..." "Cyan"
            foreach ($modName in $config.remove.modrinth) {
                Write-Status "  Removing: $modName" "White"
                $modFileName = $modName.ToLower() -replace '[^a-z0-9\-_]', '-' -replace '-+', '-'
                $cmd = "packwiz remove `"$modFileName`"$forceFlag"
                Invoke-Expression $cmd
                if ($LASTEXITCODE -ne 0) {
                    Write-Status "    Failed to remove $modName" "Red"
                } else {
                    Write-Status "    Successfully removed $modName" "Green"
                }
            }
        }
    }
    
    # Refresh index
    Write-Status "Refreshing packwiz index..." "Cyan"
    $cmd = "packwiz refresh$forceFlag"
    Invoke-Expression $cmd
    
    Write-Status "Operation completed!" "Green"
    return $true
}

#endregion

#region Server Deployment Functions

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

function Stop-PackwizServe {
    param($Job)
    if ($Job -and $Job.State -eq "Running") {
        Write-Host "Stopping packwiz serve..." -ForegroundColor Yellow
        Stop-Job $Job -ErrorAction SilentlyContinue
        Remove-Job $Job -ErrorAction SilentlyContinue
    }
}

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

function Invoke-ServerDeployment {
    param(
        [int]$Port = 0,
        [bool]$SkipDownload = $false,
        [bool]$KeepServing = $false,
        [string]$InstallDir = ".server"
    )
    
    # Set error action preference
    $ErrorActionPreference = "Stop"
    
    # Get the root directory (current directory for the module)
    $RootDir = Get-Location
    $BinDir = Join-Path $RootDir ".bin"
    $ServerDir = Join-Path $RootDir $InstallDir
    $ServerFilesDir = Join-Path $RootDir "server"
    $BootstrapJar = Join-Path $BinDir "packwiz-installer-bootstrap.jar"
    
    Write-Host "=== UwUCraft 21 Server Deployment ===" -ForegroundColor Cyan
    Write-Host "Root directory: $RootDir" -ForegroundColor Gray
    Write-Host "Bin directory: $BinDir" -ForegroundColor Gray
    Write-Host "Install directory: $ServerDir" -ForegroundColor Gray
    
    $ServeJob = $null
    
    try {
        # Choose port - either specified or find random available
        if ($Port -eq 0) {
            $Port = Get-RandomAvailablePort
            Write-Host "Using randomly selected port: $Port" -ForegroundColor Gray
        } else {
            Write-Host "Using specified port: $Port" -ForegroundColor Gray
        }
        
        $PackTomlUrl = "http://localhost:$Port/pack.toml"
        
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
        
        Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Error "Deployment failed: $($_.Exception.Message)"
        # Always cleanup on error, regardless of parameters
        if ($ServeJob) {
            Invoke-Cleanup -ServeJob $ServeJob -Port $Port
        }
        return $false
    }
}

#endregion

#region Advanced Mod Management Functions

function Invoke-AdvancedModManagement {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("add", "remove", "sync", "list")]
        [string]$Action,
        
        [string]$ModName,
        [string]$ConfigFile = ".\custom.yml",
        [bool]$DryRun = $false
    )
    
    # Validate packwiz installation
    if (-not (Test-PackwizAvailable)) {
        return $false
    }
    
    # Parse configuration file
    try {
        $customData = Parse-CustomYaml -FilePath $ConfigFile
    }
    catch {
        Write-Log "Failed to parse configuration file: $($_.Exception.Message)" -Level "Error"
        return $false
    }
    
    Write-Host "Packwiz Advanced Mod Manager" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    
    switch ($Action) {
        "add" {
            if ($ModName) {
                # Add specific mod
                $mod = $customData.add.curseforge | Where-Object { $_.name -eq $ModName -or $_.name -like "*$ModName*" }
                if ($mod) {
                    $projectId = Get-CurseForgeProjectId -Url $mod.url
                    if ($projectId) {
                        $command = "packwiz curseforge add $projectId"
                        if ($DryRun) {
                            Write-Host "Would execute: $command" -ForegroundColor Yellow
                        } else {
                            Write-Host "Adding mod: $($mod.name)" -ForegroundColor Green
                            Invoke-Expression $command
                        }
                    }
                } else {
                    Write-Error "Mod '$ModName' not found in custom.yml"
                    return $false
                }
            } else {
                # Add all mods
                if ($customData.add -and $customData.add.curseforge) {
                    foreach ($mod in $customData.add.curseforge) {
                        $projectId = Get-CurseForgeProjectId -Url $mod.url
                        if ($projectId) {
                            $command = "packwiz curseforge add $projectId"
                            if ($DryRun) {
                                Write-Host "Would execute: $command" -ForegroundColor Yellow
                            } else {
                                Write-Host "Adding mod: $($mod.name)" -ForegroundColor Green
                                Invoke-Expression $command
                            }
                        }
                    }
                }
            }
        }
        
        "remove" {
            if (-not $ModName) {
                Write-Error "ModName parameter is required for remove action"
                return $false
            }
            
            $existingMods = Get-ExistingMods
            $modToRemove = $existingMods | Where-Object { $_.Name -eq $ModName -or $_.Name -like "*$ModName*" }
            
            if (-not $modToRemove) {
                Write-Warning "Mod not found: $ModName"
                return $false
            }
            
            if ($modToRemove.Count -gt 1) {
                Write-Host "Multiple mods found matching '$ModName':" -ForegroundColor Yellow
                $modToRemove | ForEach-Object { Write-Host "  - $($_.Name)" }
                return $false
            }
            
            $command = "packwiz remove `"$($modToRemove.Name)`""
            if ($DryRun) {
                Write-Host "Would execute: $command" -ForegroundColor Yellow
            } else {
                Write-Host "Removing mod: $($modToRemove.Name)" -ForegroundColor Red
                Invoke-Expression $command
            }
        }
        
        "sync" {
            $existingMods = Get-ExistingMods
            $targetMods = @()
            
            if ($customData.add -and $customData.add.curseforge) {
                $targetMods = $customData.add.curseforge
            }
            
            Write-Host "Analyzing mod differences..." -ForegroundColor Cyan
            
            # Find mods to add
            $modsToAdd = @()
            foreach ($mod in $targetMods) {
                $projectId = Get-CurseForgeProjectId -Url $mod.url
                $exists = $existingMods | Where-Object { 
                    $_.Name -eq $mod.name -or 
                    $_.ProjectId -eq $projectId -or
                    $_.Name -like "*$($mod.name)*"
                }
                
                if (-not $exists) {
                    $modsToAdd += $mod
                }
            }
            
            if ($modsToAdd.Count -eq 0) {
                Write-Host "No mods need to be added. All mods from custom.yml are already installed." -ForegroundColor Green
                return $true
            }
            
            Write-Host "`nMods to add ($($modsToAdd.Count)):" -ForegroundColor Yellow
            foreach ($mod in $modsToAdd) {
                Write-Host "  + $($mod.name)" -ForegroundColor Yellow
            }
            
            if ($DryRun) {
                Write-Host "`nDry run complete. No changes were made." -ForegroundColor Yellow
                return $true
            }
            
            Write-Host "`nProceeding with mod installation..." -ForegroundColor Green
            
            $successCount = 0
            foreach ($mod in $modsToAdd) {
                $projectId = Get-CurseForgeProjectId -Url $mod.url
                if ($projectId) {
                    Write-Host "Adding: $($mod.name)" -ForegroundColor Green
                    $command = "packwiz curseforge add $projectId"
                    try {
                        Invoke-Expression $command
                        $successCount++
                    } catch {
                        Write-Error "Failed to add mod $($mod.name): $_"
                    }
                }
            }
            
            Write-Host "`nSync complete! Successfully added $successCount out of $($modsToAdd.Count) mods." -ForegroundColor Green
        }
        
        "list" {
            Write-Host "`nMods in custom.yml:" -ForegroundColor Cyan
            Write-Host "===================" -ForegroundColor Cyan
            
            if ($customData.add -and $customData.add.curseforge) {
                foreach ($mod in $customData.add.curseforge) {
                    $projectId = Get-CurseForgeProjectId -Url $mod.url
                    Write-Host "  ✓ $($mod.name)" -ForegroundColor Green
                    Write-Host "    URL: $($mod.url)" -ForegroundColor Gray
                    Write-Host "    Project ID: $projectId" -ForegroundColor Gray
                    Write-Host ""
                }
            }
            
            Write-Host "`nCurrently installed mods:" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            
            $existingMods = Get-ExistingMods
            foreach ($mod in $existingMods) {
                Write-Host "  ✓ $($mod.Name)" -ForegroundColor Green
                Write-Host "    File: $($mod.File)" -ForegroundColor Gray
                if ($mod.ProjectId) {
                    Write-Host "    Project ID: $($mod.ProjectId)" -ForegroundColor Gray
                }
                Write-Host ""
            }
        }
    }
    
    Write-Host "`nOperation completed." -ForegroundColor Green
    return $true
}

#endregion

# Export all public functions
Export-ModuleMember -Function @(
    'Write-Log',
    'Write-Status', 
    'Test-PackwizAvailable',
    'Invoke-PackwizCommand',
    'Install-RequiredModule',
    'Parse-CustomYaml',
    'Add-CurseForgeMod',
    'Add-ModrinthMod', 
    'Remove-Mod',
    'Get-CurseForgeProjectId',
    'Get-ExistingMods',
    'Invoke-ModOperations',
    'Invoke-SimpleModManagement',
    'Invoke-ServerDeployment',
    'Invoke-AdvancedModManagement'
)
