import Foundation
import CoreGraphics
import ApplicationServices
import Carbon
import AppKit
import Logging

public actor KeybindingManager {
    private var hotkeys: [Hotkey] = []
    private var config: Config
    private let commandHandler: CommandHandler
    private let logger = Logger(label: "com.tilingwm.keybinding")
    
    public init(config: Config, commandHandler: CommandHandler) {
        self.config = config
        self.commandHandler = commandHandler
    }
    
    public func updateConfig(_ newConfig: Config) async {
        config = newConfig
        await unregisterAllHotkeys()
        await registerKeybindings()
    }
    
    public func registerKeybindings() async {
        for binding in config.keybindings {
            guard let keyCode = keyCodeFromString(binding.key),
                  let modifiers = modifiersFromStrings(binding.modifiers) else {
                logger.warning("Invalid keybinding: \(binding.key)")
                continue
            }
            
            let command = binding.command
            let args = binding.args
            
            let hotkey = Hotkey(
                keyCode: keyCode,
                modifiers: modifiers,
                action: { [weak self] in
                    Task { [self] in
                        await self?.commandHandler.execute(command: command, args: args)
                    }
                }
            )
            
            hotkeys.append(hotkey)
            hotkey.register()
            
            logger.debug("Registered hotkey: \(binding.modifiers.joined(separator: "+")) + \(binding.key)")
        }
        
        logger.info("Registered \(hotkeys.count) hotkeys")
    }
    
    public func unregisterAllHotkeys() async {
        for hotkey in hotkeys {
            hotkey.unregister()
        }
        hotkeys.removeAll()
        logger.info("Unregistered all hotkeys")
    }
    
    // MARK: - Helper Functions
    
    private func keyCodeFromString(_ string: String) -> UInt32? {
        let keyMap: [String: UInt32] = [
            // Letters
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            // Numbers row
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "equal": 24, "9": 25, "7": 26,
            "minus": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
            // Middle row
            "return": 36, "l": 37, "j": 38, "quote": 39, "k": 40, "semicolon": 41, "backslash": 42,
            "comma": 43, "slash": 44, "n": 45, "m": 46, "period": 47, "tab": 48, "space": 49,
            "backtick": 50, "delete": 51,
            // Special keys
            "escape": 53, "clear": 71, "help": 114, "home": 115, "pageup": 116,
            "forwarddelete": 117, "end": 119, "pagedown": 121, "left": 123, "right": 124,
            "down": 125, "up": 126,
            // Function keys
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
            "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        ]
        
        return keyMap[string.lowercased()]
    }
    
    private func modifiersFromStrings(_ strings: [String]) -> UInt32? {
        var modifiers: UInt32 = 0
        
        for string in strings {
            switch string.lowercased() {
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            case "opt", "option", "alt":
                modifiers |= UInt32(optionKey)
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            default:
                return nil
            }
        }
        
        return modifiers
    }
}

// MARK: - Hotkey Class

private class Hotkey {
    let keyCode: UInt32
    let modifiers: UInt32
    let action: () -> Void
    var eventHandler: EventHandlerRef?
    var eventHotKey: EventHotKeyRef?
    
    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
    }
    
    func register() {
        var gMyHotKeyID = EventHotKeyID()
        gMyHotKeyID.id = keyCode
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Install event handler
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, refcon -> OSStatus in
                guard let refcon = refcon else { return OSStatus(eventNotHandledErr) }
                let hotkey = Unmanaged<Hotkey>.fromOpaque(refcon).takeUnretainedValue()
                hotkey.action()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        // Register hotkey
        RegisterEventHotKey(
            keyCode,
            modifiers,
            gMyHotKeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotKey
        )
    }
    
    func unregister() {
        if let hotKey = eventHotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

// MARK: - Command Handler

public actor CommandHandler {
    private let workspaceManager: WorkspaceManager
    private let windowManager: WindowManager
    private let layoutEngine: LayoutEngine
    private let logger = Logger(label: "com.tilingwm.commands")
    
    public init(workspaceManager: WorkspaceManager, windowManager: WindowManager, layoutEngine: LayoutEngine) {
        self.workspaceManager = workspaceManager
        self.windowManager = windowManager
        self.layoutEngine = layoutEngine
    }
    
    public func execute(command: String, args: [String]) async {
        logger.info("Executing command: \(command) with args: \(args)")
        
        switch command {
        case "workspace":
            await executeWorkspace(args: args)
        case "move-to-workspace":
            await executeMoveToWorkspace(args: args)
        case "toggle-float":
            await executeToggleFloat()
        case "close-window":
            await executeCloseWindow()
        case "focus":
            await executeFocus(args: args)
        case "move":
            await executeMove(args: args)
        case "resize":
            await executeResize(args: args)
        case "layout":
            await executeLayout(args: args)
        default:
            logger.warning("Unknown command: \(command)")
        }
    }
    
    private func executeWorkspace(args: [String]) async {
        guard let workspaceID = args.first else { return }
        _ = await workspaceManager.switchToWorkspace(id: workspaceID)
        await layoutEngine.layoutAllWorkspaces()
    }
    
    private func executeMoveToWorkspace(args: [String]) async {
        guard let workspaceID = args.first else { return }
        // Get focused window by ID from window manager
        if let windowID = await getFocusedWindowID() {
            // Move window to workspace using ID
            await moveWindowByID(windowID, to: workspaceID)
        }
        await layoutEngine.layoutWorkspace(workspaceID)
        await layoutEngine.layoutAllWorkspaces()
    }
    
    private func executeToggleFloat() async {
        // Toggle floating state of focused window
        // This would need Window model to be mutable or use a different approach
    }
    
    private func executeCloseWindow() async {
        // Close focused window by ID
        if let windowID = await getFocusedWindowID() {
            await closeWindowByID(windowID)
        }
    }
    
    private func executeFocus(args: [String]) async {
        guard args.first != nil else { return }
        // Implement focus based on direction
        // This requires looking at window positions
    }
    
    private func executeMove(args: [String]) async {
        guard args.first != nil else { return }
        // Implement window movement based on direction
    }
    
    private func executeResize(args: [String]) async {
        guard args.first != nil else { return }
        // Implement resize logic
    }
    
    private func executeLayout(args: [String]) async {
        guard let layoutName = args.first,
              let _ = LayoutType(rawValue: layoutName) else { return }
        
        if let workspace = await workspaceManager.getActiveWorkspace() {
            // Update workspace layout
            // This requires mutable workspace model
            await layoutEngine.layoutWorkspace(workspace.id)
        }
    }
    
    // Helper methods to work with window IDs
    private func getFocusedWindowID() async -> CGWindowID? {
        // This will be implemented in WindowManager
        return nil
    }
    
    private func moveWindowByID(_ windowID: CGWindowID, to workspaceID: String) async {
        // This will be implemented
    }
    
    private func closeWindowByID(_ windowID: CGWindowID) async {
        // This will be implemented
    }
}