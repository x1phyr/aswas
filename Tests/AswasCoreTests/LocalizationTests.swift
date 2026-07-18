import Testing
@testable import AswasCore

struct LocalizationTests {
    @Test
    func resolvesEnglishAndSimplifiedChinese() {
        let english = AswasLocalization.string(
            "menu.restore_last",
            language: .english
        )
        let chinese = AswasLocalization.string(
            "menu.restore_last",
            language: .simplifiedChinese
        )

        #expect(english == "Restore Last Workspace")
        #expect(chinese == "恢复上一个工作区")
    }

    @Test
    func formatsLocalizedCounts() {
        let chinese = AswasLocalization.string(
            "workspace.summary",
            language: .simplifiedChinese,
            arguments: [3, 8]
        )

        #expect(chinese == "3 个窗口 · 8 个文件夹")
    }
}
