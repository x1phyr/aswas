import Foundation

public enum PathNormalizer {
    public static func normalize(
        _ path: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let expanded: String
        if path == "~" {
            expanded = homeDirectory.path
        } else if path.hasPrefix("~/") {
            expanded = homeDirectory.appendingPathComponent(String(path.dropFirst(2))).path
        } else {
            expanded = path
        }

        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    public static func abbreviateHome(
        _ path: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let normalizedPath = normalize(path, homeDirectory: homeDirectory)
        let normalizedHome = homeDirectory.standardizedFileURL.path

        if normalizedPath == normalizedHome { return "~" }
        if normalizedPath.hasPrefix(normalizedHome + "/") {
            return "~" + normalizedPath.dropFirst(normalizedHome.count)
        }
        return normalizedPath
    }
}
