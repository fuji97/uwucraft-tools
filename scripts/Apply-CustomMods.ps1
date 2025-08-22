#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Applies mod changes defined in custom.yml using packwiz commands.

.DESCRIPTION
    This script parses the custom.yml file and uses packwiz CLI commands to:
    - Add mods from CurseForge and Modrinth as specified in the 'add' section
    - Remove mods from CurseForge and Modrinth as specified in the 'remove' section

.PARAMETER ConfigFile
    Path to the custom.yml configuration file (default: "./custom.yml")

.PARAMETER DryRun
    If specified, shows what would be done without actually executing packwiz commands

.PARAMETER Force
    If specified, uses the -y flag with packwiz commands for non-interactive mode

.EXAMPLE
    .\Apply-CustomMods.ps1
    Applies changes from ./custom.yml

.EXAMPLE
    .\Apply-CustomMods.ps1 -DryRun
    Shows what would be done without executing commands

.EXAMPLE
    .\Apply-CustomMods.ps1 -Force
    Applies changes automatically without prompts
#>

param(
    [string]$ConfigFile = "./custom.yml",
    [switch]$DryRun,
    [switch]$Force
)

# Import required modules
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Warning "powershell-yaml module not found. Installing..."
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser
    }
    catch {
        Write-Error "Failed to install powershell-yaml module. Please install it manually: Install-Module -Name powershell-yaml"
        exit 1
    }
}

Import-Module powershell-yaml

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
        [string]$Description
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

function Add-CurseForgeMod {
    param(
        [string]$Name,
        [string]$Url
    )
    
    $command = "packwiz curseforge add `"$Url`""
    $description = "Adding CurseForge mod: $Name"
    
    return Invoke-PackwizCommand -Command $command -Description $description
}

function Add-ModrinthMod {
    param(
        [string]$Name,
        [string]$Url
    )
    
    $command = "packwiz modrinth add `"$Url`""
    $description = "Adding Modrinth mod: $Name"
    
    return Invoke-PackwizCommand -Command $command -Description $description
}

function Remove-Mod {
    param(
        [string]$Name
    )
    
    # Convert name to a likely filename (lowercase, spaces to hyphens)
    $modFileName = $Name.ToLower() -replace '[^a-z0-9\-_]', '-' -replace '-+', '-'
    
    $command = "packwiz remove `"$modFileName`""
    $description = "Removing mod: $Name (trying filename: $modFileName)"
    
    return Invoke-PackwizCommand -Command $command -Description $description
}

function Main {
    Write-Log "Starting custom mod application script" -Level "Info"
    
    # Check if packwiz is available
    if (-not (Test-PackwizAvailable)) {
        exit 1
    }
    
    # Check if config file exists
    if (-not (Test-Path $ConfigFile)) {
        Write-Log "Config file not found: $ConfigFile" -Level "Error"
        exit 1
    }
    
    # Parse YAML config
    try {
        $yamlContent = Get-Content $ConfigFile -Raw
        $config = ConvertFrom-Yaml $yamlContent
        Write-Log "Successfully parsed config file: $ConfigFile" -Level "Success"
    }
    catch {
        Write-Log "Failed to parse YAML config: $($_.Exception.Message)" -Level "Error"
        exit 1
    }
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No actual changes will be made" -Level "Warning"
    }
    
    $successCount = 0
    $failureCount = 0
    
    # Process additions
    if ($config.add) {
        Write-Log "Processing mod additions..." -Level "Info"
        
        # Add CurseForge mods
        if ($config.add.curseforge -and $config.add.curseforge.Count -gt 0) {
            Write-Log "Adding $($config.add.curseforge.Count) CurseForge mod(s)" -Level "Info"
            foreach ($mod in $config.add.curseforge) {
                if (Add-CurseForgeMod -Name $mod.name -Url $mod.url) {
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
                if (Add-ModrinthMod -Name $mod.name -Url $mod.url) {
                    $successCount++
                }
                else {
                    $failureCount++
                }
            }
        }
    }
    
    # Process removals
    if ($config.remove) {
        Write-Log "Processing mod removals..." -Level "Info"
        
        # Remove CurseForge mods
        if ($config.remove.curseforge -and $config.remove.curseforge.Count -gt 0) {
            Write-Log "Removing $($config.remove.curseforge.Count) CurseForge mod(s)" -Level "Info"
            foreach ($modName in $config.remove.curseforge) {
                if (Remove-Mod -Name $modName) {
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
                if (Remove-Mod -Name $modName) {
                    $successCount++
                }
                else {
                    $failureCount++
                }
            }
        }
    }
    
    # Refresh the index if any changes were made and not in dry run mode
    if (($successCount -gt 0) -and (-not $DryRun)) {
        Write-Log "Refreshing packwiz index..." -Level "Info"
        Invoke-PackwizCommand -Command "packwiz refresh" -Description "Refreshing mod index"
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
}

# Execute main function
Main
