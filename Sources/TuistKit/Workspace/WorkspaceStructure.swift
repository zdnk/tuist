import Foundation
import Basic
import TuistCore

struct WorkspaceStructure {
    
    indirect enum Element: Equatable {
        case file(path: AbsolutePath)
        case folderReference(path: AbsolutePath)
        case group(name: String, absolutePath: AbsolutePath, contents: [Element])
        case project(path: AbsolutePath)
    }
    
    let name: String
    let contents: [Element]
    
}

struct DirectoryStructure {
    let path: AbsolutePath
    let fileHandler: FileHandling
    
    let projects: [AbsolutePath]
    let files: [Workspace.Element]
    
    init(path: AbsolutePath,
         fileHandler: FileHandling = FileHandler(),
         projects: [AbsolutePath],
         files: [Workspace.Element]) {
        self.path = path
        self.fileHandler = fileHandler
        self.projects = projects
        self.files = files
    }
    
    func buildGraph() throws -> Graph {
        return try buildGraph(path: path)
    }
    
    private func buildGraph(path: AbsolutePath) throws -> Graph {
        let root = Graph()
        
        let fileNodes = files.map(fileNode)
        let projectNodes = projects.map(projectNode)
        let allNodes = (projectNodes + fileNodes).sorted(by: { $0.path < $1.path })
        
        let commonAncestor = allNodes.reduce(path) { $0.commonAncestor(with: $1.path) }
        for node in allNodes {
            let relativePath = node.path.relative(to: commonAncestor)
            var currentNode = root
            var absolutePath = commonAncestor
            for component in relativePath.components.dropLast() {
                absolutePath = absolutePath.appending(component: component)
                currentNode = currentNode.add(.directory(absolutePath))
            }
            
            currentNode.add(node)
        }
        
        return root
    }
    
    func fileNode(from element: Workspace.Element) -> Node {
        switch element {
        case let .file(path: path):
            return .file(path)
        case let .folderReference(path: path):
            return .folderReference(path)
        }
    }
    
    func projectNode(from path: AbsolutePath) -> Node {
        return .project(path)
    }
    
}

struct WorkspaceStructureFactory {
    
    let path: AbsolutePath
    let workspace: Workspace
    
    let containers: [String] = [
        ".playground",
        ".xcodeproj"
    ]
    
    private func directoryGraphToWorkspaceStructureElement(content: DirectoryStructure.Node) -> WorkspaceStructure.Element? {
        switch content {
        case .file(let file):
            return .file(path: file)
        case .directory(let path, _) where path.suffix.map(containers.contains) ?? false:
            return .file(path: path)
        case .project(let path):
            return .project(path: path)
        case .directory(let path, let contents):
            return .group(name: path.basename,
                          absolutePath: path,
                          contents: contents.nodes.compactMap(directoryGraphToWorkspaceStructureElement))
        case let .folderReference(path):
            return .folderReference(path: path)
        }
    }
    
    func makeWorkspaceStructure() throws -> WorkspaceStructure {
        let graph = try DirectoryStructure(path: path, projects: workspace.projects, files: workspace.additionalFiles).buildGraph()
        return WorkspaceStructure(name: workspace.name, contents: graph.nodes.compactMap(directoryGraphToWorkspaceStructureElement))
    }
    
}

extension Sequence where Element == AbsolutePath {
    
    func contains(fileName: String) -> Bool {
        return contains(where: { $0.basename == fileName })
    }
    
    func matches(path: AbsolutePath) -> Bool {
        return contains(where: { $0.contains(path) || path.contains($0) })
    }
    
}

extension Sequence where Element == DirectoryStructure.Node {
    
    func files() -> [AbsolutePath] {
        return compactMap{ content in
            switch content {
            case .file(let path): return path
            case .directory, .project, .folderReference: return nil
            }
        }
    }
    
    func contains(fileName: String) -> Bool {
        return files().contains(fileName: fileName)
    }
    
    func containsProjectInGraph() -> Bool {
        return first { node in
            switch node {
                case .project: return true
                case .directory(_, let graph): return graph.nodes.containsProjectInGraph()
                case _: return false
                }
            } != nil
    }
    
}

extension DirectoryStructure {
    class Graph: Equatable, ExpressibleByArrayLiteral, CustomDebugStringConvertible {
        var nodes: [Node] = []
        private var directoryCache: [AbsolutePath: Graph] = [:]
        
        required init(arrayLiteral elements: DirectoryStructure.Node...) {
            nodes = elements
            directoryCache = Dictionary(uniqueKeysWithValues: nodes.compactMap {
                switch $0 {
                case let .directory(path, graph):
                    return (path, graph)
                default:
                    return nil
                }
            })
        }
        
        @discardableResult
        func add(_ node: Node) -> Graph {
            switch node {
            case .file(_), .project(_), .folderReference(_):
                nodes.append(node)
                return self
            case let .directory(path, _):
                if let existingNode = directoryCache[path] {
                    return existingNode
                } else {
                    let directoryGraph = Graph()
                    nodes.append(.directory(path, directoryGraph))
                    directoryCache[path] = directoryGraph
                    return directoryGraph
                }
            }
        }
        
        var debugDescription: String {
            return nodes.debugDescription
        }
        
        static func == (lhs: DirectoryStructure.Graph,
                        rhs: DirectoryStructure.Graph) -> Bool {
            return lhs.nodes == rhs.nodes
        }
    }
}

extension DirectoryStructure {
    indirect enum Node: Equatable {
        case file(AbsolutePath)
        case project(AbsolutePath)
        case directory(AbsolutePath, DirectoryStructure.Graph)
        case folderReference(AbsolutePath)
        
        static func directory(_ path: AbsolutePath) -> Node {
            return .directory(path, Graph())
        }
        
        var path: AbsolutePath {
            switch self {
            case let .file(path):
                return path
            case let .project(path):
                return path
            case let .directory(path, _):
                return path
            case let .folderReference(path):
                return path
            }
        }
    }
}

extension DirectoryStructure.Node: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
        case let .file(path):
            return "file: \(path.asString)"
        case let .project(path):
            return "project: \(path.asString)"
        case let .directory(path, graph):
            return "directory: \(path.asString) > \(graph.nodes)"
        case let .folderReference(path):
            return "folderReference: \(path.asString)"
        }
    }
}
