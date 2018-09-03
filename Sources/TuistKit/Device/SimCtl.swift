import Foundation
import TuistCore

protocol SimCtling: AnyObject {
    func run(_ args: [String]) throws -> String
    func run(_ args: String...) throws -> String
    func runAndDecode<T: Decodable>(_ args: String..., type: T.Type) throws -> T
}

enum SimCtlError: FatalError, Equatable {
    case notFound
    case invalidOutput

    var description: String {
        switch self {
        case .notFound: return "simctl not found in the system"
        case .invalidOutput: return "Couldn't process the output from simctl"
        }
    }

    var type: ErrorType {
        switch self {
        case .notFound: return .abort
        case .invalidOutput: return .abort
        }
    }
}

final class SimCtl: SimCtling {

    // MARK: - Attributes

    private let system: Systeming
    private let jsonDecoder: JSONDecoder = JSONDecoder()

    // MARK: - Init

    init(system: Systeming = System()) {
        self.system = system
    }

    // MARK: - SimCtling

    func run(_ args: [String]) throws -> String {
        var simctlPath: String!
        do {
            simctlPath = try system.capture("/usr/bin/xcrun", "-f", "simctl", verbose: false).throwIfError().stdout.chuzzle()
        } catch {
            throw SimCtlError.notFound
        }
        if simctlPath == nil { throw SimCtlError.notFound }

        var arguments: [String] = [simctlPath]
        arguments.append(contentsOf: args)

        let result = try system.capture(arguments, verbose: false).throwIfError()
        return result.stdout
    }

    func run(_ args: String...) throws -> String {
        return try run(args)
    }

    func runAndDecode<T: Decodable>(_ args: String..., type: T.Type) throws -> T {
        let output = try run(args)
        guard let data = output.data(using: .utf8) else {
            throw SimCtlError.invalidOutput
        }
        return try jsonDecoder.decode(type, from: data)
    }
}
