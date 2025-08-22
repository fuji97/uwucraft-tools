#!/usr/bin/env pwsh

<#
.SYNOPSIS
    UwUCraft Tools - Unified mod and server management wrapper

.DESCRIPTION
    This script provides a unified interface for all UwUCraft mod and server management operations.
    It replaces the individual wrapper scripts and provides a single entry point for all functionality.
    
    This version supports shell-like syntax with double-dash arguments (--option) as well as traditional
    PowerShell parameters (-Option).

.PARAMETER Action
    The action to perform:
    - mods: Manage mods (add/remove from custom.yml)
    - deploy: Deploy server
    - advanced: Advanced mod management with more options
    - help: Show detailed help

.NOTES
    Shell-like syntax examples:
    ./uwucraft-tools.ps1 mods --dry-run --force
    ./uwucraft-tools.ps1 deploy --port 8080 --keep-serving
    ./uwucraft-tools.ps1 advanced --sync --dry-run

.EXAMPLE
    ./uwucraft-tools.ps1 mods
    Apply all mod changes from custom.yml

.EXAMPLE
    ./uwucraft-tools.ps1 mods --add --force
    Add only new mods without prompts

.EXAMPLE
    ./uwucraft-tools.ps1 deploy --port 8080
    Deploy server using port 8080

.EXAMPLE
    ./uwucraft-tools.ps1 advanced --sync --dry-run
    Preview what mods would be synchronized

.EXAMPLE
    ./uwucraft-tools.ps1 help
    Show detailed help information
#>

# Handle shell-like argument parsing
function ConvertTo-PowerShellArgs {
    param([string[]]$Arguments)
    
    $result = @{}
    $i = 0
    
    while ($i -lt $Arguments.Length) {
        $arg = $Arguments[$i]
        
        # Handle double-dash arguments
        if ($arg.StartsWith("--")) {
            $argName = $arg.Substring(2)
            
            # Check if next argument is a value (doesn't start with --)
            if (($i + 1) -lt $Arguments.Length -and -not $Arguments[$i + 1].StartsWith("--")) {
                $result[$argName] = $Arguments[$i + 1]
                $i += 2
            } else {
                $result[$argName] = $true
                $i++
            }
        }
        # Handle single-dash arguments (traditional PowerShell)
        elseif ($arg.StartsWith("-")) {
            $argName = $arg.Substring(1)
            
            # Check if next argument is a value
            if (($i + 1) -lt $Arguments.Length -and -not $Arguments[$i + 1].StartsWith("-")) {
                $result[$argName] = $Arguments[$i + 1]
                $i += 2
            } else {
                $result[$argName] = $true
                $i++
            }
        }
        else {
            $i++
        }
    }
    
    return $result
}

# Parse shell-like arguments from $args
$ParsedArgs = ConvertTo-PowerShellArgs $args

# Extract action (first non-flag argument)
$Action = $args | Where-Object { -not $_.StartsWith("-") } | Select-Object -First 1

if (-not $Action) {
    Write-Error "Action is required. Use: mods, deploy, advanced, or help"
    exit 1
}

# Map parsed arguments to variables
$Add = $ParsedArgs.ContainsKey("add")
$Remove = $ParsedArgs.ContainsKey("remove")
$Sync = $ParsedArgs.ContainsKey("sync")
$List = $ParsedArgs.ContainsKey("list")
$DryRun = $ParsedArgs.ContainsKey("dry-run") -or $ParsedArgs.ContainsKey("DryRun")
$Force = $ParsedArgs.ContainsKey("force") -or $ParsedArgs.ContainsKey("Force")

