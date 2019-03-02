import Basic
import Foundation
import TuistCore
import TuistGenerator

enum GeneratorModelLoaderError: Error, Equatable, FatalError {
    case malformedManifest(String)
    
    var type: ErrorType {
        switch self {
        case .malformedManifest:
            return .abort
        }
    }
    
    var description: String {
        switch self {
        case .malformedManifest(let details):
            return "The Project manifest appears to be malformed: \(details)"
        }
    }
}

class GeneratorModelLoader: GeneratorModelLoading {

    var environmentPath: AbsolutePath?

    private let fileHandler: FileHandling
    private let manifestLoader: GraphManifestLoading
    
    init(fileHandler: FileHandling, manifestLoader: GraphManifestLoading) {
        self.fileHandler = fileHandler
        self.manifestLoader = manifestLoader
    }
    
    func loadProject(at path: AbsolutePath) throws -> Project {
        let environment = try loadEnvironment()
        let json = try manifestLoader.load(.project, path: path)
        let project = try TuistKit.Project.from(json: json, path: path, fileHandler: fileHandler, environment: environment)
        return project
    }
    
    func loadWorkspace(at path: AbsolutePath) throws -> Workspace {
        let environment = try loadEnvironment()
        let json = try manifestLoader.load(.workspace, path: path)
        let workspace = try TuistKit.Workspace.from(json: json, path: path, environment: environment)
        return workspace
    }

    private func loadEnvironment() throws -> Environment? {
        guard let environmentPath = environmentPath else {
            return nil
        }
        let environmentJson = try manifestLoader.load(.environment, path: environmentPath)
        let environment = try Environment.from(json: environmentJson, path: environmentPath, fileHandler: fileHandler)
        return environment
    }
}

extension TuistKit.Workspace {
    static func from(json: JSON, path: AbsolutePath, environment: Environment?) throws -> TuistKit.Workspace {
        let projectsStrings: [String] = try json.get("projects")
        let name: String = try json.get("name")
        let projectsRelativePaths: [RelativePath] = projectsStrings.map { RelativePath($0) }
        let projects = projectsRelativePaths.map { path.appending($0) }
        return Workspace(name: name, projects: projects)
    }
}

extension TuistKit.Project {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling, environment: Environment?) throws -> TuistKit.Project {
        let name: String = try json.get("name")
        let targetsJSONs: [JSON] = try json.get("targets")
        let targets = try targetsJSONs.map { try TuistKit.Target.from(json: $0, path: path, fileHandler: fileHandler, environment: environment) }
        let settingsJSON: JSON? = try? json.get("settings")
        let settings = try settingsJSON.map { try TuistKit.Settings.from(json: $0, path: path, fileHandler: fileHandler, environment: environment) }
        
        return Project(path: path,
                       name: name,
                       settings: settings ?? Settings.default,
                       targets: targets)
    }
}

extension TuistKit.Target {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling, environment: Environment?) throws -> TuistKit.Target {
        let name: String = try json.get("name")
        let platformString: String = try json.get("platform")
        guard let platform = TuistKit.Platform(rawValue: platformString) else {
            throw GeneratorModelLoaderError.malformedManifest("unrecognized platform '\(platformString)'")
        }
        let productString: String = try json.get("product")
        guard let product = TuistKit.Product(rawValue: productString) else {
            throw GeneratorModelLoaderError.malformedManifest("unrecognized product '\(productString)'")
        }
        let bundleId: String = try json.get("bundle_id")
        let dependenciesJSON: [JSON] = try json.get("dependencies")
        let dependencies = try dependenciesJSON.map { try TuistKit.Dependency.from(json: $0, path: path, fileHandler: fileHandler) }
        
        // Info.plist
        let infoPlistPath: String = try json.get("info_plist")
        let infoPlist = path.appending(RelativePath(infoPlistPath))
        
        // Entitlements
        let entitlementsPath: String? = try? json.get("entitlements")
        let entitlements = entitlementsPath.map { path.appending(RelativePath($0)) }
        
