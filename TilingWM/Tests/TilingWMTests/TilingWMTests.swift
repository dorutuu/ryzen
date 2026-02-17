import XCTest
@testable import TilingWMLib

final class TilingWMTests: XCTestCase {
    func testWorkspaceCreation() async {
        let manager = WorkspaceManager()
        let workspace = await manager.createWorkspace(id: "test", name: "Test Workspace")
        
        XCTAssertEqual(workspace.id, "test")
        XCTAssertEqual(workspace.name, "Test Workspace")
        
        let retrieved = await manager.getWorkspace(id: "test")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, "test")
    }
    
    func testDefaultWorkspaces() async {
        let manager = WorkspaceManager()
        let workspaces = await manager.getAllWorkspaces()
        
        XCTAssertEqual(workspaces.count, 9)
        XCTAssertEqual(workspaces[0].id, "1")
        XCTAssertEqual(workspaces[8].id, "9")
    }
    
    func testWorkspaceSwitching() async {
        let manager = WorkspaceManager()
        let result = await manager.switchToWorkspace(id: "2")
        
        XCTAssertTrue(result)
        
        let activeID = await manager.getActiveWorkspaceID()
        XCTAssertEqual(activeID, "2")
        
        let active = await manager.getActiveWorkspace()
        XCTAssertEqual(active?.id, "2")
    }
}