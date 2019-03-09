import Foundation

public class Environment: Codable {

    public enum VariableType {
        case settings(_ name: EnvironmentIdentifier.ResourceIdentifier, _ value: Settings)
    }

    public typealias Identifier = String

    public let settings: [EnvironmentIdentifier.ResourceIdentifier: Settings]

    public convenience init(_ variables: VariableType...) {
        let settingsKeyValues = variables.compactMap { (variable: VariableType) -> (String, Settings)? in
            switch variable {
            case let .settings(name, value):
                return (name, value)
            }
        }
        let settings: [EnvironmentIdentifier.ResourceIdentifier: Settings] = Dictionary(uniqueKeysWithValues: settingsKeyValues)
        self.init(settings: settings)
    }

    public init(settings: [EnvironmentIdentifier.ResourceIdentifier: Settings]) {
        self.settings = settings
        dumpIfNeeded(self)
    }

    public static func at(path: String) -> EnvironmentVariables {
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

public class EnvironmentVariables {

    private let path: String?

    init(path: String?) {
        self.path = path
    }

    public func settings(_ resourceIdentifier: EnvironmentIdentifier.ResourceIdentifier) -> Settings {
        return Settings(identifier(resourceIdentifier))
    }

    private func identifier(_ resourceIdentifier: EnvironmentIdentifier.ResourceIdentifier) -> EnvironmentIdentifier {
        return EnvironmentIdentifier(path: path, resourceIdentifier: resourceIdentifier)
    }
}
