import Foundation
import AppKit
import Logging
import TilingWMLib

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var workspaceManager: WorkspaceManager!
    private var windowManager: WindowManager!
    private var layoutEngine: LayoutEngine!
    private var configManager: ConfigManager!
    private var keybindingManager: KeybindingManager!
    private var commandHandler: CommandHandler!
    private var statusItem: NSStatusItem?
    private let logger = Logger(label: "com.tilingwm.app")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("TilingWM starting...")
        
        Task {
            await setup()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await windowManager?.stop()
            await keybindingManager?.unregisterAllHotkeys()
        }
    }
    
    private func setup() async {
        do {
            // Initialize managers
            workspaceManager = WorkspaceManager()
            windowManager = WindowManager(workspaceManager: workspaceManager)
            layoutEngine = LayoutEngine(workspaceManager: workspaceManager)
            configManager = ConfigManager()
            
            // Load configuration
            try await configManager.load()
            let config = configManager.getConfig()
            
            // Initialize command handler
            commandHandler = CommandHandler(
                workspaceManager: workspaceManager,
                windowManager: windowManager,
                layoutEngine: layoutEngine
            )
            
            // Initialize keybinding manager
            keybindingManager = KeybindingManager(
                config: config,
                commandHandler: commandHandler
            )
            await keybindingManager.registerKeybindings()
            
            // Setup window manager callbacks
            windowManager.onWindowCreated = { [weak self] window in
                Task {
                    await self?.onWindowCreated(window)
                }
            }
            
            windowManager.onWindowDestroyed = { [weak self] window in
                Task {
                    await self?.onWindowDestroyed(window)
                }
            }
            
            windowManager.onWindowFocused = { [weak self] window in
                Task {
                    await self?.onWindowFocused(window)
                }
            }
            
            // Start window manager
            await windowManager.start()
            
            // Initial layout
            await layoutEngine.layoutAllWorkspaces()
            
            // Setup menu bar
            setupMenuBar()
            
            // Apply config settings
            await applyConfig(config)
            
            logger.info("TilingWM setup complete")
            
        } catch {
            logger.error("Failed to setup TilingWM: \(error)")
        }
    }
    
    private func applyConfig(_ config: Config) async {
        await layoutEngine.setGapSize(config.gaps.inner)
        await layoutEngine.setOuterGap(config.gaps.outer)
        
        // Setup workspaces from config
        for wsConfig in config.workspaces {
            _ = await workspaceManager.createWorkspace(
                id: wsConfig.id,
                name: wsConfig.name,
                layout: LayoutType(rawValue: wsConfig.layout) ?? .bsp
            )
        }
    }
    
    private func onWindowCreated(_ window: Window) async {
        logger.info("Window created: \(window.title ?? "Unknown")")
        if let workspace = await workspaceManager.getActiveWorkspace() {
            await layoutEngine.layoutWorkspace(workspace.id)
        }
    }
    
    private func onWindowDestroyed(_ window: Window) async {
        logger.info("Window destroyed: \(window.title ?? "Unknown")")
        let workspaces = await workspaceManager.getAllWorkspaces()
        for workspace in workspaces {
            await layoutEngine.layoutWorkspace(workspace.id)
        }
    }
    
    private func onWindowFocused(_ window: Window) async {
        logger.debug("Window focused: \(window.title ?? "Unknown")")
    }
    
    // MARK: - Menu Bar
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "⊞" // Unicode symbol for tiling
        }
        
        let menu = NSMenu()
        
        // Workspaces submenu
        let workspacesItem = NSMenuItem(title: "Workspaces", action: nil, keyEquivalent: "")
        let workspacesMenu = NSMenu()
        
        for i in 1...9 {
            let item = NSMenuItem(
                title: "Workspace \(i)",
                action: #selector(switchToWorkspace(_:)),
                keyEquivalent: ""
            )
            item.tag = i
            workspacesMenu.addItem(item)
        }
        
        workspacesItem.submenu = workspacesMenu
        menu.addItem(workspacesItem)
        menu.addItem(NSMenuItem.separator())
        
        // Layout menu
        let layoutItem = NSMenuItem(title: "Layout", action: nil, keyEquivalent: "")
        let layoutMenu = NSMenu()
        
        let bspItem = NSMenuItem(title: "BSP", action: #selector(setLayout(_:)), keyEquivalent: "")
        bspItem.tag = 0
        let stackItem = NSMenuItem(title: "Stack", action: #selector(setLayout(_:)), keyEquivalent: "")
        stackItem.tag = 1
        let floatItem = NSMenuItem(title: "Float", action: #selector(setLayout(_:)), keyEquivalent: "")
        floatItem.tag = 2
        
        layoutMenu.addItem(bspItem)
        layoutMenu.addItem(stackItem)
        layoutMenu.addItem(floatItem)
        layoutItem.submenu = layoutMenu
        menu.addItem(layoutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Preferences
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        
        // Reload config
        menu.addItem(NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "r"))
        
        menu.addItem(NSMenuItem.separator())
        
        // About
        menu.addItem(NSMenuItem(title: "About TilingWM", action: #selector(showAbout), keyEquivalent: ""))
        
        // Quit
        menu.addItem(NSMenuItem(title: "Quit TilingWM", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func switchToWorkspace(_ sender: NSMenuItem) {
        let workspaceID = "\(sender.tag)"
        Task {
            await commandHandler.execute(command: "workspace", args: [workspaceID])
        }
    }
    
    @objc private func setLayout(_ sender: NSMenuItem) {
        let layouts = ["bsp", "stack", "float"]
        let layout = layouts[sender.tag]
        Task {
            await commandHandler.execute(command: "layout", args: [layout])
        }
    }
    
    @objc private func openPreferences() {
        // Open config file in default editor
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".config/tilingwm/config.toml")
        
        NSWorkspace.shared.open(configPath)
    }
    
    @objc private func reloadConfig() {
        Task {
            do {
                try await configManager.load()
                let config = configManager.getConfig()
                await keybindingManager.updateConfig(config)
                await applyConfig(config)
                logger.info("Config reloaded")
            } catch {
                logger.error("Failed to reload config: \(error)")
            }
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "TilingWM"
        alert.informativeText = "A tiling window manager for macOS\n\nVersion 0.1.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(self)
    }
}