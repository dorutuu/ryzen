import Foundation
import CoreGraphics
import ApplicationServices
import Logging

public actor LayoutEngine {
    private let workspaceManager: WorkspaceManager
    private let logger = Logger(label: "com.tilingwm.layoutengine")
    
    // Layout settings
    public var gapSize: CGFloat = 10
    public var outerGap: CGFloat = 10
    
    public init(workspaceManager: WorkspaceManager) {
        self.workspaceManager = workspaceManager
    }
    
    // MARK: - Layout Calculation
    
    public func layoutWorkspace(_ workspaceID: String) async {
        guard let workspace = await workspaceManager.getWorkspace(id: workspaceID),
              let display = workspace.display ?? getMainDisplay() else { return }
        
        let screenFrame = getScreenFrame(for: display)
        let availableFrame = applyGaps(to: screenFrame)
        
        let windows = workspace.windows.filter { !$0.isMinimized && !$0.isFullscreen && !$0.isFloating }
        
        switch workspace.layout {
        case .bsp:
            applyBSPLayout(windows: windows, in: availableFrame)
        case .stack:
            applyStackLayout(windows: windows, in: availableFrame)
        case .float:
            // Do nothing for floating layout
            break
        }
    }
    
    public func layoutAllWorkspaces() async {
        let workspaces = await workspaceManager.getAllWorkspaces()
        for workspace in workspaces {
            await layoutWorkspace(workspace.id)
        }
    }
    
    // MARK: - BSP Layout (Binary Space Partitioning)
    
    private func applyBSPLayout(windows: [Window], in frame: CGRect) {
        guard !windows.isEmpty else { return }
        
        if windows.count == 1 {
            windows[0].setFrame(frame)
            return
        }
        
        // Split windows recursively
        let midIndex = windows.count / 2
        let firstHalf = Array(windows[0..<midIndex])
        let secondHalf = Array(windows[midIndex...])
        
        // Determine split direction based on frame aspect ratio
        let isHorizontalSplit = frame.width > frame.height
        
        if isHorizontalSplit {
            let leftWidth = frame.width * CGFloat(firstHalf.count) / CGFloat(windows.count)
            let leftFrame = CGRect(x: frame.minX, y: frame.minY, width: leftWidth - gapSize/2, height: frame.height)
            let rightFrame = CGRect(x: frame.minX + leftWidth + gapSize/2, y: frame.minY, width: frame.width - leftWidth - gapSize/2, height: frame.height)
            
            applyBSPLayout(windows: firstHalf, in: leftFrame)
            applyBSPLayout(windows: secondHalf, in: rightFrame)
        } else {
            let topHeight = frame.height * CGFloat(firstHalf.count) / CGFloat(windows.count)
            let topFrame = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: topHeight - gapSize/2)
            let bottomFrame = CGRect(x: frame.minX, y: frame.minY + topHeight + gapSize/2, width: frame.width, height: frame.height - topHeight - gapSize/2)
            
            applyBSPLayout(windows: firstHalf, in: topFrame)
            applyBSPLayout(windows: secondHalf, in: bottomFrame)
        }
    }
    
    // MARK: - Stack Layout
    
    private func applyStackLayout(windows: [Window], in frame: CGRect) {
        guard !windows.isEmpty else { return }
        
        if windows.count == 1 {
            windows[0].setFrame(frame)
            return
        }
        
        // First window takes most of the space (master)
        let masterRatio: CGFloat = 0.6
        let masterFrame = CGRect(
            x: frame.minX,
            y: frame.minY,
            width: frame.width * masterRatio - gapSize/2,
            height: frame.height
        )
        windows[0].setFrame(masterFrame)
        
        // Stack the rest on the right
        let stackWidth = frame.width * (1 - masterRatio) - gapSize/2
        let stackX = frame.minX + frame.width * masterRatio + gapSize/2
        let windowHeight = (frame.height - gapSize * CGFloat(windows.count - 2)) / CGFloat(windows.count - 1)
        
        for (index, window) in windows.dropFirst().enumerated() {
            let windowFrame = CGRect(
                x: stackX,
                y: frame.minY + CGFloat(index) * (windowHeight + gapSize),
                width: stackWidth,
                height: windowHeight
            )
            window.setFrame(windowFrame)
        }
    }
    
    // MARK: - Helper Methods
    
    private func applyGaps(to frame: CGRect) -> CGRect {
        return CGRect(
            x: frame.minX + outerGap,
            y: frame.minY + outerGap,
            width: frame.width - 2 * outerGap,
            height: frame.height - 2 * outerGap
        )
    }
    
    private func getMainDisplay() -> CGDirectDisplayID? {
        return CGMainDisplayID()
    }
    
    private func getScreenFrame(for display: CGDirectDisplayID) -> CGRect {
        let bounds = CGDisplayBounds(display)
        
        // Convert to Cocoa coordinates (y-flipped)
        let mainDisplayBounds = CGDisplayBounds(CGMainDisplayID())
        return CGRect(
            x: bounds.minX,
            y: mainDisplayBounds.height - bounds.maxY,
            width: bounds.width,
            height: bounds.height
        )
    }
    
    // MARK: - Settings
    
    public func setGapSize(_ size: CGFloat) {
        gapSize = size
    }
    
    public func setOuterGap(_ size: CGFloat) {
        outerGap = size
    }
}