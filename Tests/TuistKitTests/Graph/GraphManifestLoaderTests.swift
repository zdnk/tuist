import Basic
import Foundation
import XCTest
@testable import TuistCoreTesting
@testable import TuistKit

final class GraphManifestLoaderErrorTests: XCTestCase {
    func test_description() {
        XCTAssertEqual(GraphManifestLoaderError.projectDescriptionNotFound(AbsolutePath("/test")).description, "Couldn't find ProjectDescription.framework at path /test")
        XCTAssertEqual(GraphManifestLoaderError.unexpectedOutput(AbsolutePath("/test/")).description, "Unexpected output trying to parse the manifest at path /test")
        XCTAssertEqual(GraphManifestLoaderError.manifestNotFound(.project, AbsolutePath("/test/")).description, "Project.swift not found at path /test")
        XCTAssertEqual(GraphManifestLoaderError.manifestNotFound(nil, AbsolutePath("/test/")).description, "Manifest not found at path /test")
    }

    func test_type() {
        XCTAssertEqual(GraphManifestLoaderError.projectDescriptionNotFound(AbsolutePath("/test")).type, .bug)
        XCTAssertEqual(GraphManifestLoaderError.unexpectedOutput(AbsolutePath("/test/")).type, .bug)
        XCTAssertEqual(GraphManifestLoaderError.manifestNotFound(.project, AbsolutePath("/test/")).type, .abort)
    }
}

final class ManifestTests: XCTestCase {

    func test_allPredefinedCases() {
        XCTAssertEqual(Manifest.allPredefinedCases, Set([.project, .workspace, .setup]))
    }

    func test_fileName() {
        XCTAssertEqual(Manifest.project.fileName, "Project.swift")
        XCTAssertEqual(Manifest.workspace.fileName, "Workspace.swift")
        XCTAssertEqual(Manifest.setup.fileName, "Setup.swift")
        XCTAssertEqual(Manifest.environment(name: "Shared.Environment.swift").fileName, "Shared.Environment.swift")
    }

    func test_manifest() {
        XCTAssertEqual(Manifest.manifest(from: "Project.swift"), Manifest.project)
        XCTAssertEqual(Manifest.manifest(from: "Workspace.swift"), Manifest.workspace)
        XCTAssertEqual(Manifest.manifest(from: "Setup.swift"), Manifest.setup)
        XCTAssertEqual(Manifest.manifest(from: "Shared.Environment.swift"), Manifest.environment(name: "Shared.Environment.swift"))

        XCTAssertNil(Manifest.manifest(from: "Shared_Environment.swift"))
        XCTAssertNil(Manifest.manifest(from: "Shared.Environment"))
    }
}

final class GraphManifestLoaderTests: XCTestCase {
    var fileHandler: MockFileHandler!
    var deprecator: MockDeprecator!
    var subject: GraphManifestLoader!

    override func setUp() {
        super.setUp()
        fileHandler = try! MockFileHandler()
        deprecator = MockDeprecator()
        subject = GraphManifestLoader(fileHandler: fileHandler,
                                      deprecator: deprecator)
    }

    func test_loadProject() throws {
        // Given
        let content = """
        import ProjectDescription
        let project = Project(name: "tuist")
        """

        let manifestPath = fileHandler.currentPath.appending(component: Manifest.project.fileName)
        try content.write(to: manifestPath.url,
                          atomically: true,
                          encoding: .utf8)

        // When
        let got = try subject.loadProject(at: fileHandler.currentPath)

        // Then

        XCTAssertEqual(got.name, "tuist")
    }

    func test_loadWorkspace() throws {
        // Given
        let content = """
        import ProjectDescription
        let workspace = Workspace(name: "tuist", projects: [])
        """

        let manifestPath = fileHandler.currentPath.appending(component: Manifest.workspace.fileName)
        try content.write(to: manifestPath.url,
                          atomically: true,
                          encoding: .utf8)

        // When
        let got = try subject.loadWorkspace(at: fileHandler.currentPath)

        // Then
        XCTAssertEqual(got.name, "tuist")
    }

    func test_loadSetup() throws {
        // Given
        let content = """
        import ProjectDescription
        let setup = Setup([
                        .custom(name: "hello", meet: ["a", "b"], isMet: ["c"])
                    ])
        """

        let manifestPath = fileHandler.currentPath.appending(component: Manifest.setup.fileName)
        try content.write(to: manifestPath.url,
                          atomically: true,
                          encoding: .utf8)

        // When
        let got = try subject.loadSetup(at: fileHandler.currentPath)

        // Then
        let customUp = got.first as? UpCustom
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(customUp?.name, "hello")
        XCTAssertEqual(customUp?.meet, ["a", "b"])
        XCTAssertEqual(customUp?.isMet, ["c"])
    }

    func test_load_invalidFormat() throws {
        // Given
        let content = """
        import ABC
        let project
        """

        let manifestPath = fileHandler.currentPath.appending(component: Manifest.project.fileName)
        try content.write(to: manifestPath.url,
                          atomically: true,
                          encoding: .utf8)

        // When / Then
        XCTAssertThrowsError(
            try subject.loadProject(at: fileHandler.currentPath)
        )
    }

    func test_load_missingManifest() throws {
        XCTAssertThrowsError(
            try subject.loadProject(at: fileHandler.currentPath)
        ) { error in
            XCTAssertEqual(error as? GraphManifestLoaderError, GraphManifestLoaderError.manifestNotFound(.project, fileHandler.currentPath))
        }
    }

