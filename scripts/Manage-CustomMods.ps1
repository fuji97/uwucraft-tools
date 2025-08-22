#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Simple PowerShell script to manage mods using packwiz commands based on custom.yml.

.DESCRIPTION
    This is a simplified version of Apply-CustomMods.ps1 that provides basic functionality
    to add and remove mods using packwiz CLI commands.

.PARAMETER Action
    The action to perform: 'add', 'remove', or 'both' (default: 'both')

.PARAMETER Force
    If specified, uses the -y flag with packwiz commands for non-interactive mode

.EXAMPLE
    .\Manage-CustomMods.ps1
    Applies both additions and removals from custom.yml

.EXAMPLE
    .\Manage-CustomMods.ps1 -Action add -Force
    Only adds mods automatically without prompts
#>

param(
    [ValidateSet("add", "remove", "both")]
    [string]$Action = "both",
    [switch]$Force
)

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor $Color
}

# Check if powershell-yaml is available
try {
    Import-Module powershell-yaml -ErrorAction Stop
} catch {
    Write-Status "Installing powershell-yaml module..." "Yellow"
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser -ErrorAction Stop
    Import-Module powershell-yaml
}

# Check if packwiz is available
try {
    $null = Get-Command packwiz -ErrorAction Stop
} catch {
    Write-Status "ERROR: packwiz command not found. Please install packwiz." "Red"
    exit 1
}

# Parse custom.yml
if (-not (Test-Path "./custom.yml")) {
    Write-Status "ERROR: custom.yml not found in current directory." "Red"
    exit 1
}

try {
    $config = Get-Content "./custom.yml" -Raw | ConvertFrom-Yaml
    Write-Status "Loaded custom.yml configuration" "Green"
} catch {
    Write-Status "ERROR: Failed to parse custom.yml: $($_.Exception.Message)" "Red"
    exit 1
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
