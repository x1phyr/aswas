import Foundation
import Testing
@testable import AswasCore

struct DomainTests {
    @Test
    func workspaceRoundTripsThroughCodable() throws {
        let original = makeWorkspace()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WorkspaceSnapshot.self, from: data)

        #expect(decoded == original)
        #expect(decoded.schemaVersion == WorkspaceSchema.currentVersion)
        #expect(decoded.finder.tabCount == 1)
    }

    @Test
    func rejectsInvalidSelectedTabIndex() {
        var workspace = makeWorkspace()
        workspace.finder.windows[0].selectedTabIndex = 2

        #expect(throws: WorkspaceValidationError.self) {
            try WorkspaceValidator.validate(workspace)
        }
    }

    @Test
    func migrationRejectsUnknownSchemaVersion() throws {
        let json = "{\"schemaVersion\":99}"
        let decoder = JSONDecoder()

        #expect(throws: WorkspaceMigrationError.unsupportedVersion(99)) {
            try WorkspaceMigration.decode(Data(json.utf8), using: decoder)
        }
    }

    @Test
    func pathNormalizationHandlesTildeUnicodeAndSpaces() {
        let home = URL(fileURLWithPath: "/Users/test-user")
        let normalized = PathNormalizer.normalize(
            "~/工作 项目/../工作 项目/卡牌",
            homeDirectory: home
        )

        #expect(normalized == "/Users/test-user/工作 项目/卡牌")
        #expect(PathNormalizer.abbreviateHome(normalized, homeDirectory: home) == "~/工作 项目/卡牌")
    }
}
