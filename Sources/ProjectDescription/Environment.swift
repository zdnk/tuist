import Foundation

public class Environment: Codable {

    public enum VariableType {
        case settings(_ name: EnvironmentIdentifier.ResourceIdentifier, _ value: Settings)
        case string(_ name: EnvironmentIdentifier.ResourceIdentifier, _ value: String)
    }

    public typealias Identifier = String

    public let settings: [EnvironmentIdentifier.ResourceIdentifier: Settings]
    public let strings: [EnvironmentIdentifier.ResourceIdentifier: String]

    public convenience init(_ variables: VariableType...) {
        let settingsKeyValues = variables.compactMap { (variable: VariableType) -> (String, Settings)? in
            switch variable {
            case let .settings(name, value):
                return (name, value)
            default:
                return nil
            }

        }
        let stringsKeyValues = variables.compactMap { (variable: VariableType) -> (String, String)? in
            switch variable {
            case let .string(name, value):
                return (name, value)
            default:
                return nil
            }
        }
        let settings: [EnvironmentIdentifier.ResourceIdentifier: Settings] = Dictionary(uniqueKeysWithValues: settingsKeyValues)
        let strings: [EnvironmentIdentifier.ResourceIdentifier: String] = Dictionary(uniqueKeysWithValues: stringsKeyValues)
        self.init(settings: settings,
                  strings: strings)
    }

    public init(settings: [EnvironmentIdentifier.ResourceIdentifier: Settings] = [:],
                strings: [EnvironmentIdentifier.ResourceIdentifier: String] = [:]) {
        self.settings = settings
        self.strings = strings
        dumpIfNeeded(self)
    }

    public static func load(from json: String) -> Environment {
        let decoder = JSONDecoder()

        // swiftlint:disable force_try
        let data = json.data(using: .utf8)!
        return try! decoder.decode(Environment.self, from: data)
        // swiftlint:enable force_try
    }

    // Mock function
    public static func at(path: String, _ line: UInt = #line) -> Environment {
        dumpIfNeeded(EnvironmentAt(path: path, line: line))
        return Environment()
    }
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

public struct EnvironmentAt: Codable {
    public let path: String
    public let line: UInt
}