        // Settings
        let settingsDictionary: [String: JSONSerializable]? = try? json.get("settings")
        let settings = try settingsDictionary.map { try TuistKit.Settings.from(json: JSON($0), path: path, fileHandler: fileHandler, environment: environment) }
        
        // Sources
        let sourcesString: String = try json.get("sources")
        let sources = try TuistKit.Target.sources(projectPath: path, sources: sourcesString, fileHandler: fileHandler)
        
        // Resources
        let resourcesString: String? = try? json.get("resources")
        let resources = try resourcesString.map {
            try TuistKit.Target.resources(projectPath: path, resources: $0, fileHandler: fileHandler) } ?? []
        
        // Headers
        let headersJSON: JSON? = try? json.get("headers")
        let headers = try headersJSON.map { try TuistKit.Headers.from(json: $0, path: path, fileHandler: fileHandler) }
        
        // Core Data Models
        let coreDataModelsJSON: [JSON] = (try? json.get("core_data_models")) ?? []
        let coreDataModels = try coreDataModelsJSON.map { try TuistKit.CoreDataModel.from(json: $0, path: path, fileHandler: fileHandler) }
        
        // Actions
        let actionsJSON: [JSON] = (try? json.get("actions")) ?? []
        let actions = try actionsJSON.map { try TuistKit.TargetAction.from(json: $0, path: path, fileHandler: fileHandler) }
        
        // Environment
        let environment: [String: String] = (try? json.get("environment")) ?? [:]
        
        return Target(name: name,
                      platform: platform,
                      product: product,
                      bundleId: bundleId,
                      infoPlist: infoPlist,
                      entitlements: entitlements,
                      settings: settings,
                      sources: sources,
                      resources: resources,
                      headers: headers,
                      coreDataModels: coreDataModels,
                      actions: actions,
                      environment: environment,
                      dependencies: dependencies)
    }
}

extension TuistKit.Settings {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling, environment: Environment?) throws -> TuistKit.Settings {
        if let identifier = json.getIdentifier() {
            guard let environment = environment else {
                throw GeneratorModelLoaderError.malformedManifest("Used Environment.settings '\(identifier)' but Environment not found")
            }
            return try environment.lookupSettings(identifier: identifier)
        }

        let base: [String: String] = try json.get("base")
//        let debugJSON: JSON? = try? json.get("debug")
//        let debug = try debugJSON.flatMap { try Configuration.from(json: $0, path: path, fileHandler: fileHandler) }
//        let releaseJSON: JSON? = try? json.get("release")
//        let release = try releaseJSON.flatMap { try Configuration.from(json: $0, path: path, fileHandler: fileHandler) }
//        let configurations = [
//            BuildConfiguration.debug: debug,
//            BuildConfiguration.release: release
//        ]
        let configurations = try json.getArray("configurations").compactMap({ try TuistKit.Configuration.from(json: $0, path: path, fileHandler: fileHandler) })
        return Settings(base: base, configurations: Dictionary(uniqueKeysWithValues: configurations))

//        return .init(x
//            base: try json.get("base"),
//            configurations: try json.getArray("configurations").compactMap({ try TuistKit.Configuration.from(json: $0, path: path, fileHandler: fileHandler) })
//        )
    }
}

extension TuistKit.Configuration {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling) throws -> (TuistKit.BuildConfiguration, TuistKit.Configuration) {
        let name: String = try json.get("name")
        let buildConfigurationString: String = try json.get("buildConfiguration")
        let settings: [String: String] = try json.get("settings")
        let xcconfigString: String? = json.get("xcconfig")
        let xcconfig = xcconfigString.flatMap { path.appending(RelativePath($0)) }
        let variant: BuildConfiguration.Variant = buildConfigurationString == "release" ? .release : .debug
        let buildConfiguration = BuildConfiguration(name: name, predefined: false, variant: variant)
        let configuration = Configuration(settings: settings, xcconfig: xcconfig)
        return (buildConfiguration, configuration)
//        return .init(
//            name: try json.get("name"),
//            buildConfiguration: BuildConfiguration(rawValue: try json.get("buildConfiguration")) ?? .debug,
//            settings: try json.get("settings"),
//            xcconfig: json.get("xcconfig").flatMap({ path.appending(RelativePath($0)) })
//        )
    }
}

