import AswasCore
import Foundation

enum L10n {
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        AswasLocalization.string(key, arguments: arguments)
    }
}