$ModName = $ParsedArgs["mod-name"] ?? $ParsedArgs["ModName"]
$ConfigFile = $ParsedArgs["config"] ?? $ParsedArgs["ConfigFile"] ?? "./custom.yml"
$ServerPort = [int]($ParsedArgs["port"] ?? $ParsedArgs["Port"] ?? 0)
$SkipDownload = $ParsedArgs.ContainsKey("skip-download") -or $ParsedArgs.ContainsKey("SkipDownload")
$KeepServing = $ParsedArgs.ContainsKey("keep-serving") -or $ParsedArgs.ContainsKey("KeepServing")
$InstallDir = $ParsedArgs["install-dir"] ?? $ParsedArgs["InstallDir"] ?? ".server"

# Import the UwUCraft Tools module
$ModulePath = Join-Path $PSScriptRoot "UwUCraftTools.psm1"

if (-not (Test-Path $ModulePath)) {
    Write-Error "UwUCraftTools.psm1 not found at: $ModulePath"
    Write-Error "Please ensure the module file exists in the same directory as this script."
    exit 1
}

try {
    Import-Module $ModulePath -Force
}
catch {
    Write-Error "Failed to import UwUCraftTools module: $($_.Exception.Message)"
    exit 1
}

function Show-Help {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                                   UwUCraft Tools                                     ║
║                          Unified Mod and Server Management                           ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝

USAGE:
    ./uwucraft-tools.ps1 <action> [options]

ACTIONS:
    mods        Manage mods using custom.yml configuration
    deploy      Deploy server package
    advanced    Advanced mod management with individual mod control
    help        Show this help information

MOD MANAGEMENT (mods):
    ./uwucraft-tools.ps1 mods [options]
    
    Options:
        --add                 Only add mods (skip removals)
        --remove              Only remove mods (skip additions)
        --dry-run             Preview changes without applying them
        --force               Apply changes without prompts
        --config <path>       Path to custom.yml (default: ./custom.yml)
    
    Examples:
        ./uwucraft-tools.ps1 mods
        ./uwucraft-tools.ps1 mods --add --force
        ./uwucraft-tools.ps1 mods --dry-run

SERVER DEPLOYMENT (deploy):
    ./uwucraft-tools.ps1 deploy [options]
    
    Options:
        --port <number>       Port for packwiz serve (default: random)
        --skip-download       Skip downloading bootstrap if it exists
        --keep-serving        Keep packwiz serve running after deployment
        --install-dir <path>  Installation directory (default: .server)
    
    Examples:
        ./uwucraft-tools.ps1 deploy
        ./uwucraft-tools.ps1 deploy --port 8080 --keep-serving

ADVANCED MOD MANAGEMENT (advanced):
    ./uwucraft-tools.ps1 advanced <action> [options]
    
    Actions:
        --add                 Add mods from custom.yml
        --remove <name>       Remove a specific mod
        --sync                Synchronize with custom.yml (add missing mods)
        --list                List mods in custom.yml and installed mods
    
    Options:
        --mod-name <name>     Specific mod name (required for --remove)
        --dry-run             Preview changes without applying them
        --config <path>       Path to custom.yml (default: ./custom.yml)
    
    Examples:
        ./uwucraft-tools.ps1 advanced --list
        ./uwucraft-tools.ps1 advanced --remove --mod-name "Chunky"
        ./uwucraft-tools.ps1 advanced --sync --dry-run

CONFIGURATION:
    All mod operations use a custom.yml file with the following structure:
    
    add:
      curseforge:
        - name: "Mod Name"
          url: "https://www.curseforge.com/minecraft/mc-mods/mod-slug"
      modrinth:
        - name: "Mod Name"
          url: "https://modrinth.com/mod/mod-slug"
    
    remove:
      curseforge:
        - "Mod Name to Remove"
      modrinth:
        - "Another Mod Name"

REQUIREMENTS:
    - PowerShell 5.1 or later
    - packwiz installed and in PATH
    - Java (for server deployment)
    - powershell-yaml module (automatically installed if needed)

For more information, visit: https://github.com/uwucraft/uwucraft-tools
"@ -ForegroundColor Cyan
}

