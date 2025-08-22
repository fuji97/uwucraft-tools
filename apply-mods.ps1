#!/usr/bin/env pwsh

# Simple launcher for mod management scripts
# Usage: ./apply-mods.ps1 [options]
#
# Options:
#   --dry-run, -n     : Preview changes without applying them
#   --force, -f       : Apply changes without prompts
#   --add-only        : Only add mods (skip removals)
#   --remove-only     : Only remove mods (skip additions)
#   --help, -h        : Show this help message

param(
    [Alias("n")][switch]$DryRun,
    [Alias("f")][switch]$Force,
    [switch]$AddOnly,
    [switch]$RemoveOnly,
    [Alias("h")][switch]$Help
)

if ($Help) {
    Write-Host "Mod Management Tool"
    Write-Host ""
    Write-Host "Usage: ./apply-mods.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --dry-run, -n     Preview changes without applying them"
    Write-Host "  --force, -f       Apply changes without prompts"
    Write-Host "  --add-only        Only add mods (skip removals)"
    Write-Host "  --remove-only     Only remove mods (skip additions)"
    Write-Host "  --help, -h        Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  ./apply-mods.ps1              # Apply all changes from custom.yml"
    Write-Host "  ./apply-mods.ps1 -n           # Preview changes"
    Write-Host "  ./apply-mods.ps1 -f           # Apply without prompts"
    Write-Host "  ./apply-mods.ps1 --add-only   # Only add new mods"
    return
}

# Build arguments for the main script
$scriptArgs = @()

if ($DryRun) {
    $scriptArgs += "-DryRun"
}

if ($Force) {
    $scriptArgs += "-Force"
}

# Determine action for simple script if using selective mode
if ($AddOnly -and $RemoveOnly) {
    Write-Host "Error: Cannot specify both --add-only and --remove-only" -ForegroundColor Red
    exit 1
}

if ($AddOnly -or $RemoveOnly) {
    # Use simple script for selective operations
    $action = if ($AddOnly) { "add" } else { "remove" }
    $actionArgs = @("-Action", $action)
    if ($Force) { $actionArgs += "-Force" }
    
    Write-Host "Running: ./scripts/Manage-CustomMods.ps1 $($actionArgs -join ' ')" -ForegroundColor Cyan
    & "./scripts/Manage-CustomMods.ps1" @actionArgs
} else {
    # Use full script for complete operations
    Write-Host "Running: ./scripts/Apply-CustomMods.ps1 $($scriptArgs -join ' ')" -ForegroundColor Cyan
    & "./scripts/Apply-CustomMods.ps1" @scriptArgs
}
