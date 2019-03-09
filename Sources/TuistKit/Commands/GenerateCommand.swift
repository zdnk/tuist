import Basic
import Foundation
import TuistCore
import Utility

class GenerateCommand: NSObject, Command {
    // MARK: - Static

    static let command = "generate"
    static let overview = "Generates an Xcode workspace to start working on the project."

    // MARK: - Attributes

    fileprivate let graphLoader: GraphLoading
    fileprivate let workspaceGenerator: WorkspaceGenerating
    fileprivate let printer: Printing
    fileprivate let system: Systeming
    fileprivate let resourceLocator: ResourceLocating
    fileprivate var modelLoader: GeneratorModelLoading

    let pathArgument: OptionArgument<String>
    let environmentPathArgument: OptionArgument<String>

    // MARK: - Init

    required convenience init(parser: ArgumentParser) {
        let system = System()
        let printer = Printer()
        let modelLoader = GeneratorModelLoader(fileHandler: FileHandler(),
                                               manifestLoader: GraphManifestLoader())
        self.init(graphLoader: GraphLoader(modelLoader: modelLoader),
                  modelLoader: modelLoader,
                  workspaceGenerator: WorkspaceGenerator(),
                  parser: parser,
                  printer: printer,
                  system: system,
                  resourceLocator: ResourceLocator())
    }

    init(graphLoader: GraphLoading,
         modelLoader: GeneratorModelLoading,
         workspaceGenerator: WorkspaceGenerating,
         parser: ArgumentParser,
         printer: Printing,
         system: Systeming,
         resourceLocator: ResourceLocating) {
        let subParser = parser.add(subparser: GenerateCommand.command, overview: GenerateCommand.overview)
        self.graphLoader = graphLoader
        self.modelLoader = modelLoader
        self.workspaceGenerator = workspaceGenerator
        self.printer = printer
        self.system = system
        self.resourceLocator = resourceLocator
        pathArgument = subParser.add(option: "--path",
                                     shortName: "-p",
                                     kind: String.self,
                                     usage: "The path where the project will be generated.",
                                     completion: .filename)
        environmentPathArgument = subParser.add(option: "--environment",
                                                shortName: "-e",
                                                kind: String.self,
                                                usage: "Path to the environment file.",
                                                completion: .filename)
    }

    func run(with arguments: ArgumentParser.Result) throws {
        let path = self.path(arguments: arguments)
        modelLoader.environmentPath = arguments.get(environmentPathArgument)
            .map { $0.hasSuffix(".Environment.swift") ? $0 : "\($0).Environment.swift" }
            .map { $0.hasPrefix("/") ?  AbsolutePath($0) :  AbsolutePath(path, $0) }
        let graph = try graphLoader.load(path: path)
        try workspaceGenerator.generate(path: path,
                                        graph: graph,
                                        options: GenerationOptions(),
                                        directory: .manifest)

        printer.print(success: "Project generated.")
    }

    // MARK: - Fileprivate

    fileprivate func path(arguments: ArgumentParser.Result) -> AbsolutePath {
        if let path = arguments.get(pathArgument) {
            return AbsolutePath(path, relativeTo: AbsolutePath.current)
        } else {
            return AbsolutePath.current
        }
    }
}
