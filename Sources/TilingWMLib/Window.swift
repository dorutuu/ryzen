import Foundation
import CoreGraphics
import ApplicationServices

public struct Window: Identifiable, Equatable, Hashable, @unchecked Sendable {
    public let id: CGWindowID
    public let axElement: AXUIElement
    public var title: String?
    public var appName: String?
    public var frame: CGRect
    public var isFloating: Bool
    public var isMinimized: Bool
    public var isFullscreen: Bool
    
    public init(axElement: AXUIElement) {
        self.axElement = axElement
        self.id = Window.getWindowID(from: axElement)
        self.title = Window.getTitle(from: axElement)
        self.appName = Window.getAppName(from: axElement)
        self.frame = Window.getFrame(from: axElement) ?? .zero
        self.isFloating = false
        self.isMinimized = false
        self.isFullscreen = false
    }
    
    public static func == (lhs: Window, rhs: Window) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    private static func getWindowID(from element: AXUIElement) -> CGWindowID {
        var windowID: CGWindowID = 0
        _AXUIElementGetWindow(element, &windowID)
        return windowID
    }
    
    private static func getTitle(from element: AXUIElement) -> String? {
        var titleValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        guard result == .success else { return nil }
        return titleValue as? String
    }
    
    private static func getAppName(from element: AXUIElement) -> String? {
        var app: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &app)
        guard result == .success, let app = app as! AXUIElement? else { return nil }
        
        var appNameValue: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(app, kAXTitleAttribute as CFString, &appNameValue)
        guard appResult == .success else { return nil }
        return appNameValue as? String
    }
    
    private static func getFrame(from element: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        
        let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        
        guard positionResult == .success, sizeResult == .success else { return nil }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        if let positionValue = positionValue {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        }
        if let sizeValue = sizeValue {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }
        
        return CGRect(origin: position, size: size)
    }
    
    public func setFrame(_ frame: CGRect) {
        var position = frame.origin
        var size = frame.size
        
        let positionRef = AXValueCreate(.cgPoint, &position)
        let sizeRef = AXValueCreate(.cgSize, &size)
        
        AXUIElementSetAttributeValue(axElement, kAXPositionAttribute as CFString, positionRef!)
        AXUIElementSetAttributeValue(axElement, kAXSizeAttribute as CFString, sizeRef!)
    }
    
    public func focus() {
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        var app: AnyObject?
        let result = AXUIElementCopyAttributeValue(axElement, kAXParentAttribute as CFString, &app)
        if result == .success, let app = app as! AXUIElement? {
            AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
    }
}

// Bridge function for getting window ID
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError