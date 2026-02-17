import Foundation
import CoreGraphics
import ApplicationServices

public struct Workspace: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var windows: [Window]
    public var layout: LayoutType
    public var display: CGDirectDisplayID?
    public var isActive: Bool
    
    public init(id: String, name: String, layout: LayoutType = .bsp) {
        self.id = id
        self.name = name
        self.windows = []
        self.layout = layout
        self.display = nil
        self.isActive = false
    }
    
    public mutating func addWindow(_ window: Window) {
        if !windows.contains(where: { $0.id == window.id }) {
            windows.append(window)
        }
    }
    
    public mutating func removeWindow(_ window: Window) {
        windows.removeAll { $0.id == window.id }
    }
    
    public mutating func removeWindow(withID id: CGWindowID) {
        windows.removeAll { $0.id == id }
    }
    
    public var windowCount: Int {
        return windows.count
    }
    
    public var isEmpty: Bool {
        return windows.isEmpty
    }
}

public enum LayoutType: String, CaseIterable, Sendable {
    case bsp = "bsp"
    case stack = "stack"
    case float = "float"
}