import Foundation
import ArgumentParser
import TilingWMLib

@main
struct TilingWMCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "twm",
        abstract: "Tiling Window Manager CLI",
        subcommands: [
            Workspace.self,
            Window.self,
            Layout.self,
            Config.self,
            Service.self,
        ]
    )
}

// MARK: - Workspace Commands

extension TilingWMCLI {
    struct Workspace: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Manage workspaces",
            subcommands: [Switch.self, List.self]
        )
        
        struct Switch: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                commandName: "switch",
                abstract: "Switch to a workspace"
            )
            
            @Argument(help: "Workspace ID")
            var id: String
            
            func run() async throws {
                print("Switching to workspace \(id)...")
                // Send IPC message to daemon
                try await sendCommand(.workspace(id: id))
            }
        }
        
        struct List: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                commandName: "list",
                abstract: "List all workspaces"
            )
            
            func run() async throws {
                print("Workspaces:")
                // Get workspaces from daemon
                let workspaces = try await queryDaemon(.listWorkspaces)
                print(workspaces)
            }
        }
    }
}

// MARK: - Window Commands

extension TilingWMCLI {
    struct Window: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Manage windows",
            subcommands: [Close.self, Focus.self, Move.self]
        )
        
        struct Close: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Close the focused window"
            )
            
            func run() async throws {
                print("Closing focused window...")
                try await sendCommand(.closeWindow)
            }
        }
        
        struct Focus: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Focus a window by direction"
            )
            
            @Argument(help: "Direction (left, right, up, down)")
            var direction: String
            
            func run() async throws {
                print("Focusing \(direction)...")
                try await sendCommand(.focus(direction: direction))
            }
        }
        
        struct Move: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Move the focused window"
            )
            
            @Argument(help: "Direction (left, right, up, down)")
            var direction: String
            
            func run() async throws {
                print("Moving window \(direction)...")
                try await sendCommand(.move(direction: direction))
            }
        }
    }
}

// MARK: - Layout Commands

extension TilingWMCLI {
    struct Layout: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Manage layout",
            subcommands: [Set.self]
        )
        
        struct Set: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                commandName: "set",
                abstract: "Set the layout mode"
            )
            
            @Argument(help: "Layout mode (bsp, stack, float)")
            var mode: String
            
            func run() async throws {
                print("Setting layout to \(mode)...")
                try await sendCommand(.setLayout(mode: mode))
            }
        }
    }
}

// MARK: - Config Commands

extension TilingWMCLI {
    struct Config: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Manage configuration",
            subcommands: [Edit.self, Reload.self]
        )
        
        struct Edit: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Open config in default editor"
            )
            
            func run() throws {
                let home = FileManager.default.homeDirectoryForCurrentUser
                let configPath = home.appendingPathComponent(".config/tilingwm/config.toml")
                NSWorkspace.shared.open(configPath)
            }
        }
        
        struct Reload: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Reload configuration"
            )
            
            func run() async throws {
                print("Reloading config...")
                try await sendCommand(.reloadConfig)
            }
        }
    }
}

// MARK: - Service Commands

extension TilingWMCLI {
    struct Service: AsyncParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Manage TilingWM service",
            subcommands: [Start.self, Stop.self, Restart.self, Status.self]
        )
        
        struct Start: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Start TilingWM"
            )
            
            func run() async throws {
                print("Starting TilingWM...")
                // Launch the main app
                let appURL = Bundle.main.bundleURL
                    .deletingLastPathComponent()
                    .appendingPathComponent("TilingWM.app")
                NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
            }
        }
        
        struct Stop: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Stop TilingWM"
            )
            
            func run() async throws {
                print("Stopping TilingWM...")
                try await sendCommand(.quit)
            }
        }
        
        struct Restart: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Restart TilingWM"
            )
            
            func run() async throws {
                print("Restarting TilingWM...")
                try await sendCommand(.quit)
                // Wait a bit then restart
                try await Task.sleep(nanoseconds: 500_000_000)
                // Restart logic here
            }
        }
        
        struct Status: AsyncParsableCommand {
            static var configuration = CommandConfiguration(
                abstract: "Check TilingWM status"
            )
            
            func run() async throws {
                // Check if daemon is running
                print("TilingWM status: running")
            }
        }
    }
}

// MARK: - IPC

enum Command {
    case workspace(id: String)
    case closeWindow
    case focus(direction: String)
    case move(direction: String)
    case setLayout(mode: String)
    case reloadConfig
    case quit
}

enum Query {
    case listWorkspaces
}

func sendCommand(_ command: Command) async throws {
    // TODO: Implement IPC to communicate with main daemon
    // This could use sockets, XPC, or distributed notifications
    print("Command sent: \(command)")
}

func queryDaemon(_ query: Query) async throws -> String {
    // TODO: Implement IPC query
    return "[]"
}