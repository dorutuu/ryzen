import Foundation
import CoreGraphics
import ApplicationServices
import Logging

public actor WindowManager {
    private var trackedWindows: [CGWindowID: Window] = [:]
    private var workspaceManager: WorkspaceManager
    private var eventTap: CFMachPort?
    private let logger = Logger(label: "com.tilingwm.windowmanager")
    private var isRunning = false
    
    // Callbacks
    public var onWindowCreated: ((Window) -> Void)?
    public var onWindowDestroyed: ((Window) -> Void)?
    public var onWindowFocused: ((Window) -> Void)?
    public var onWindowMoved: ((Window) -> Void)?
    public var onWindowResized: ((Window) -> Void)?
    
    public init(workspaceManager: WorkspaceManager) {
        self.workspaceManager = workspaceManager
    }
    
    // MARK: - Lifecycle
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        
        logger.info("Starting WindowManager")
        
        // Check accessibility permissions
        Task {
            await checkAccessibilityPermissions()
        }
        
        // Scan existing windows
        scanExistingWindows()
        
        // Start refresh timer
        startRefreshTimer()
        
        logger.info("WindowManager started")
    }
    
    public func stop() {
        isRunning = false
        logger.info("Stopping WindowManager")
        
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }
    
    // MARK: - Accessibility Permissions
    
    private func checkAccessibilityPermissions() async {
        // Check accessibility permissions using nonisolated helper
        let enabled = await isAccessibilityEnabled()
        
        if !enabled {
            logger.warning("Accessibility permissions not granted. Please grant permissions in System Preferences.")
        } else {
            logger.info("Accessibility permissions granted")
        }
    }
    
    nonisolated private func isAccessibilityEnabled() async -> Bool {
        // Use the hardcoded key to avoid concurrency issues with the global constant
        let options = ["AXTrustedCheckOptionPrompt": true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // MARK: - Window Discovery
    
    public func scanExistingWindows() {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        
        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            
            // Get AXUIElement for this window
            if let axElement = getAXElementForWindowID(windowID) {
                let window = Window(axElement: axElement)
                
                // Only track normal application windows
                if shouldTrackWindow(window) {
                    trackedWindows[windowID] = window
                    
                    // Add to active workspace
                    Task {
                        await workspaceManager.addWindow(window, to: "1")
                    }
                    
                    onWindowCreated?(window)
                }
            }
        }
        
        logger.info("Found \(trackedWindows.count) windows")
    }
    
    private func getAXElementForWindowID(_ windowID: CGWindowID) -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var apps: CFArray?
        
        let result = AXUIElementCopyAttributeValues(
            systemWide,
            kAXApplicationRole as CFString,
            0,
            100,
            &apps
        )
        
        guard result == .success, let apps = apps as? [AXUIElement] else { return nil }
        
        for app in apps {
            var windows: CFArray?
            let windowsResult = AXUIElementCopyAttributeValues(
                app,
                kAXWindowsAttribute as CFString,
                0,
                100,
                &windows
            )
            
            if windowsResult == .success, let windows = windows as? [AXUIElement] {
                for window in windows {
                    var currentWindowID: CGWindowID = 0
                    let _ = _AXUIElementGetWindow(window, &currentWindowID)
                    
                    if currentWindowID == windowID {
                        return window
                    }
                }
            }
        }
        
        return nil
    }
    
    private func shouldTrackWindow(_ window: Window) -> Bool {
        // Don't track windows without titles (usually system windows)
        guard let title = window.title, !title.isEmpty else { return false }
        
        // Don't track certain system apps
        let excludedApps = ["Window Server", "SystemUIServer", "Dock"]
        if let appName = window.appName, excludedApps.contains(appName) {
            return false
        }
        
        // Don't track tiny windows (usually popups or alerts)
        if window.frame.width < 100 || window.frame.height < 100 {
            return false
        }
        
        return true
    }
    
    // MARK: - Refresh Timer
    
    nonisolated private func startRefreshTimer() {
        // Schedule timer on main thread
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshWindows()
            }
        }
    }
    
    public func refreshWindows() {
        // Check for new windows
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        
        var currentWindowIDs = Set<CGWindowID>()
        
        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            
            currentWindowIDs.insert(windowID)
            
            if trackedWindows[windowID] == nil {
                // New window detected
                if let axElement = getAXElementForWindowID(windowID) {
                    let window = Window(axElement: axElement)
                    if shouldTrackWindow(window) {
                        trackedWindows[windowID] = window
                        onWindowCreated?(window)
                        
                        Task {
                            await workspaceManager.addWindow(window, to: "1")
                        }
                        
                        logger.info("New window detected: \(window.title ?? "Unknown")")
                    }
                }
            }
        }
        
        // Check for closed windows
        let trackedIDs = Set(trackedWindows.keys)
        let closedIDs = trackedIDs.subtracting(currentWindowIDs)
        
        for closedID in closedIDs {
            if let window = trackedWindows[closedID] {
                trackedWindows.removeValue(forKey: closedID)
                onWindowDestroyed?(window)
                
                Task {
                    await workspaceManager.removeWindow(window)
                }
                
                logger.info("Window closed: \(window.title ?? "Unknown")")
            }
        }
    }
    
    // MARK: - Public API
    
    public func getAllWindows() -> [Window] {
        return Array(trackedWindows.values)
    }
    
    public func getWindow(byID id: CGWindowID) -> Window? {
        return trackedWindows[id]
    }
    
    public func getFocusedWindow() -> Window? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        var focusedApp: AnyObject?
        
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        
        guard result == .success, let app = focusedApp as! AXUIElement? else { return nil }
        
        let windowResult = AXUIElementCopyAttributeValue(
            app,
            kAXFocusedWindowAttribute as CFString,
            &focusedElement
        )
        
        guard windowResult == .success, let element = focusedElement as! AXUIElement? else { return nil }
        
        var windowID: CGWindowID = 0
        let _ = _AXUIElementGetWindow(element, &windowID)
        
        return trackedWindows[windowID]
    }
    
    public func focusWindow(_ window: Window) {
        window.focus()
        onWindowFocused?(window)
    }
    
    public func closeWindow(_ window: Window) {
        var closeButton: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            window.axElement,
            kAXCloseButtonAttribute as CFString,
            &closeButton
        )
        
        if result == .success, let button = closeButton as! AXUIElement? {
            AXUIElementPerformAction(button, kAXPressAction as CFString)
        }
    }
    
    public func minimizeWindow(_ window: Window) {
        var minimizeButton: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            window.axElement,
            kAXMinimizeButtonAttribute as CFString,
            &minimizeButton
        )
        
        if result == .success, let button = minimizeButton as! AXUIElement? {
            AXUIElementPerformAction(button, kAXPressAction as CFString)
        }
    }
}