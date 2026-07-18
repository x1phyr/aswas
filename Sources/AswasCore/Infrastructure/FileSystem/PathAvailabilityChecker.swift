import Foundation

public protocol PathAvailabilityChecking: Sendable {
    func isAccessibleDirectory(_ path: String) async -> Bool
}

public struct FileSystemPathAvailabilityChecker: PathAvailabilityChecking, Sendable {
    public init() {}

    public func isAccessibleDirectory(_ path: String) async -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
            && FileManager.default.isReadableFile(atPath: path)
    }
}
