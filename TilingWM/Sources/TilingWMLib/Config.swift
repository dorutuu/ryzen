import Foundation
import Logging

public struct Config: Codable {
    public var general: GeneralConfig
    public var gaps: GapsConfig
    public var workspaces: [WorkspaceConfig]
    public var keybindings: [KeybindingConfig]
    public var rules: [RuleConfig]
    
    public init() {
        self.general = GeneralConfig()
        self.gaps = GapsConfig()
        self.workspaces = []
        self.keybindings = []
        self.rules = []
    }
}

public struct GeneralConfig: Codable {
    public var startAtLogin: Bool
    public var enableAnimations: Bool
    public var defaultLayout: String
    public var onStartup: [String]
    
    public init() {
        self.startAtLogin = false
        self.enableAnimations = false
        self.defaultLayout = "bsp"
        self.onStartup = []
    }
}

public struct GapsConfig: Codable {
    public var inner: CGFloat
    public var outer: CGFloat
    
    public init() {
        self.inner = 10
        self.outer = 10
    }
}

public struct WorkspaceConfig: Codable {
    public var id: String
    public var name: String
    public var layout: String
    
    public init(id: String, name: String, layout: String = "bsp") {
        self.id = id
        self.name = name
        self.layout = layout
    }
}

public struct KeybindingConfig: Codable {
    public var key: String
    public var modifiers: [String]
    public var command: String
    public var args: [String]
    
    public init(key: String, modifiers: [String], command: String, args: [String] = []) {
        self.key = key
        self.modifiers = modifiers
        self.command = command
        self.args = args
    }
}

public struct RuleConfig: Codable {
    public var app: String?
    public var title: String?
    public var workspace: String?
    public var float: Bool?
    
    public init(app: String? = nil, title: String? = nil, workspace: String? = nil, float: Bool? = nil) {
        self.app = app
        self.title = title
        self.workspace = workspace
        self.float = float
    }
}