extension TuistKit.TargetAction {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling) throws -> TuistKit.TargetAction {
        let name: String = try json.get("name")
        let tool: String? = try? json.get("tool")
        let order = TuistKit.TargetAction.Order(rawValue: try json.get("order"))!
        let pathString: String? = try? json.get("path")
        let path = pathString.map { AbsolutePath($0, relativeTo: path) }
        let arguments: [String] = try json.get("arguments")
        return TargetAction(name: name, order: order, tool: tool, path: path, arguments: arguments)
    }
}

extension TuistKit.CoreDataModel {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling) throws -> TuistKit.CoreDataModel {
        let pathString: String = try json.get("path")
        let modelPath = path.appending(RelativePath(pathString))
        if !fileHandler.exists(modelPath) {
            throw GraphLoadingError.missingFile(modelPath)
        }
        let versions: [AbsolutePath] = path.glob("*.xcdatamodel")
        let currentVersion: String = try json.get("current_version")
        return CoreDataModel(path: modelPath, versions: versions, currentVersion: currentVersion)
    }
}

extension TuistKit.Headers {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling) throws -> TuistKit.Headers {
        let publicString: String? = try? json.get("public")
        let `public` = publicString.map { path.glob($0) } ?? []
        let privateString: String? = try? json.get("private")
        let `private` = privateString.map { path.glob($0) } ?? []
        let projectString: String? = try? json.get("project")
        let project = projectString.map { path.glob($0) } ?? []
        return Headers(public: `public`, private: `private`, project: project)
    }
}

extension TuistKit.Dependency {
    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling) throws -> TuistKit.Dependency {
        let type: String = try json.get("type")
        switch type {
        case "target":
            return .target(name: try json.get("name"))
        case "project":
            let target: String = try json.get("target")
            let path: String = try json.get("path")
            return .project(target: target, path: RelativePath(path))
        case "framework":
            let path: String = try json.get("path")
            return .framework(path: RelativePath(path))
        case "library":
            let path: String = try json.get("path")
            let publicHeaders: String = try json.get("public_headers")
            let swiftModuleMap: RelativePath? = json.get("swift_module_map").map { RelativePath($0) }
            return .library(path: RelativePath(path),
                            publicHeaders: RelativePath(publicHeaders),
                            swiftModuleMap: swiftModuleMap)
        default:
            throw GeneratorModelLoaderError.malformedManifest("unrecognized dependency type '\(type)'")
        }
    }
}

 // MARK: - JSON extension for getting dictionary value from self [String: T].

extension JSON {
    
    /// Returns a JSON mappable dictionary for self.
    fileprivate func getDictionary<T: JSONMappable>() throws -> [String: T] {
        guard case .dictionary(let value) = self else {
            throw MapError.typeMismatch(key: "<self>", expected: Dictionary<String, T>.self, json: self)
        }
        return try Dictionary(items: value.map({ ($0.0, try T.init(json: $0.1)) }))
    }

    fileprivate func getIdentifier() -> String? {
        return get("identifier")
    }
}

// MARK: - Environment

class Environment {

    let settings: [String: Settings]

    private init(settings: [String: Settings]) {
        self.settings = settings
    }

    func lookupSettings(identifier: String) throws -> Settings {
        guard let settings = self.settings[identifier] else {
            throw GeneratorModelLoaderError.malformedManifest("Unrecognized Environment.settings identifier '\(identifier)'")
        }
        return settings
    }

    static func from(json: JSON, path: AbsolutePath, fileHandler: FileHandling) throws -> Environment {
        let identifierToJson: [String: JSON] = try json.get("settings")
        let settings = try identifierToJson.mapValues { try TuistKit.Settings.from(json: $0, path: path, fileHandler: fileHandler, environment: nil) }
        return Environment(settings: settings)
    }
}
