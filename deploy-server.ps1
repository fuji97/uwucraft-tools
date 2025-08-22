# UwUCraft 21 Server Deployment Wrapper
# This script calls the main deployment script in the scripts directory

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

$ScriptPath = Join-Path $PSScriptRoot "scripts\Deploy-Server.ps1"

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Deploy-Server.ps1 not found at: $ScriptPath"
    exit 1
}

# Forward all parameters to the main script
$Arguments = @{}
if ($PSBoundParameters.ContainsKey('Port')) { $Arguments['Port'] = $Port }
if ($SkipDownload) { $Arguments['SkipDownload'] = $true }
if ($KeepServing) { $Arguments['KeepServing'] = $true }
if ($PSBoundParameters.ContainsKey('InstallDir')) { $Arguments['InstallDir'] = $InstallDir }

& $ScriptPath @Arguments