public actor ConfigManager {
    private var config: Config
    private let logger = Logger(label: "com.tilingwm.config")
    private let configPath: URL
    
    public init() {
        self.config = Config()
        
        // Default config location: ~/.config/tilingwm/config.toml
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.configPath = home.appendingPathComponent(".config/tilingwm/config.toml")
        
        // Create config directory if needed
        let configDir = configPath.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    }
    
    public func load() async throws {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            logger.info("Config file not found, creating default config")
            try await createDefaultConfig()
            return
        }
        
        let data = try Data(contentsOf: configPath)
        let decoder = TOMLDecoder()
        config = try decoder.decode(Config.self, from: data)
        
        logger.info("Config loaded successfully")
    }
    
    public func save() async throws {
        let encoder = TOMLEncoder()
        let data = try encoder.encode(config)
        try data.write(to: configPath)
        logger.info("Config saved")
    }
    
    public func getConfig() -> Config {
        return config
    }
    
    public func updateConfig(_ newConfig: Config) {
        config = newConfig
    }
    
    private func createDefaultConfig() async throws {
        var defaultConfig = Config()
        
        // Setup default workspaces
        defaultConfig.workspaces = [
            WorkspaceConfig(id: "1", name: "Terminal", layout: "bsp"),
            WorkspaceConfig(id: "2", name: "Browser", layout: "bsp"),
            WorkspaceConfig(id: "3", name: "Code", layout: "bsp"),
            WorkspaceConfig(id: "4", name: "Chat", layout: "stack"),
            WorkspaceConfig(id: "5", name: "Media", layout: "float"),
            WorkspaceConfig(id: "6", name: "6", layout: "bsp"),
            WorkspaceConfig(id: "7", name: "7", layout: "bsp"),
            WorkspaceConfig(id: "8", name: "8", layout: "bsp"),
            WorkspaceConfig(id: "9", name: "9", layout: "bsp"),
        ]
        
        // Setup default keybindings
        defaultConfig.keybindings = [
            // Workspace switching
            KeybindingConfig(key: "1", modifiers: ["cmd", "alt"], command: "workspace", args: ["1"]),
            KeybindingConfig(key: "2", modifiers: ["cmd", "alt"], command: "workspace", args: ["2"]),
            KeybindingConfig(key: "3", modifiers: ["cmd", "alt"], command: "workspace", args: ["3"]),
            KeybindingConfig(key: "4", modifiers: ["cmd", "alt"], command: "workspace", args: ["4"]),
            KeybindingConfig(key: "5", modifiers: ["cmd", "alt"], command: "workspace", args: ["5"]),
            KeybindingConfig(key: "6", modifiers: ["cmd", "alt"], command: "workspace", args: ["6"]),
            KeybindingConfig(key: "7", modifiers: ["cmd", "alt"], command: "workspace", args: ["7"]),
            KeybindingConfig(key: "8", modifiers: ["cmd", "alt"], command: "workspace", args: ["8"]),
            KeybindingConfig(key: "9", modifiers: ["cmd", "alt"], command: "workspace", args: ["9"]),
            
            // Move window to workspace
            KeybindingConfig(key: "1", modifiers: ["cmd", "alt", "shift"], command: "move-to-workspace", args: ["1"]),
            KeybindingConfig(key: "2", modifiers: ["cmd", "alt", "shift"], command: "move-to-workspace", args: ["2"]),
            KeybindingConfig(key: "3", modifiers: ["cmd", "alt", "shift"], command: "move-to-workspace", args: ["3"]),
            
            // Layout commands
            KeybindingConfig(key: "f", modifiers: ["cmd", "alt"], command: "toggle-float"),
            KeybindingConfig(key: "q", modifiers: ["cmd", "alt"], command: "close-window"),
            
            // Focus
            KeybindingConfig(key: "h", modifiers: ["cmd", "alt"], command: "focus", args: ["left"]),
            KeybindingConfig(key: "j", modifiers: ["cmd", "alt"], command: "focus", args: ["down"]),
            KeybindingConfig(key: "k", modifiers: ["cmd", "alt"], command: "focus", args: ["up"]),
            KeybindingConfig(key: "l", modifiers: ["cmd", "alt"], command: "focus", args: ["right"]),
            
            // Move windows
            KeybindingConfig(key: "h", modifiers: ["cmd", "alt", "shift"], command: "move", args: ["left"]),
            KeybindingConfig(key: "j", modifiers: ["cmd", "alt", "shift"], command: "move", args: ["down"]),
            KeybindingConfig(key: "k", modifiers: ["cmd", "alt", "shift"], command: "move", args: ["up"]),
            KeybindingConfig(key: "l", modifiers: ["cmd", "alt", "shift"], command: "move", args: ["right"]),
            
            // Resize
            KeybindingConfig(key: "minus", modifiers: ["cmd", "alt"], command: "resize", args: ["shrink"]),
            KeybindingConfig(key: "equal", modifiers: ["cmd", "alt"], command: "resize", args: ["grow"]),
            
            // Layout switching
            KeybindingConfig(key: "b", modifiers: ["cmd", "alt"], command: "layout", args: ["bsp"]),
            KeybindingConfig(key: "s", modifiers: ["cmd", "alt"], command: "layout", args: ["stack"]),
        ]
        
        // Default rules
        defaultConfig.rules = [
            RuleConfig(app: "System Settings", float: true),
            RuleConfig(app: "Finder", float: true),
            RuleConfig(app: "Safari", workspace: "2"),
        ]
        
        config = defaultConfig
        try await save()
    }
}

// TOML Encoder/Decoder stubs (you'll need to implement or use a library)
public struct TOMLEncoder {
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        // Convert to TOML format
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return try encoder.encode(value)
    }
}

public struct TOMLDecoder {
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = PropertyListDecoder()
        return try decoder.decode(type, from: data)
    }
}