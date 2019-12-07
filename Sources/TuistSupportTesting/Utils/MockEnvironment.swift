import Basic
import Foundation
import TuistSupport
import XCTest

public class MockEnvironment: Environmenting {
    let directory: TemporaryDirectory
    var setupCallCount: UInt = 0
    var setupErrorStub: Error?

    init() throws {
        directory = try TemporaryDirectory(removeTreeOnDeinit: true)
        try FileManager.default.createDirectory(at: versionsDirectory.url,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
    }

    public var shouldOutputBeColoured: Bool = false
    public var isStandardOutputInteractive: Bool = false

    public var versionsDirectory: AbsolutePath {
        directory.path.appending(component: "Versions")
    }

    public var derivedProjectsDirectory: AbsolutePath {
        directory.path.appending(component: "DerivedProjects")
    }

    public var settingsPath: AbsolutePath {
        directory.path.appending(component: "settings.json")
    }

    public var cacheDirectory: AbsolutePath {
        directory.path.appending(component: "Cache")
    }

    public var projectDescriptionHelpersCacheDirectory: AbsolutePath {
        cacheDirectory.appending(component: "ProjectDescriptionHelpers")
    }

    func path(version: String) -> AbsolutePath {
        versionsDirectory.appending(component: version)
    }
}