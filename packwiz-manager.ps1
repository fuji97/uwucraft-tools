#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple packwiz mod manager for custom.yml

.DESCRIPTION
    A lightweight script to add/remove mods from packwiz using custom.yml configuration.
    This version uses basic YAML parsing to avoid external dependencies.

.PARAMETER Action
    add, remove, sync, or list

.PARAMETER ModName
    Specific mod name (optional)

.PARAMETER DryRun
    Show what would be done without executing

.EXAMPLE
    .\packwiz-manager.ps1 add
    .\packwiz-manager.ps1 remove "Chunky"
    .\packwiz-manager.ps1 sync -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("add", "remove", "sync", "list")]
    [string]$Action,
    
    [string]$ModName,
    [switch]$DryRun
)

# Simple YAML parser for custom.yml structure
function Parse-CustomYaml {
    param([string]$FilePath = ".\custom.yml")
    
    if (!(Test-Path $FilePath)) {
        throw "Configuration file not found: $FilePath"
    }
    
    $content = Get-Content $FilePath
    $mods = @()
    $inCurseForge = $false
    
    foreach ($line in $content) {
        $line = $line.Trim()
        
        if ($line -eq "curseforge:") {
            $inCurseForge = $true
            continue
        }
        
        if ($inCurseForge) {
            if ($line -match "^\s*- name:\s*(.+)$") {
                $modName = $matches[1].Trim('"').Trim("'")
                $currentMod = @{ Name = $modName }
            }
            elseif ($line -match "^\s*url:\s*(.+)$" -and $currentMod) {
                $currentMod.Url = $matches[1].Trim()
                $mods += $currentMod
                $currentMod = $null
            }
            elseif ($line -match "^[a-zA-Z]" -and $line -ne "curseforge:") {
                # New section started
                break
            }
        }
    }
    
    return $mods
}

# Extract CurseForge project ID from URL
function Get-ProjectId {
    param([string]$Url)
    
    if ($Url -match "curseforge\.com/minecraft/mc-mods/([^/\?]+)") {
        return $matches[1]
    }
    return $null
}

# Get currently installed mods
function Get-InstalledMods {
    $mods = @()
    
    if (Test-Path ".\mods\*.pw.toml") {
        Get-ChildItem ".\mods\*.pw.toml" | ForEach-Object {
            try {
                $content = Get-Content $_.FullName -Raw
                if ($content -match 'name\s*=\s*"([^"]+)"') {
                    $name = $matches[1]
                    $projectId = $null
                    if ($content -match 'project-id\s*=\s*(\d+)') {
                        $projectId = $matches[1]
                    }
                    $mods += @{
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
    
    return $mods
}

# Execute packwiz command
function Invoke-PackwizCommand {
    param([string]$Command, [bool]$DryRun = $false)
    
    if ($DryRun) {
        Write-Host "DRY RUN: $Command" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "Executing: $Command" -ForegroundColor Gray
    try {
        Invoke-Expression $Command | Out-Host
        return $true
    }
    catch {
        Write-Error "Command failed: $_"
        return $false
    }
}

# Main execution
Write-Host "Packwiz Mod Manager - Simple Edition" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Check packwiz availability
try {
    $null = packwiz --version 2>$null
}
catch {
    Write-Error "Packwiz not found. Please install packwiz and ensure it's in your PATH."
    exit 1
}

try {
    $configMods = Parse-CustomYaml
    $installedMods = Get-InstalledMods
    
    switch ($Action) {
        "list" {
            Write-Host "`nMods in custom.yml ($($configMods.Count)):" -ForegroundColor Green
            $configMods | ForEach-Object {
                $projectId = Get-ProjectId $_.Url
                Write-Host "  ✓ $($_.Name) (ID: $projectId)" -ForegroundColor White
            }
            
            Write-Host "`nCurrently installed ($($installedMods.Count)):" -ForegroundColor Green
            $installedMods | ForEach-Object {
                Write-Host "  ✓ $($_.Name) [$($_.File)]" -ForegroundColor White
            }
        }
        
        "add" {
            $modsToProcess = if ($ModName) {
                $configMods | Where-Object { $_.Name -like "*$ModName*" }
            } else {
                $configMods
            }
            
            if (!$modsToProcess) {
                Write-Warning "No mods found matching: $ModName"
                exit 1
            }
            
            foreach ($mod in $modsToProcess) {
                $projectId = Get-ProjectId $mod.Url
                if ($projectId) {
                    Write-Host "Adding: $($mod.Name)" -ForegroundColor Green
                    Invoke-PackwizCommand "packwiz curseforge add $projectId" $DryRun
                } else {
                    Write-Warning "Could not extract project ID for: $($mod.Name)"
                }
            }
        }
        
        "remove" {
            if (!$ModName) {
                Write-Error "ModName is required for remove action"
                exit 1
            }
            
            $modToRemove = $installedMods | Where-Object { $_.Name -like "*$ModName*" }
            if (!$modToRemove) {
                Write-Warning "No installed mod found matching: $ModName"
                exit 1
            }
            
            if ($modToRemove.Count -gt 1) {
                Write-Host "Multiple matches found:" -ForegroundColor Yellow
                $modToRemove | ForEach-Object { Write-Host "  - $($_.Name)" }
                exit 1
            }
            
            Write-Host "Removing: $($modToRemove.Name)" -ForegroundColor Red
            Invoke-PackwizCommand "packwiz remove `"$($modToRemove.Name)`"" $DryRun
        }
        
        "sync" {
            Write-Host "Analyzing differences..." -ForegroundColor Cyan
            
            $toAdd = @()
            foreach ($configMod in $configMods) {
                $projectId = Get-ProjectId $configMod.Url
                $isInstalled = $installedMods | Where-Object {
                    $_.Name -eq $configMod.Name -or 
                    $_.ProjectId -eq $projectId -or
                    $_.Name -like "*$($configMod.Name)*"
                }
                
                if (!$isInstalled) {
                    $toAdd += $configMod
                }
            }
            
            if ($toAdd.Count -eq 0) {
                Write-Host "All mods are already installed!" -ForegroundColor Green
            } else {
                Write-Host "`nMods to add ($($toAdd.Count)):" -ForegroundColor Yellow
                $toAdd | ForEach-Object { Write-Host "  + $($_.Name)" -ForegroundColor Yellow }
                
                if (!$DryRun) {
                    Write-Host "`nProceeding with installation..." -ForegroundColor Green
                    foreach ($mod in $toAdd) {
                        $projectId = Get-ProjectId $mod.Url
                        if ($projectId) {
                            Write-Host "Adding: $($mod.Name)" -ForegroundColor Green
                            Invoke-PackwizCommand "packwiz curseforge add $projectId" $false
                        }
                    }
                }
            }
        }
    }
    
    Write-Host "`nCompleted successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}
