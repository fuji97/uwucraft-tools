# Server Deployment Script Documentation

## Overview
The deployment script (`Deploy-Server.ps1`) automates the process of creating a server package from your UwUCraft 21 modpack using packwiz tools.

## Files Created
- `scripts/Deploy-Server.ps1` - Main deployment script
- `deploy-server.cmd` - Batch wrapper for easy execution
- `deploy-server.ps1` - PowerShell wrapper in root directory

## Features
- ✅ Automatic random port selection (8000-9999 range)
- ✅ **Centralized installer in `.bin/` directory**
- ✅ **Configurable installation directory** (default: `.server`)
- ✅ Starts `packwiz serve` in background
- ✅ Downloads `packwiz-installer-bootstrap.jar` automatically
- ✅ Uses `--pack-folder` parameter for clean separation
- ✅ Handles CurseForge API excluded mods gracefully
- ✅ Copies override files from `server/` to install directory
- ✅ Port conflict detection and automatic cleanup
- ✅ **Always kills packwiz serve process** (even on errors)
- ✅ **No artifact cleanup needed** (kept in `.bin/`)
- ✅ Comprehensive error handling and logging

## Usage

### Basic Usage
```powershell
# Using PowerShell wrapper
.\deploy-server.ps1

# Using batch file
.\deploy-server.cmd

# Using the main script directly
.\scripts\Deploy-Server.ps1
```

### Advanced Options
```powershell
# Use a different port (default: random selection)
.\deploy-server.ps1 -Port 9090

# Use custom installation directory (default: .server)
.\deploy-server.ps1 -InstallDir "my-server"

# Skip downloading JAR if it already exists
.\deploy-server.ps1 -SkipDownload

# Keep packwiz serve running after deployment
.\deploy-server.ps1 -KeepServing

# Combine options
.\deploy-server.ps1 -InstallDir "prod-server" -Port 8080 -SkipDownload
```

## What the Script Does

### Step 1: Directory Setup
- Creates `.bin/` directory for installer artifacts
- Creates installation directory (default: `.server/`, configurable)
- Clean separation between tools and server files

### Step 2: Download Dependencies
- Downloads `packwiz-installer-bootstrap.jar` to `.bin/` directory
- Can be skipped with `-SkipDownload` if file already exists
- Installer artifacts remain in `.bin/` for reuse

### Step 3: Start Packwiz Server
- Automatically selects a random available port (8000-9999) if none specified
- Starts `packwiz serve` on specified port
- Automatically detects and resolves port conflicts
- Runs in background PowerShell job
- **Always terminated at the end** (even on script errors)

### Step 4: Server Availability Testing
- Tests if packwiz server is responding
- Retries up to 10 times with 2-second intervals
- Ensures server is ready before proceeding

### Step 5: Install Server Package
- Runs from `.bin/` directory: `java -jar packwiz-installer-bootstrap.jar -g -s server --pack-folder ../INSTALL_DIR http://localhost:PORT/pack.toml`
- Uses `--pack-folder` parameter to specify installation directory
- Downloads all available mods and creates server structure
- Gracefully handles CurseForge API excluded mods

### Step 6: Override Files
- Copies any files from `server/` directory to installation directory
- Allows customization of server configuration  
- Overwrites any existing files

### Step 7: Cleanup
- **Always stops packwiz serve process** (unless `-KeepServing` is used)
- **Installer artifacts remain in `.bin/`** for future use
- Cleans up temporary files
- **Guaranteed cleanup even on script errors**
- Reports completion status

## Handling Excluded Mods

Some mods are excluded from the CurseForge API and must be downloaded manually. The script will:
- Continue deployment with available mods
- Show warnings about excluded mods
- Provide direct download links for manual downloads
- List all manual downloads needed at the end

Example excluded mods in UwUCraft 21:
- Bad Wither No Cookie - Reloaded
- I'm Fast
- More Overlays Updated
- Not Enough Animations
- Structory & Structory: Towers
- Time in a bottle

## Server Override Files

Place any server-specific files in the `server/` directory:
- `server.properties` - Server configuration
- `eula.txt` - EULA acceptance
- `whitelist.json` - Player whitelist
- `ops.json` - Server operators
- Custom scripts, configs, etc.

These files will automatically be copied to `.server/` during deployment.

## Output Directories

### `.bin/` Directory
Contains installer tools and artifacts:
- `packwiz-installer-bootstrap.jar` - Bootstrap installer
- `packwiz-installer.jar` - Main installer (downloaded during first run)
- These files are preserved for future deployments

### Installation Directory (configurable)
The final server files are created in the specified directory (default: `.server/`) and include:
- All automatically downloaded mods
- Server configuration and structure  
- Any override files from `server/`

**Examples:**
- Default: `.server/` directory
- Custom: `.\deploy-server.ps1 -InstallDir "prod-server"` creates `prod-server/` directory

## Troubleshooting

### Port Already in Use
The script automatically detects and stops processes using the specified port.

### Java Not Found
Ensure Java is installed and available in your PATH.

### Manual Mod Downloads
Download excluded mods manually from the provided CurseForge links and place them in `.server/mods/`.

### Permission Issues
Run PowerShell with appropriate execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Examples

### Full deployment with custom port
```powershell
.\deploy-server.ps1 -Port 9090
```

### Quick re-deployment (skip download, keep serving)
```powershell
.\deploy-server.ps1 -SkipDownload -KeepServing
```

### First-time setup
```powershell
.\deploy-server.ps1
# Script will download everything needed and complete setup
```
