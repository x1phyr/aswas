import Foundation

public struct DisplayDescriptor: Codable, Equatable, Sendable {
    public var displayID: UInt32?
    public var localizedName: String?
    public var frame: CodableRect
    public var visibleFrame: CodableRect
    public var scaleFactor: Double

    public init(
        displayID: UInt32?,
        localizedName: String?,
        frame: CodableRect,
        visibleFrame: CodableRect,
        scaleFactor: Double
    ) {
        self.displayID = displayID
        self.localizedName = localizedName
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.scaleFactor = scaleFactor
    }
}
