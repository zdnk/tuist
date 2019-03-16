import Basic
import Foundation
import ProjectDescription
import TuistCore

enum GraphManifestLoaderError: FatalError, Equatable {
    case projectDescriptionNotFound(AbsolutePath)
    case unexpectedOutput(AbsolutePath)
    case manifestNotFound(Manifest?, AbsolutePath)

    static func manifestNotFound(_ path: AbsolutePath) -> GraphManifestLoaderError {
        return .manifestNotFound(nil, path)
    }

    var description: String {
        switch self {
        case let .projectDescriptionNotFound(path):
            return "Couldn't find ProjectDescription.framework at path \(path.asString)"
        case let .unexpectedOutput(path):
            return "Unexpected output trying to parse the manifest at path \(path.asString)"
        case let .manifestNotFound(manifest, path):
            return "\(manifest?.fileName ?? "Manifest") not found at path \(path.asString)"
        }
    }

    var type: ErrorType {
        switch self {
        case .unexpectedOutput:
            return .bug
        case .projectDescriptionNotFound:
            return .bug
        case .manifestNotFound:
            return .abort
        }
    }

    // MARK: - Equatable

    static func == (lhs: GraphManifestLoaderError, rhs: GraphManifestLoaderError) -> Bool {
        switch (lhs, rhs) {
        case let (.projectDescriptionNotFound(lhsPath), .projectDescriptionNotFound(rhsPath)):
            return lhsPath == rhsPath
        case let (.unexpectedOutput(lhsPath), .unexpectedOutput(rhsPath)):
            return lhsPath == rhsPath
        case let (.manifestNotFound(lhsManifest, lhsPath), .manifestNotFound(rhsManifest, rhsPath)):
            return lhsManifest == rhsManifest && lhsPath == rhsPath
        default:
            return false
        }
    }
}

enum Manifest: Equatable, Hashable {
    case project
    case workspace
    case setup
    case environment(name: String)

    static let allPredefinedCases: Set<Manifest> = [.project, .workspace, .setup]

    var fileName: String {
        switch self {
        case .project:
            return "Project.swift"
        case .workspace:
            return "Workspace.swift"
        case .setup:
            return "Setup.swift"
        case let .environment(name):
            return name
        }
    }

    static func manifest(from fileName: String) -> Manifest? {
        switch fileName {
        case Manifest.project.fileName: return .project
        case Manifest.workspace.fileName: return .workspace
        case Manifest.setup.fileName: return .setup
        case let name where name.hasSuffix(".Environment.swift"):
            return .environment(name: fileName)
        default:
            return nil
        }
    }
}

protocol GraphManifestLoading {
    func loadProject(at path: AbsolutePath) throws -> ProjectDescription.Project
    func loadWorkspace(at path: AbsolutePath) throws -> ProjectDescription.Workspace
    func loadSetup(at path: AbsolutePath) throws -> [Upping]
    func manifests(at path: AbsolutePath) -> Set<Manifest>
    func manifestPath(at path: AbsolutePath, manifest: Manifest) throws -> AbsolutePath
}

class GraphManifestLoader: GraphManifestLoading {
    // MARK: - Attributes

    /// File handler to interact with the file system.
    let fileHandler: FileHandling

    /// Instance to run commands in the system.
    let system: Systeming

    /// Resource locator to look up Tuist-related resources.
    let resourceLocator: ResourceLocating

    /// Depreactor to notify about deprecations.
    let deprecator: Deprecating

    /// A decoder instance for decoding the raw manifest data to their concrete types
    private let decoder: JSONDecoder

    /// A parser instance for scanning the raw manifest data to find Environment.at calls
    private let environmentAtParser: EnvironmentAtParser

    // MARK: - Init

    /// Initializes the manifest loader with its attributes.
    ///
    /// - Parameters:
    ///   - fileHandler: File handler to interact with the file system.
    ///   - system: Instance to run commands in the system.
    ///   - resourceLocator: Resource locator to look up Tuist-related resources.
    ///   - deprecator: Depreactor to notify about deprecations.
    init(fileHandler: FileHandling = FileHandler(),
         system: Systeming = System(),
         resourceLocator: ResourceLocating = ResourceLocator(),
         deprecator: Deprecating = Deprecator()) {
        self.fileHandler = fileHandler
        self.system = system
        self.resourceLocator = resourceLocator
        self.deprecator = deprecator
        decoder = JSONDecoder()
        environmentAtParser = EnvironmentAtParser()
    }

    func manifestPath(at path: AbsolutePath, manifest: Manifest) throws -> AbsolutePath {
        let filePath = path.appending(component: manifest.fileName)

        if fileHandler.exists(filePath) {
            return filePath
        } else {
            throw GraphManifestLoaderError.manifestNotFound(manifest, path)
        }
    }

    func manifests(at path: AbsolutePath) -> Set<Manifest> {
        return .init(Manifest.allPredefinedCases.filter {
            fileHandler.exists(path.appending(component: $0.fileName))
        })
    }

    func loadProject(at path: AbsolutePath) throws -> ProjectDescription.Project {
        return try loadManifest(.project, at: path)
    }

