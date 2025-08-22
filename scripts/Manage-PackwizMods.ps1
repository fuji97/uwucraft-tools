#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Manages mods in a packwiz project by parsing custom.yml and executing packwiz commands.

.DESCRIPTION
    This script parses the custom.yml file to add or remove mods from a packwiz project.
    It supports CurseForge mods and can handle both adding and removing operations.

.PARAMETER Action
    The action to perform: "add", "remove", "sync", or "list"

.PARAMETER ModName
    The name of a specific mod to add or remove (optional for single mod operations)

.PARAMETER ConfigFile
    Path to the custom.yml file (defaults to ./custom.yml)

.PARAMETER DryRun
    Show what would be done without actually executing packwiz commands

.EXAMPLE
    .\Manage-PackwizMods.ps1 -Action add
    Adds all mods listed in the custom.yml file

.EXAMPLE
    .\Manage-PackwizMods.ps1 -Action remove -ModName "Chunky"
    Removes the Chunky mod

.EXAMPLE
    .\Manage-PackwizMods.ps1 -Action sync -DryRun
    Shows what mods would be added/removed to sync with custom.yml
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("add", "remove", "sync", "list")]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$ModName,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = ".\custom.yml",
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

# Import required modules
if (!(Get-Module -ListAvailable -Name PowerShell-Yaml)) {
    Write-Warning "PowerShell-Yaml module not found. Installing..."
    Install-Module -Name PowerShell-Yaml -Force -Scope CurrentUser
}
Import-Module PowerShell-Yaml

# Function to validate packwiz installation
function Test-PackwizInstallation {
    try {
        $result = packwiz --version 2>$null
        return $true
    }
    catch {
        Write-Error "Packwiz is not installed or not in PATH. Please install packwiz first."
        return $false
    }
}

# Function to parse custom.yml
function Get-CustomYamlData {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) {
        Write-Error "Configuration file not found: $FilePath"
        return $null
    }
    
    try {
        $yamlContent = Get-Content $FilePath -Raw
        $data = ConvertFrom-Yaml $yamlContent
        return $data
    }
    catch {
        Write-Error "Failed to parse YAML file: $_"
        return $null
    }
}

# Function to get CurseForge project ID from URL
function Get-CurseForgeProjectId {
    param([string]$Url)
    
    if ($Url -match "curseforge\.com/minecraft/mc-mods/([^/\?]+)") {
        return $matches[1]
    }
    return $null
}

# Function to get existing mods from packwiz
function Get-ExistingMods {
    try {
        $indexContent = Get-Content ".\index.toml" -Raw
        $indexData = ConvertFrom-Toml $indexContent -ErrorAction SilentlyContinue
        
        $existingMods = @()
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
        return $existingMods
    }
    catch {
        Write-Warning "Could not read existing mods from index.toml: $_"
        return @()
    }
}

