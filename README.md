# TilingWM

A tiling window manager for macOS, inspired by Aerospace and i3.

## Features

- **Workspaces**: Multiple virtual workspaces (1-9 by default)
- **Tiling Layouts**: BSP (Binary Space Partitioning) and Stack layouts
- **Keyboard-Driven**: Fully configurable keybindings
- **Accessibility API**: Uses native macOS Accessibility APIs
- **Menu Bar App**: System tray integration for easy control
- **CLI Tool**: Command-line interface for scripting and control

## Project Structure

```
TilingWM/
├── Package.swift                 # Swift Package Manager manifest
├── Sources/
│   ├── TilingWM/                # Main application
│   │   └── AppDelegate.swift    # Menu bar app entry point
│   ├── TilingWMCLI/             # CLI tool
│   │   └── main.swift           # Command-line interface
│   └── TilingWMLib/             # Core library
│       ├── Window.swift         # Window model
│       ├── Workspace.swift      # Workspace model
│       ├── WorkspaceManager.swift  # Workspace management
│       ├── WindowManager.swift     # Window detection & management
│       ├── LayoutEngine.swift      # Tiling layout calculations
│       ├── Config.swift            # Configuration system
│       └── KeybindingManager.swift # Hotkey & command handling
└── Tests/
    └── TilingWMTests/           # Unit tests
```

## Building

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later (or Swift 6.2+)
- Accessibility permissions (will be prompted on first run)

### Build Commands

```bash
# Build the project
cd TilingWM
swift build

# Build for release
swift build -c release

# Run the main app
swift run TilingWM

# Run the CLI
swift run twm --help

# Run tests
swift test
```

### Installing

```bash
# Build release binaries
swift build -c release

# The binaries will be in .build/release/
# Copy to appropriate locations:
cp .build/release/TilingWM /Applications/TilingWM.app/Contents/MacOS/
cp .build/release/twm /usr/local/bin/
```

## Configuration

Configuration file is located at `~/.config/tilingwm/config.toml`

### Default Keybindings

- **Workspace Switching**: `Cmd+Alt+1..9`
- **Move to Workspace**: `Cmd+Alt+Shift+1..9`
- **Close Window**: `Cmd+Alt+Q`
- **Toggle Float**: `Cmd+Alt+F`
- **Focus Direction**: `Cmd+Alt+H/J/K/L`
- **Move Window**: `Cmd+Alt+Shift+H/J/K/L`
- **Resize**: `Cmd+Alt+Minus/Equal`
- **Layout Mode**: `Cmd+Alt+B/S` (BSP/Stack)

### Sample Configuration

```toml
[general]
startAtLogin = false
enableAnimations = false
defaultLayout = "bsp"

[gaps]
inner = 10
outer = 10

[[workspaces]]
id = "1"
name = "Terminal"
layout = "bsp"

[[workspaces]]
id = "2"
name = "Browser"
layout = "bsp"

[[keybindings]]
key = "1"
modifiers = ["cmd", "alt"]
command = "workspace"
args = ["1"]

[[rules]]
app = "System Settings"
float = true

[[rules]]
app = "Safari"
workspace = "2"
```

## CLI Usage

```bash
# Workspace commands
twm workspace switch 1          # Switch to workspace 1
twm workspace list              # List all workspaces

# Window commands
twm window close                # Close focused window
twm window focus left           # Focus window to the left
twm window move right           # Move window to the right

# Layout commands
twm layout set bsp              # Set BSP layout
twm layout set stack            # Set Stack layout

# Configuration
twm config edit                 # Open config in editor
twm config reload               # Reload configuration

# Service management
twm service start               # Start TilingWM
twm service stop                # Stop TilingWM
twm service restart             # Restart TilingWM
twm service status              # Check status
```

## Architecture

### Components

1. **WindowManager**: Uses macOS Accessibility API to track and manage windows
2. **WorkspaceManager**: Manages virtual workspaces and window assignments
3. **LayoutEngine**: Calculates window positions for tiling layouts
4. **KeybindingManager**: Registers global hotkeys using Carbon Event Manager
5. **CommandHandler**: Executes commands from keybindings or CLI
6. **ConfigManager**: Loads and manages TOML configuration

### Window Management

The window manager uses the Accessibility API (`AXUIElement`) to:
- Detect window creation/destruction
- Track window positions and sizes
- Move and resize windows
- Focus windows

### Workspace System

- Each workspace maintains a list of windows
- Windows are hidden by moving off-screen when switching workspaces
- Active workspace windows are laid out according to the current layout mode

### Layouts

**BSP (Binary Space Partitioning)**:
- Recursively splits space between windows
- Alternates between horizontal and vertical splits based on aspect ratio

**Stack**:
- Main window takes 60% of space
- Remaining windows stacked on the side

## Development

### Running in Xcode

1. Open the project in Xcode
2. Set the scheme to `TilingWM`
3. Build and run (⌘R)

### Granting Permissions

The app requires Accessibility permissions to control windows:
1. Open System Settings → Privacy & Security → Accessibility
2. Add and enable `TilingWM.app`

## Differences from Aerospace

This implementation provides a simpler foundation:
- Uses Swift + AppKit instead of being fully scriptable
- Simpler configuration format
- Smaller feature set (can be extended)
- No tree-based layout preservation yet
- No built-in workspace previews

## Roadmap

- [ ] IPC communication for CLI
- [ ] Tree-based layout preservation
- [ ] Workspace previews
- [ ] Multi-monitor support improvements
- [ ] Application-specific rules
- [ ] Gaps customization per workspace
- [ ] Animations
- [ ] Mission Control integration
- [ ] Window decorations

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.