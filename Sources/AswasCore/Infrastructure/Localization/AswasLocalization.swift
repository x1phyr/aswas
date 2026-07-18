import Foundation

public enum AswasLanguage: String, CaseIterable, Codable, Sendable {
    case system
    case english
    case simplifiedChinese

    var localizationCode: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .current
        case .english: Locale(identifier: "en")
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        }
    }
}

public enum AswasLocalization {
    public static let languageDefaultsKey = "appLanguage"

    public static var language: AswasLanguage {
        let value = UserDefaults.standard.string(forKey: languageDefaultsKey)
        return value.flatMap(AswasLanguage.init(rawValue:)) ?? .system
    }

    public static func string(_ key: String, _ arguments: CVarArg...) -> String {
        string(key, arguments: arguments)
    }

    public static func string(_ key: String, arguments: [CVarArg]) -> String {
        string(key, language: language, arguments: arguments)
    }

    public static func string(
        _ key: String,
        language selectedLanguage: AswasLanguage,
        arguments: [CVarArg] = []
    ) -> String {
        let format = localizedBundle(for: selectedLanguage).localizedString(
            forKey: key,
            value: key,
            table: nil
        )
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: selectedLanguage.locale, arguments: arguments)
    }

    private static func localizedBundle(for language: AswasLanguage) -> Bundle {
        let base = resourcesBundle
        guard let code = language.localizationCode else {
            return base
        }

        // SwiftPM lowercases some localization directory names (for example,
        // `zh-Hans.lproj` becomes `zh-hans.lproj`) in its generated bundle.
        // Packaged apps preserve the source casing, so accept both forms.
        let candidates = [code, code.lowercased()]
        for candidate in candidates {
            if
                let path = base.path(forResource: candidate, ofType: "lproj"),
                let bundle = Bundle(path: path)
            {
                return bundle
            }
        }

        return base
    }

    private static var resourcesBundle: Bundle {
        // A packaged app copies localizations directly into Contents/Resources.
        // SwiftPM development builds keep them in the AswasCore resource bundle.
        if Bundle.main.bundleURL.pathExtension == "app" {
            return .main
        }
        return .module
    }
}
