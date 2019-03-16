import Basic
import Foundation
import TuistCore

class Workspace: Equatable {
    // MARK: - Attributes
    
    enum Element: Equatable {
        case file(path: AbsolutePath)
        case folderReference(path: AbsolutePath)
        
        var path: AbsolutePath {
            switch self {
            case let .file(path: path):
                return path
            case let .folderReference(path: path):
                return path
            }
        }
    }

    let name: String
    var projects: [AbsolutePath]
    let additionalFiles: [Element]

    // MARK: - Init

    init(name: String,
         projects: [AbsolutePath],
         additionalFiles: [Element]) {
        self.name = name
        self.projects = projects
        self.additionalFiles = additionalFiles
    }

    // MARK: - Equatable

    static func == (lhs: Workspace, rhs: Workspace) -> Bool {
        return lhs.name == rhs.name && lhs.projects == rhs.projects && lhs.additionalFiles == rhs.additionalFiles
    }
}
