import OSLog

public enum AswasLog {
    private static let subsystem = "io.github.x1phyr.aswas"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let workspace = Logger(subsystem: subsystem, category: "workspace")
    public static let finder = Logger(subsystem: subsystem, category: "finder")
    public static let automation = Logger(subsystem: subsystem, category: "automation")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")
    public static let restore = Logger(subsystem: subsystem, category: "restore")
    public static let capture = Logger(subsystem: subsystem, category: "capture")
}
