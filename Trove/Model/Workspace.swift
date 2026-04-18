import Foundation

struct Workspace: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var order: Int
    var createdAt: Date

    static let defaultWorkspace = Workspace(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Default", icon: "tray", order: 0, createdAt: Date()
    )
}

@MainActor
final class WorkspaceManager: ObservableObject {
    static let shared = WorkspaceManager()
    @Published private(set) var workspaces: [Workspace] = [.defaultWorkspace]
    @Published var activeWorkspaceId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private init() {}

    func add(name: String, icon: String = "tray") {
        workspaces.append(Workspace(id: UUID(), name: name, icon: icon, order: workspaces.count, createdAt: Date()))
    }

    func delete(_ workspace: Workspace) {
        guard workspace.id != activeWorkspaceId else { return }
        workspaces.removeAll { $0.id == workspace.id }
    }

    func switchTo(_ workspace: Workspace) {
        activeWorkspaceId = workspace.id
    }
}
