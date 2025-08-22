# UwUCraft 21 Mod Management

Simple scripts to manage Minecraft mods using packwiz CLI based on a `custom.yml` configuration.

## Quick Start

```powershell
# Apply all changes from custom.yml
./apply-mods.ps1

# Preview changes without applying them
./apply-mods.ps1 --dry-run

# Apply changes without prompts (non-interactive)
./apply-mods.ps1 --force

# Only add new mods
./apply-mods.ps1 --add-only

# Only remove mods
./apply-mods.ps1 --remove-only
```

## Usage

The scripts read mod definitions from `custom.yml` and use packwiz commands to add/remove mods:

```yaml
add:
  curseforge:
    - name: "Mod Name"
      url: "https://www.curseforge.com/minecraft/mc-mods/mod-slug"
  modrinth:
    - name: "Modrinth Mod"
      url: "https://modrinth.com/mod/mod-slug"

remove:
  curseforge:
    - "Mod Name to Remove"
  modrinth:
    - "Modrinth Mod to Remove"
```

## Available Launchers

- **`apply-mods.cmd`** - Windows batch file (recommended for Windows)
- **`apply-mods.ps1`** - PowerShell script (cross-platform)

Both launchers support the same options:

| Option | Short | Description |
|--------|-------|-------------|
| `--dry-run` | `-n` | Preview changes without applying them |
| `--force` | `-f` | Apply changes without prompts |
| `--add-only` | | Only add mods (skip removals) |
| `--remove-only` | | Only remove mods (skip additions) |
| `--help` | `-h` | Show help message |

## Examples

```powershell
# Basic usage
./apply-mods.ps1

# See what would happen
./apply-mods.ps1 -n

# Run without any user prompts
./apply-mods.ps1 -f

# Only add new mods from custom.yml
./apply-mods.ps1 --add-only

# Show help
./apply-mods.ps1 --help
```

## Requirements

- **packwiz CLI** - Must be installed and in PATH
- **PowerShell** - For .ps1 launcher (usually pre-installed on Windows)
- **custom.yml** - Configuration file with mod definitions

## Full Documentation

See the [full scripting documentation](scripts/MOD-MANAGEMENT-README.md) for detailed documentation, troubleshooting, and advanced usage.