    func loadWorkspace(at path: AbsolutePath) throws -> ProjectDescription.Workspace {
        return try loadManifest(.workspace, at: path)
    }

    func loadSetup(at path: AbsolutePath) throws -> [Upping] {
        let setupPath = path.appending(component: Manifest.setup.fileName)
        guard fileHandler.exists(setupPath) else {
            throw GraphManifestLoaderError.manifestNotFound(.setup, path)
        }

        let setup = try loadManifestData(at: setupPath)
        let setupJson = try JSON(data: setup)
        let actionsJson: [JSON] = try setupJson.get("actions")
        return try actionsJson.compactMap {
            try Up.with(dictionary: $0,
                        projectPath: path,
                        fileHandler: fileHandler)
        }
    }

    // MARK: - Private

    private func loadManifest<T: Decodable>(_ manifest: Manifest, at path: AbsolutePath) throws -> T {
        let manifestPath = path.appending(component: manifest.fileName)
        guard fileHandler.exists(manifestPath) else {
            throw GraphManifestLoaderError.manifestNotFound(manifest, path)
        }
        let data = try loadManifestData(at: manifestPath)
        return try decoder.decode(T.self, from: data)
    }

    private func loadManifestData(at path: AbsolutePath) throws -> Data {
        return try fileHandler.inTemporaryDirectory { temporaryDirPath in
            let environments = try dumpRequiredEnvironments(at: path)
            let temporaryManifestPath = temporaryDirPath.appending(component: "\(UUID().uuidString).swift")
            try fileHandler.copy(from: path, to: temporaryManifestPath)
            return try loadManifestWithEnvironmentsData(at: temporaryManifestPath,
                                                        environments: environments)
        }
    }

    private func loadManifestWithEnvironmentsData(at path: AbsolutePath, environments: [String]) throws -> Data {
        let loadMethodCall: (String) -> String = { json in return "Environment.load(from: \"\(json)\")" }
        let manifestContent = try String(contentsOfFile: path.asString)
        let manifestMutableContent = NSMutableString(string: manifestContent)
        let environmentsRanges = environmentAtParser.parse(manifestContent)
        let offsets = environmentsRanges.reduce(into: [0]) { (result, range) in
            let last = result.last!
            let loadMethodCallString = loadMethodCall(environments[result.count - 1])
            result.append(last + loadMethodCallString.utf8.count - range.length)
        }
        environmentsRanges.enumerated().forEach { i, range in
            let rightOffset = NSRange(location: range.location + offsets[i], length: range.length)
            let newString = loadMethodCall(environments[i])
            manifestMutableContent.replaceCharacters(in: rightOffset, with: newString)
        }

        try (manifestMutableContent as String).write(to: path.asURL, atomically: true, encoding: .utf8)
        
        let jsonString = try dumpManifest(at: path, type: .default)
        return try utf8Data(from: jsonString, at: path)
    }

    private func dumpManifest(at path: AbsolutePath, type: DumpType = .default) throws -> String {
        let projectDescriptionPath = try resourceLocator.projectDescription()
        let arguments: [String] = [
            "/usr/bin/xcrun",
            "swiftc",
            "--driver-mode=swift",
            "-suppress-warnings",
            "-I", projectDescriptionPath.parentDirectory.asString,
            "-L", projectDescriptionPath.parentDirectory.asString,
            "-F", projectDescriptionPath.parentDirectory.asString,
            "-lProjectDescription",
            path.asString,
            type.rawValue
        ]
        guard let jsonString = try system.capture(arguments).spm_chuzzle() else {
            switch type {
            case .default:
                throw GraphManifestLoaderError.unexpectedOutput(path)
            case .environment:
                return ""
            }
        }
        return jsonString
    }

    private func dumpRequiredEnvironments(at path: AbsolutePath) throws -> [String] {
        return try dumpManifest(at: path, type: .environment)
            .split(separator: "\n")
            .map { String($0) }
            .map { try utf8Data(from: $0, at: path) }
            .map { try decoder.decode(EnvironmentAt.self, from: $0) }
            .map { (RelativePath(Array(RelativePath($0.path).components.dropLast()).joined(separator: "/")),
                    try dumpManifest(at: path.parentDirectory.appending(RelativePath($0.path)))) }
            .map { $0.1
                .replacingOccurrences(of: "${ENVIRONMENT_DIR}", with: $0.0.asString)
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") }
    }

    private func utf8Data(from string: String, at path: AbsolutePath) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw GraphManifestLoaderError.unexpectedOutput(path)
        }
        return data
    }

    private enum DumpType: String {
        case `default` = "--dump"
        case environment = "--dump-environment"
    }

    class EnvironmentAtParser {

        // swiftlint:disable:next force_try
        private let regex = try! NSRegularExpression(pattern: "Environment[\\s]*\\.at\\([\\s]*path:[a-zA-Z0-9\"\\/\\.\\ ]+[\\s]*\\)", options: [])

        func parse(_ manifestContent: String) -> [NSRange] {
            let matches = regex.matches(in: manifestContent, range: NSRange(location: 0, length: manifestContent.utf8.count))
            return matches.map { $0.range }
        }
    }
}
