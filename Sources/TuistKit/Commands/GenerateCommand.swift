import Basic
import Foundation
import SPMUtility
import TuistCore
import TuistGenerator

class GenerateCommand: NSObject, Command {
    // MARK: - Static

    static let command = "generate"
    static let overview = "Generates an Xcode workspace to start working on the project."

    // MARK: - Attributes

    private let generator: Generating
    private let printer: Printing
    private let fileHandler: FileHandling
    private let manifestLoader: GraphManifestLoading
    private let clock: Clock

    let pathArgument: OptionArgument<String>
    let projectOnlyArgument: OptionArgument<Bool>

    // MARK: - Init

    required convenience init(parser: ArgumentParser) {
        let fileHandler = FileHandler()
        let system = System()
        let printer = Printer()
        let resourceLocator = ResourceLocator(fileHandler: fileHandler)
        let manifestLoader = GraphManifestLoader(fileHandler: fileHandler,
                                                 system: system,
                                                 resourceLocator: resourceLocator,
                                                 deprecator: Deprecator(printer: printer))
        let manifestTargetGenerator = ManifestTargetGenerator(manifestLoader: manifestLoader,
                                                              resourceLocator: resourceLocator)
        let manifestLinter = ManifestLinter()
        let modelLoader = GeneratorModelLoader(fileHandler: fileHandler,
                                               manifestLoader: manifestLoader,
                                               manifestLinter: manifestLinter,
                                               manifestTargetGenerator: manifestTargetGenerator)
        let generator = Generator(system: system,
                                  printer: printer,
                                  fileHandler: fileHandler,
                                  modelLoader: modelLoader)
        self.init(parser: parser,
                  printer: printer,
                  fileHandler: fileHandler,
                  generator: generator,
                  manifestLoader: manifestLoader,
                  clock: WallClock())
    }

    init(parser: ArgumentParser,
         printer: Printing,
         fileHandler: FileHandling,
         generator: Generating,
         manifestLoader: GraphManifestLoading,
         clock: Clock) {
        let subParser = parser.add(subparser: GenerateCommand.command, overview: GenerateCommand.overview)
        self.generator = generator
        self.printer = printer
        self.fileHandler = fileHandler
        self.manifestLoader = manifestLoader
        self.clock = clock

        pathArgument = subParser.add(option: "--path",
                                     shortName: "-p",
                                     kind: String.self,
                                     usage: "The path where the project will be generated.",
                                     completion: .filename)

        projectOnlyArgument = subParser.add(option: "--project-only",
                                            kind: Bool.self,
                                            usage: "Only generate the local project (without generating its dependencies).")
    }

    func run(with arguments: ArgumentParser.Result) throws {
        let timer = clock.startTimer()
        let path = self.path(arguments: arguments)
        let projectOnly = arguments.get(projectOnlyArgument) ?? false

        _ = try generator.generate(at: path,
                                   manifestLoader: manifestLoader,
                                   projectOnly: projectOnly)

        let time = String(format: "%.3f", timer.stop())
        printer.print(success: "Project generated.")
        printer.print("Total time taken: \(time)s", color: .white)
    }

    // MARK: - Fileprivate

    private func path(arguments: ArgumentParser.Result) -> AbsolutePath {
        if let path = arguments.get(pathArgument) {
            return AbsolutePath(path, relativeTo: fileHandler.currentPath)
        } else {
            return fileHandler.currentPath
        }
    }
}