    func test_manifestsAt() throws {
        // Given
        try fileHandler.touch(fileHandler.currentPath.appending(component: "Project.swift"))
        try fileHandler.touch(fileHandler.currentPath.appending(component: "Workspace.swift"))
        try fileHandler.touch(fileHandler.currentPath.appending(component: "Setup.swift"))

        // When
        let got = subject.manifests(at: fileHandler.currentPath)

        // Then
        XCTAssertTrue(got.contains(.project))
        XCTAssertTrue(got.contains(.workspace))
        XCTAssertTrue(got.contains(.setup))
    }

    func test_loadWorkspace_withEnvironments() throws {
        // Given
        let first = """
        import ProjectDescription

        let enviornment = Environment(
            strings: ["workspace_name": "WorkspaceName"]
        )
        """

        let second = """
        import ProjectDescription

        let enviornment = Environment(
            strings: ["workspace_name2": "WorkspaceName2"]
        )
        """

        let manifest = """
        import ProjectDescription

        let env = Environment.at(path: "../First.Environment.swift")
        let env2 = Environment.at(path: "../Second.Environment.swift")

        let n1 = env.strings["workspace_name"] ?? "-"
        let n2 = env2.strings["workspace_name2"] ?? "-"
        let wn = "\\(n1)\\(n2)"
        let workspace = Workspace(name: wn,
                                  projects: ["project1"])
        """

        let firstPath = fileHandler.currentPath.appending(component: "First.Environment.swift")
        try first.write(to: firstPath.url, atomically: true, encoding: .utf8)

        let secondPath = fileHandler.currentPath.appending(component: "Second.Environment.swift")
        try second.write(to: secondPath.url, atomically: true, encoding: .utf8)

        let manifestPath = fileHandler.currentPath.appending(components: "Project", "Workspace.swift")
        try fileHandler.createFolder(manifestPath.parentDirectory)
        try manifest.write(to: manifestPath.url, atomically: true, encoding: .utf8)

        // When
        let got = try subject.loadWorkspace(at: manifestPath.parentDirectory)

        // Then
        XCTAssertEqual(got.name, "WorkspaceNameWorkspaceName2")
    }
}

final class EnvironmentAtParserTests: XCTestCase {

    private var subject: GraphManifestLoader.EnvironmentAtParser!

    override func setUp() {
        super.setUp()

        subject = GraphManifestLoader.EnvironmentAtParser()
    }

    func test_parse_whenNoCalls() {
        // Given
        let content = """
        import ProjectDescription
        let workspace = Workspace(name: "WorkspaceName",
                                  projects: ["project1"])
        """

        // When
        let got = subject.parse(content)

        // Then
        XCTAssertEqual(got, [])
    }

    func test_parse_whenSingleCall() {
        // Given
        let variable = self.variable(name: "env")
        let environmentAt = "Environment.at(path: \"File1.Environment.swift\")"
        let content = "\(variable)\(environmentAt)\(suffix())"

        // When
        let got = subject.parse(content)

        // Then
        XCTAssertEqual(got, [NSRange(location: variable.count, length: environmentAt.count)])
    }

    func test_parse_whenSingleCallPathWithSpaces() {
        // Given
        let variable = self.variable(name: "env")
        let environmentAt = "Environment.at(path: \"   File1.Environment.swift   \")"
        let content = "\(variable)\(environmentAt)\(suffix())"

        // When
        let got = subject.parse(content)

        // Then
        XCTAssertEqual(got, [NSRange(location: variable.count, length: environmentAt.count)])
    }

    func test_parse_whenSingleCallAndUntypicalSpacing() {
        // Given
        let variable = self.variable(name: "env")
        let environmentAt = "Environment   .at(          path:\"File1.Environment.swift\"             )"
        let content = "\(variable)\(environmentAt)\(suffix())"

        // When
        let got = subject.parse(content)

        // Then
        XCTAssertEqual(got, [NSRange(location: variable.count, length: environmentAt.count)])
    }

    func test_parse_whenSingleCallInMultipleLines() {
        // Given
        let variable = self.variable(name: "env")
        let environmentAt = """
        Environment
            .at(
                path: \"File1.Environment.swift\")
        """
        let content = "\(variable)\(environmentAt)\(suffix())"

        // When
        let got = subject.parse(content)

        // Then
        XCTAssertEqual(got, [NSRange(location: variable.count, length: environmentAt.count)])
    }

    func test_parse_whenMultipleCalls() {
        // Given
        let environmentAt1 = "Environment.at(path: \"File1.Environment.swift\")"
        let environmentAt2 = "Environment.at(path: \"../Dir/File2.Environment.swift\")"
        let environmentAt3 = "Environment.at(path: \"../Dir/File3\")"

        var content = String()
        content.append(variable(name: "env")); let location1 = content.count
        content.append(environmentAt1)
        content.append("\n")
        content.append(variable(name: "env2")); let location2 = content.count
        content.append(environmentAt2)
        content.append("\n")
        content.append("_ = 0\n")
        content.append(variable(name: "env3")); let location3 = content.count
        content.append(environmentAt3)
        content.append(suffix())

        // When
        let got = subject.parse(content)

        // Then
        XCTAssertEqual(got, [
            NSRange(location: location1, length: environmentAt1.count),
            NSRange(location: location2, length: environmentAt2.count),
            NSRange(location: location3, length: environmentAt3.count),
        ])
    }

    // MARK: - Helpers

    private func variable(name: String) -> String {
        return "\nlet \(name) = "
    }

    private func suffix() -> String {
        return """
        let workspace = Workspace(name: "WorkspaceName",
        projects: ["project1"])
        """
    }
}
