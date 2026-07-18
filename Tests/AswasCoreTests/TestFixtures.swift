import Foundation
@testable import AswasCore

func makeWorkspace(
    id: UUID = UUID(),
    name: String = "RoyalMerge",
    updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> WorkspaceSnapshot {
    WorkspaceSnapshot(
        id: id,
        name: name,
        createdAt: Date(timeIntervalSince1970: 1_600_000_000),
        updatedAt: updatedAt,
        finder: FinderWorkspaceState(
            windows: [
                FinderWindowState(
                    tabs: [
                        FinderTabState(path: "/Users/test/RoyalMerge", displayName: "RoyalMerge")
                    ],
                    selectedTabIndex: 0,
                    frame: CodableRect(x: 20, y: 40, width: 900, height: 700),
                    normalizedFrame: CodableRect(x: 0.1, y: 0.1, width: 0.7, height: 0.7),
                    display: DisplayDescriptor(
                        displayID: 1,
                        localizedName: "Built-in Display",
                        frame: CodableRect(x: 0, y: 0, width: 1512, height: 982),
                        visibleFrame: CodableRect(x: 0, y: 25, width: 1512, height: 927),
                        scaleFactor: 2
                    ),
                    viewMode: .list
                )
            ]
        )
    )
}

func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("aswas-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
