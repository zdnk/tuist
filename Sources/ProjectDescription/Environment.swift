import Foundation

public enum Either<A: Codable, B: Codable>: Codable{
    case first(_ first: A)
    case second(_ second: B)
}

public class Environment: Codable {

    public typealias Identifier = String

    public let settings: [EnvironmentIdentifier.ResourceIdentifier: Settings]

    public init(settings: [EnvironmentIdentifier.ResourceIdentifier: Settings]) {
        self.settings = settings
        dumpIfNeeded(self)
    }

    public static func variables() -> EnvironmentVariables {
        return EnvironmentVariables(path: nil)
    }

    public static func variables(path: String) -> EnvironmentVariables {
        return EnvironmentVariables(path: path)
    }
}

public protocol EnvironmentReference: Codable {

    var identifier: EnvironmentIdentifier? { get }
}

public struct EnvironmentIdentifier: Codable {

    public typealias ResourceIdentifier = String

    /// Path to the environment file
    public let path: String?

    /// Resource identifier
    public let identifier: ResourceIdentifier

    init(path: String? = nil, resourceIdentifier: ResourceIdentifier) {
        self.path = path
        self.identifier = resourceIdentifier
    }
}

private extension EnvironmentIdentifier.ResourceIdentifier {

    static var `default`: String { return "default" }
}

public class EnvironmentVariables {

    private let path: String?

    init(path: String?) {
        self.path = path
    }

    public func settings() -> Settings {
        return settings(EnvironmentIdentifier.ResourceIdentifier.default)
    }

    public func settings(_ resourceIdentifier: EnvironmentIdentifier.ResourceIdentifier) -> Settings {
        return Settings(identifier(resourceIdentifier))
    }

    private func identifier(_ resourceIdentifier: EnvironmentIdentifier.ResourceIdentifier) -> EnvironmentIdentifier {
        return EnvironmentIdentifier(path: path, resourceIdentifier: resourceIdentifier)
    }
}

//let env = Environment.variables(path: "../")
//let sets = env.settings()
//
//public class EnvironmentVariables {
//
//    private let _settings: [Environment.Identifier: Settings] = [:]
//
//    public func settings() -> Settings {
//        return try settings(Environment.Identifier.default)
//    }
//
//    public func settings(_ identifier: Environment.Identifier) throws -> Settings {
//        guard let value = _settings[identifier] else {
//            return Settings("fdsafewaf ewaf eaw") // throw!!
//        }
//        return value
//    }
//}

/**
 let env = Environment.from("../")

 Project(
    settings: env.settings()

 or

 Project(
    settings: env.settings("cpp_settings")
 */
