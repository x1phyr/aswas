import Foundation

public struct CodableRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isFiniteAndPositive: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite
            && width > 0 && height > 0
    }
}
