import Foundation

struct FinderRestoreWindowPayload: Decodable, Sendable {
    var success: Bool
    var windowID: Int?
    var frameRestored: Bool?
    var viewModeRestored: Bool?
    var errorNumber: Int?
    var message: String?
}

struct FinderCloseWindowPayload: Decodable, Sendable {
    var success: Bool
    var found: Bool
    var errorNumber: Int?
    var message: String?
}