function Show-Banner {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════════════════╗
║                                   UwUCraft Tools                                     ║
║                          Unified Mod and Server Management                           ║
╚═══════════════════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
}

# Main execution
Show-Banner

switch ($Action) {
    "help" {
        Show-Help
        exit 0
    }
    
    "mods" {
        Write-Host "Action: Mod Management" -ForegroundColor Green
        
        # Determine sub-action from flags
        $SubAction = "both"  # default
        if ($Add -and $Remove) {
            Write-Error "Cannot specify both --add and --remove"
            exit 1
        }
        elseif ($Add) {
            $SubAction = "add"
        }
        elseif ($Remove) {
            $SubAction = "remove"
        }
        
        Write-Host "Sub-action: $SubAction" -ForegroundColor Gray
        
        if ($DryRun) {
            Write-Host "Mode: Dry Run (preview only)" -ForegroundColor Yellow
        }
        
        if ($Force) {
            Write-Host "Mode: Force (non-interactive)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        
        try {
            $success = Invoke-ModOperations -ConfigFile $ConfigFile -DryRun $DryRun -Force $Force -Action $SubAction
            if (-not $success) {
                exit 1
            }
        }
        catch {
            Write-Error "Mod management failed: $($_.Exception.Message)"
            exit 1
        }
    }
    
    "deploy" {
        Write-Host "Action: Server Deployment" -ForegroundColor Green
        Write-Host "Install Directory: $InstallDir" -ForegroundColor Gray
        
        if ($ServerPort -ne 0) {
            Write-Host "Port: $ServerPort" -ForegroundColor Gray
        }
        
        if ($SkipDownload) {
            Write-Host "Skip Download: Enabled" -ForegroundColor Gray
        }
        
        if ($KeepServing) {
            Write-Host "Keep Serving: Enabled" -ForegroundColor Gray
        }
        
        Write-Host ""
        
        try {
            $success = Invoke-ServerDeployment -Port $ServerPort -SkipDownload $SkipDownload -KeepServing $KeepServing -InstallDir $InstallDir
            if (-not $success) {
                exit 1
            }
        }
        catch {
            Write-Error "Server deployment failed: $($_.Exception.Message)"
            exit 1
        }
    }
    
    "advanced" {
        Write-Host "Action: Advanced Mod Management" -ForegroundColor Green
        
        # Determine sub-action from flags
        $SubAction = ""
        $actionCount = 0
        
        if ($Add) { $SubAction = "add"; $actionCount++ }
        if ($Remove) { $SubAction = "remove"; $actionCount++ }
        if ($Sync) { $SubAction = "sync"; $actionCount++ }
        if ($List) { $SubAction = "list"; $actionCount++ }
        
        if ($actionCount -eq 0) {
            Write-Error "Advanced mode requires an action: --add, --remove, --sync, or --list"
            exit 1
        }
        
        if ($actionCount -gt 1) {
            Write-Error "Advanced mode can only perform one action at a time"
            exit 1
        }
        
        Write-Host "Sub-action: $SubAction" -ForegroundColor Gray
        
        if ($ModName) {
            Write-Host "Mod Name: $ModName" -ForegroundColor Gray
        }
        
        if ($DryRun) {
            Write-Host "Mode: Dry Run (preview only)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        
        # Validate ModName for remove action
        if ($SubAction -eq "remove" -and -not $ModName) {
            Write-Error "--mod-name is required for --remove action"
            exit 1
        }
        
        try {
            $success = Invoke-AdvancedModManagement -Action $SubAction -ModName $ModName -ConfigFile $ConfigFile -DryRun $DryRun
            if (-not $success) {
                exit 1
            }
        }
        catch {
            Write-Error "Advanced mod management failed: $($_.Exception.Message)"
            exit 1
        }
    }
    
    default {
        Write-Error "Unknown action: $Action"
        Write-Host "Use '.\uwucraft-tools.ps1 help' for usage information." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "`n╔═══════════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                 Operation Complete                                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
