# UwUCraft Tools - Refactored Structure

This project has been refactored to provide a unified, modular approach to mod and server management for UwUCraft projects.

## 🚀 Quick Start

Use the new unified wrapper:

```bash
# Apply mod changes from custom.yml
./uwucraft-tools.ps1 mods

# Deploy server
./uwucraft-tools.ps1 deploy

# Show help
./uwucraft-tools.ps1 help
```

## 📖 Usage Guide

### Mod Management

#### Basic Mod Operations
```bash
# Apply all changes from custom.yml
./uwucraft-tools.ps1 mods

# Only add mods
./uwucraft-tools.ps1 mods --add

# Only remove mods  
./uwucraft-tools.ps1 mods --remove

# Preview changes without applying
./uwucraft-tools.ps1 mods --dry-run

# Apply changes without prompts
./uwucraft-tools.ps1 mods --force
```

#### Advanced Mod Management
```bash
# List all mods
./uwucraft-tools.ps1 advanced --list

# Sync with custom.yml (add missing mods)
./uwucraft-tools.ps1 advanced --sync

# Remove specific mod
./uwucraft-tools.ps1 advanced --remove --mod-name "Chunky"

# Preview sync operation
./uwucraft-tools.ps1 advanced --sync --dry-run
```

### Server Deployment

```bash
# Basic deployment
./uwucraft-tools.ps1 deploy

# Use specific port
./uwucraft-tools.ps1 deploy --port 8080

# Keep packwiz serve running
./uwucraft-tools.ps1 deploy --keep-serving

# Custom install directory
./uwucraft-tools.ps1 deploy --install-dir "my-server"

# Skip download if bootstrap exists
./uwucraft-tools.ps1 deploy --skip-download
```

## 📋 Configuration

### custom.yml Structure
```yaml
add:
  curseforge:
    - name: "JEI"
      url: "https://www.curseforge.com/minecraft/mc-mods/jei"
    - name: "OptiFine"
      url: "https://www.curseforge.com/minecraft/mc-mods/optifine"
  modrinth:
    - name: "Lithium"
      url: "https://modrinth.com/mod/lithium"

remove:
  curseforge:
    - "Old Mod Name"
  modrinth:
    - "Another Old Mod"
```

### Using Module Functions Directly

You can also import the module and use functions directly:

```powershell
Import-Module .\UwUCraftTools.psm1

# Use any exported function
Invoke-ModOperations -ConfigFile "custom.yml" -DryRun $true
Invoke-ServerDeployment -Port 8080
```

### Getting Help

```bash
# Show comprehensive help
./uwucraft-tools.ps1 help

# Get help for specific functions
Get-Help Invoke-ModOperations -Full
```

## 📝 Examples

### Complete Workflow Example
```bash
# 1. List current mods and config
./uwucraft-tools.ps1 advanced --list

# 2. Preview what would change
./uwucraft-tools.ps1 mods --dry-run

# 3. Apply changes
./uwucraft-tools.ps1 mods --force

# 4. Deploy server
./uwucraft-tools.ps1 deploy --port 8080

# 5. Verify everything worked
./uwucraft-tools.ps1 advanced --list
```

### Custom Configuration Example
```bash
# Use custom config file
./uwucraft-tools.ps1 mods --config "configs/dev-mods.yml"

# Deploy to custom directory
./uwucraft-tools.ps1 deploy --install-dir "dev-server"
```
