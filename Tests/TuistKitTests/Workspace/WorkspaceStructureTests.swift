import Foundation
@testable import TuistKit
import XCTest
import Basic
@testable import TuistCoreTesting

final class DirectoryStructureTests: XCTestCase {
    
    func test_buildGraph_projects() throws {
        // Given
        let projects = [
            "/path/to/workspace/Modules/A",
            "/path/to/workspace/Modules/B",
            "/path/to/workspace/Modules/Sub/C",
            "/path/to/workspace/Modules/Sub/D",
        ]
        let fileHandler = try MockFileHandler()
        let subject = DirectoryStructure(path: AbsolutePath("/path/to/workspace"),
                                         fileHandler: fileHandler,
                                         projects: projects.map { AbsolutePath($0) },
                                         files: [])
        // When
        let graph = try subject.buildGraph()
        
        // Then
        XCTAssertEqual(graph, [
            .directory("/path/to/workspace/Modules", [
                .project("/path/to/workspace/Modules/A"),
                .project("/path/to/workspace/Modules/B"),
                .directory("/path/to/workspace/Modules/Sub", [
                    .project("/path/to/workspace/Modules/Sub/C"),
                    .project("/path/to/workspace/Modules/Sub/D"),
                ])
            ])
        ])
    }
    
    func test_buildGraph_projectsAndFiles() throws {
        // Given
        let projects = [
            "/path/to/workspace/Modules/A",
            "/path/to/workspace/Modules/B"
        ]
        let files = [
            "/path/to/workspace/Documentation/README.md",
            "/path/to/workspace/Documentation/setup/usage.md",
            "/path/to/workspace/Documentation/generate/guide.md",
            "/path/to/workspace/README.md",
        ]
        let fileHandler = try MockFileHandler()
        let subject = DirectoryStructure(path: "/path/to/workspace",
                                         fileHandler: fileHandler,
                                         projects: projects.map { AbsolutePath($0) },
                                         files: files.map { .file(path: AbsolutePath($0)) })
        
        // When
        let graph = try subject.buildGraph()
        
        // Then
        XCTAssertEqual(graph, [
            .directory("/path/to/workspace/Documentation", [
                .file("/path/to/workspace/Documentation/README.md"),
                .directory("/path/to/workspace/Documentation/generate", [
                    .file("/path/to/workspace/Documentation/generate/guide.md"),
                ]),
                .directory("/path/to/workspace/Documentation/setup", [
                    .file("/path/to/workspace/Documentation/setup/usage.md"),
                ]),
            ]),
            .directory("/path/to/workspace/Modules", [
                .project("/path/to/workspace/Modules/A"),
                .project("/path/to/workspace/Modules/B")
            ]),
            .file("/path/to/workspace/README.md")
        ])
    }
    
    func test_buildGraph_folderReferences() throws {
        // Given
        let files: [Workspace.Element] = [
            .folderReference(path: "/path/to/workspace/Documentation/Guides"),
            .folderReference(path: "/path/to/workspace/Documentation/Proposals"),
            .file(path: "/path/to/workspace/README.md"),
        ]
        let fileHandler = try MockFileHandler()
        let subject = DirectoryStructure(path: AbsolutePath("/path/to/workspace"),
                                         fileHandler: fileHandler,
                                         projects: [],
                                         files: files)
        
        // When
        let graph = try subject.buildGraph()
        
        // Then
        XCTAssertEqual(graph, [
            .directory("/path/to/workspace/Documentation", [
                .folderReference("/path/to/workspace/Documentation/Guides"),
                .folderReference("/path/to/workspace/Documentation/Proposals")
            ]),
            .file("/path/to/workspace/README.md")
        ])
    }
}
