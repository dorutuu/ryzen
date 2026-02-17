import Foundation
import CoreGraphics
import ApplicationServices
import Logging

public actor WorkspaceManager {
    private var workspaces: [String: Workspace] = [:]
    private var activeWorkspaceID: String?
    private var displayWorkspaces: [CGDirectDisplayID: String] = [:]
    private let logger = Logger(label: "com.tilingwm.workspacemanager")
    
    public init() {
        // Create default workspaces (1-9)
        for i in 1...9 {
            let id = "\(i)"
            workspaces[id] = Workspace(id: id, name: "Workspace \(i)")
        }
        
        // Set initial active workspace
        activeWorkspaceID = "1"
        workspaces["1"]?.isActive = true
    }
    
    // MARK: - Workspace Access
    
    public func getWorkspace(id: String) -> Workspace? {
        return workspaces[id]
    }
    
    public func getAllWorkspaces() -> [Workspace] {
        return Array(workspaces.values).sorted { $0.id < $1.id }
    }
    
    public func getActiveWorkspace() -> Workspace? {
        guard let id = activeWorkspaceID else { return nil }
        return workspaces[id]
    }
    
    public func getActiveWorkspaceID() -> String? {
        return activeWorkspaceID
    }
    
    // MARK: - Workspace Management
    
    public func createWorkspace(id: String, name: String? = nil, layout: LayoutType = .bsp) -> Workspace {
        let workspaceName = name ?? "Workspace \(id)"
        let workspace = Workspace(id: id, name: workspaceName, layout: layout)
        workspaces[id] = workspace
        logger.info("Created workspace: \(id)")
        return workspace
    }
    
    public func deleteWorkspace(id: String) -> Bool {
        guard workspaces[id] != nil else { return false }
        
        // Move windows to workspace 1 before deleting
        if let workspace = workspaces[id], !workspace.isEmpty {
            for window in workspace.windows {
                addWindow(window, to: "1")
            }
        }
        
        workspaces.removeValue(forKey: id)
        logger.info("Deleted workspace: \(id)")
        
        // Switch to workspace 1 if we deleted the active workspace
        if activeWorkspaceID == id {
            Task {
                await switchToWorkspace(id: "1")
            }
        }
        
        return true
    }
    
    // MARK: - Window Management
    
    public func addWindow(_ window: Window, to workspaceID: String) {
        guard workspaces[workspaceID] != nil else { return }
        
        // Remove window from any other workspace first
        for (id, var workspace) in workspaces {
            if id != workspaceID {
                workspace.removeWindow(window)
                workspaces[id] = workspace
            }
        }
        
        workspaces[workspaceID]?.addWindow(window)
        logger.debug("Added window \(window.id) to workspace \(workspaceID)")
    }
    
    public func removeWindow(_ window: Window) {
        for (id, var workspace) in workspaces {
            if workspace.windows.contains(where: { $0.id == window.id }) {
                workspace.removeWindow(window)
                workspaces[id] = workspace
                logger.debug("Removed window \(window.id) from workspace \(id)")
                break
            }
        }
    }
    
    public func moveWindow(_ window: Window, to workspaceID: String) {
        removeWindow(window)
        addWindow(window, to: workspaceID)
        logger.info("Moved window \(window.id) to workspace \(workspaceID)")
    }
    
    public func getWindowWorkspace(_ window: Window) -> Workspace? {
        for (_, workspace) in workspaces {
            if workspace.windows.contains(where: { $0.id == window.id }) {
                return workspace
            }
        }
        return nil
    }
    
    // MARK: - Workspace Switching
    
    public func switchToWorkspace(id: String) -> Bool {
        guard let targetWorkspace = workspaces[id] else {
            logger.warning("Workspace \(id) does not exist")
            return false
        }
        
        // Deactivate current workspace
        if let currentID = activeWorkspaceID {
            workspaces[currentID]?.isActive = false
            
            // Hide windows from current workspace
            if let currentWorkspace = workspaces[currentID] {
                for window in currentWorkspace.windows {
                    hideWindow(window)
                }
            }
        }
        
        // Activate new workspace
        workspaces[id]?.isActive = true
        activeWorkspaceID = id
        
        // Show windows from target workspace
        for window in targetWorkspace.windows {
            showWindow(window)
        }
        
        // Focus first window if exists
        if let firstWindow = targetWorkspace.windows.first {
            firstWindow.focus()
        }
        
        logger.info("Switched to workspace: \(id)")
        return true
    }
    
    // MARK: - Display Management
    
    public func assignWorkspace(_ workspaceID: String, to display: CGDirectDisplayID) {
        displayWorkspaces[display] = workspaceID
        workspaces[workspaceID]?.display = display
        logger.info("Assigned workspace \(workspaceID) to display \(display)")
    }
    
    public func getWorkspaceForDisplay(_ display: CGDirectDisplayID) -> Workspace? {
        guard let workspaceID = displayWorkspaces[display] else { return nil }
        return workspaces[workspaceID]
    }
    
    // MARK: - Window Visibility
    
    private func hideWindow(_ window: Window) {
        // Move window off-screen to hide it
        var frame = window.frame
        frame.origin = CGPoint(x: -10000, y: -10000)
        window.setFrame(frame)
    }
    
    private func showWindow(_ window: Window) {
        // Window will be repositioned by layout engine
    }
}