# Function to convert TOML (simplified implementation)
function ConvertFrom-Toml {
    param([string]$Content)
    
    # This is a very basic TOML parser - for production use, consider a proper TOML module
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

# Function to add a mod
function Add-Mod {
    param(
        [string]$Name,
        [string]$Url,
        [bool]$DryRun = $false
    )
    
    $projectId = Get-CurseForgeProjectId -Url $Url
    if (!$projectId) {
        Write-Warning "Could not extract project ID from URL: $Url"
        return $false
    }
    
    $command = "packwiz curseforge add $projectId"
    
    if ($DryRun) {
        Write-Host "Would execute: $command" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "Adding mod: $Name" -ForegroundColor Green
    Write-Host "Executing: $command" -ForegroundColor Gray
    
    try {
        $result = Invoke-Expression $command
        Write-Host "Successfully added: $Name" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to add mod $Name`: $_"
        return $false
    }
}

# Function to remove a mod
function Remove-Mod {
    param(
        [string]$Name,
        [bool]$DryRun = $false
    )
    
    # Find the mod file
    $existingMods = Get-ExistingMods
    $modToRemove = $existingMods | Where-Object { $_.Name -eq $Name -or $_.Name -like "*$Name*" }
    
    if (!$modToRemove) {
        Write-Warning "Mod not found: $Name"
        return $false
    }
    
    if ($modToRemove.Count -gt 1) {
        Write-Host "Multiple mods found matching '$Name':" -ForegroundColor Yellow
        $modToRemove | ForEach-Object { Write-Host "  - $($_.Name)" }
        return $false
    }
    
    $command = "packwiz remove `"$($modToRemove.Name)`""
    
    if ($DryRun) {
        Write-Host "Would execute: $command" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "Removing mod: $($modToRemove.Name)" -ForegroundColor Red
    Write-Host "Executing: $command" -ForegroundColor Gray
    
    try {
        $result = Invoke-Expression $command
        Write-Host "Successfully removed: $($modToRemove.Name)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to remove mod $($modToRemove.Name): $_"
        return $false
    }
}

# Function to list mods
function Show-ModsList {
    param([hashtable]$CustomData)
    
    Write-Host "`nMods in custom.yml:" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    if ($CustomData.add -and $CustomData.add.curseforge) {
        foreach ($mod in $CustomData.add.curseforge) {
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

# Function to sync mods
function Sync-Mods {
    param(
        [hashtable]$CustomData,
        [bool]$DryRun = $false
    )
    
    $existingMods = Get-ExistingMods
    $targetMods = @()
    
    if ($CustomData.add -and $CustomData.add.curseforge) {
        $targetMods = $CustomData.add.curseforge
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
        
        if (!$exists) {
            $modsToAdd += $mod
        }
    }
    
    # Find mods to remove (this would require a remove section in custom.yml)
    # For now, we'll just add missing mods
    
    if ($modsToAdd.Count -eq 0) {
        Write-Host "No mods need to be added. All mods from custom.yml are already installed." -ForegroundColor Green
        return
    }
    
    Write-Host "`nMods to add ($($modsToAdd.Count)):" -ForegroundColor Yellow
    foreach ($mod in $modsToAdd) {
        Write-Host "  + $($mod.name)" -ForegroundColor Yellow
    }
    
    if ($DryRun) {
        Write-Host "`nDry run complete. No changes were made." -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nProceeding with mod installation..." -ForegroundColor Green
    
    $successCount = 0
    foreach ($mod in $modsToAdd) {
        if (Add-Mod -Name $mod.name -Url $mod.url -DryRun $false) {
            $successCount++
        }
    }
    
    Write-Host "`nSync complete! Successfully added $successCount out of $($modsToAdd.Count) mods." -ForegroundColor Green
}

# Main script execution
Write-Host "Packwiz Mod Manager" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# Validate packwiz installation
if (!(Test-PackwizInstallation)) {
    exit 1
}

# Parse configuration file
$customData = Get-CustomYamlData -FilePath $ConfigFile
if (!$customData) {
    exit 1
}

# Execute requested action
switch ($Action) {
    "add" {
        if ($ModName) {
            # Add specific mod
            $mod = $customData.add.curseforge | Where-Object { $_.name -eq $ModName -or $_.name -like "*$ModName*" }
            if ($mod) {
                Add-Mod -Name $mod.name -Url $mod.url -DryRun $DryRun
            } else {
                Write-Error "Mod '$ModName' not found in custom.yml"
            }
        } else {
            # Add all mods
            if ($customData.add -and $customData.add.curseforge) {
                foreach ($mod in $customData.add.curseforge) {
                    Add-Mod -Name $mod.name -Url $mod.url -DryRun $DryRun
                }
            }
        }
    }
    
    "remove" {
        if (!$ModName) {
            Write-Error "ModName parameter is required for remove action"
            exit 1
        }
        Remove-Mod -Name $ModName -DryRun $DryRun
    }
    
    "sync" {
        Sync-Mods -CustomData $customData -DryRun $DryRun
    }
    
    "list" {
        Show-ModsList -CustomData $customData
    }
}

Write-Host "`nOperation completed." -ForegroundColor Green
