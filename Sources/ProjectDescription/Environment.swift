import Foundation

public class Environment: Codable {

    public typealias Identifier = String

    public let settings: [Identifier: Settings]

    public init(settings: [Identifier: Settings]) {
        self.settings = settings
        dumpIfNeeded(self)
    }

    public static func settings(_ identifier: Identifier) -> Settings {
        return Settings(identifier)
    }
}

public protocol EnvironmentReference {

    var identifier: Environment.Identifier? { get }
}
