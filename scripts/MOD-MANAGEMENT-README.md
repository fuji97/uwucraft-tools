# Custom Mod Management Scripts

This repository contains PowerShell scripts to manage Minecraft mods using packwiz CLI based on a `custom.yml` configuration file.

## Scripts

### 1. `Apply-CustomMods.ps1` (Full-featured)
A comprehensive script with logging, error handling, and dry-run capabilities.

**Features:**
- Detailed logging with timestamps
- Dry-run mode to preview changes
- Error handling and success/failure tracking
- Automatic packwiz index refresh
- Force mode for non-interactive execution

**Usage:**
```powershell
# Apply changes from custom.yml
.\Apply-CustomMods.ps1

# Preview changes without executing (dry run)
.\Apply-CustomMods.ps1 -DryRun

# Apply changes automatically without prompts
.\Apply-CustomMods.ps1 -Force

# Use a different config file
.\Apply-CustomMods.ps1 -ConfigFile ".\my-custom.yml"
```

### 2. `Manage-CustomMods.ps1` (Simple)
A streamlined script for quick mod management.

**Features:**
- Simple, direct execution
- Selective operation (add only, remove only, or both)
- Color-coded status messages
- Automatic dependency installation

**Usage:**
```powershell
# Add and remove mods based on custom.yml
.\Manage-CustomMods.ps1

# Only add mods
.\Manage-CustomMods.ps1 -Action add

# Only remove mods  
.\Manage-CustomMods.ps1 -Action remove

# Execute with force flag (no prompts)
.\Manage-CustomMods.ps1 -Force
```

## Configuration File Format

The scripts read from a `custom.yml` file with the following structure:

```yaml
add:
  curseforge:
    - name: "Mod Name"
      url: "https://www.curseforge.com/minecraft/mc-mods/mod-slug"
    - name: "Another Mod"
      url: "https://www.curseforge.com/minecraft/mc-mods/another-mod"
  modrinth:
    - name: "Modrinth Mod"
      url: "https://modrinth.com/mod/mod-slug"

remove:
  curseforge:
    - "Mod Name to Remove"
    - "Another Mod to Remove"
  modrinth:
    - "Modrinth Mod to Remove"
```

### Example `custom.yml`:
```yaml
add:
  curseforge:
    - name: Chunky
      url: https://www.curseforge.com/minecraft/mc-mods/chunky-pregenerator-forge
    - name: EMI
      url: https://www.curseforge.com/minecraft/mc-mods/emi
  modrinth: []

remove:
  curseforge: []
  modrinth: []
```

## Prerequisites

1. **packwiz CLI**: Must be installed and available in your PATH
   - Download from: https://github.com/packwiz/packwiz/releases
   - Ensure `packwiz` command works in your terminal

2. **PowerShell**: Windows PowerShell 5.1+ or PowerShell Core 7+

3. **powershell-yaml module**: Automatically installed by the scripts if missing
   - Manual install: `Install-Module -Name powershell-yaml -Force`

## How It Works

### Adding Mods
- **CurseForge**: Uses `packwiz curseforge add <url>`
- **Modrinth**: Uses `packwiz modrinth add <url>`

### Removing Mods
- Uses `packwiz remove <mod-filename>`
- Mod names are converted to likely filenames (lowercase, special chars to hyphens)
- Examples:
  - "EMI Trades" → "emi-trades"
  - "Just Dire Things" → "just-dire-things"

### Index Refresh
- Automatically runs `packwiz refresh` after making changes
- Updates the mod index and pack.toml file

## Error Handling

### Common Issues:
1. **"packwiz command not found"**: Install packwiz CLI and add to PATH
2. **"Failed to parse YAML"**: Check custom.yml syntax
3. **"Can't find this file"**: Mod name doesn't match the .pw.toml filename
   - Check existing .pw.toml files in your mods directory
   - Use the exact filename without .pw.toml extension

### Troubleshooting:
- Use `-DryRun` with `Apply-CustomMods.ps1` to preview operations
- Check packwiz help: `packwiz --help`
- List current mods: `packwiz list`
- Manual remove: `packwiz remove <exact-filename>`

## Examples

### Adding a new mod:
1. Add to `custom.yml`:
```yaml
add:
  curseforge:
    - name: "New Mod"
      url: "https://www.curseforge.com/minecraft/mc-mods/new-mod"
```

2. Run script:
```powershell
.\Apply-CustomMods.ps1 -Force
```

### Removing an existing mod:
1. Add to `custom.yml`:
```yaml
remove:
  curseforge:
    - "Mod Name"
```

2. Run script:
```powershell
.\Manage-CustomMods.ps1 -Action remove
```

### Preview changes:
```powershell
.\Apply-CustomMods.ps1 -DryRun
```

## Integration with Version Control

These scripts work well with git workflows:

1. Modify `custom.yml` with your desired changes
2. Run script to apply changes
3. Commit both `custom.yml` and the updated packwiz files
4. Other team members can run the script to sync their mod lists

## Notes

- The scripts do not modify existing .pw.toml files directly
- All operations use packwiz CLI commands
- Index refresh is automatic after changes
- Both scripts support the `-Force` flag for CI/CD pipelines
- Mod removal attempts to match filenames automatically but may require manual adjustment for complex names
