import Basic
import Foundation
import TuistCore

enum GraphError: FatalError {
    case unsupportedFileExtension(String)

    var description: String {
        switch self {
        case let .unsupportedFileExtension(productType):
            return "Could't obtain product file extension for product type: \(productType)"
        }
    }

    var type: ErrorType {
        switch self {
        case .unsupportedFileExtension:
            return .bug
        }
    }
}

enum DependencyReference: Equatable {
    case absolute(AbsolutePath)
    case product(String)

    static func == (lhs: DependencyReference, rhs: DependencyReference) -> Bool {
        switch (lhs, rhs) {
        case let (.absolute(lhsPath), .absolute(rhsPath)):
            return lhsPath == rhsPath
        case let (.product(lhsName), .product(rhsName)):
            return lhsName == rhsName
        default:
            return false
        }
    }
}

protocol Graphing: AnyObject {
    var name: String { get }
    var entryPath: AbsolutePath { get }
    var entryNodes: [GraphNode] { get }
    var projects: [Project] { get }
    var frameworks: [FrameworkNode] { get }

    func linkableDependencies(path: AbsolutePath, name: String) throws -> [DependencyReference]
    func librariesPublicHeadersFolders(path: AbsolutePath, name: String) -> [AbsolutePath]
    func embeddableFrameworks(path: AbsolutePath, name: String, system: Systeming) throws -> [DependencyReference]
    func dependencies(path: AbsolutePath, name: String) -> Set<GraphNode>
    func dependencies(path: AbsolutePath) -> Set<GraphNode>
    func targetDependencies(path: AbsolutePath, name: String) -> [String]
    func staticLibraryDependencies(path: AbsolutePath, name: String) -> [DependencyReference]
}

class Graph: Graphing {
    // MARK: - Attributes

    private let cache: GraphLoaderCaching
    let name: String
    let entryPath: AbsolutePath
    let entryNodes: [GraphNode]
    var projects: [Project] {
        return Array(cache.projects.values)
    }

    // MARK: - Init

    init(name: String,
         entryPath: AbsolutePath,
         cache: GraphLoaderCaching,
         entryNodes: [GraphNode]) {
        self.name = name
        self.entryPath = entryPath
        self.cache = cache
        self.entryNodes = entryNodes
    }

    // MARK: - Internal

    var frameworks: [FrameworkNode] {
        return cache.precompiledNodes.values.compactMap({ $0 as? FrameworkNode })
    }

    func dependencies(path: AbsolutePath) -> Set<GraphNode> {
        var dependencies: Set<GraphNode> = Set()
        cache.targetNodes[path]?.forEach {
            dependencies.formUnion(self.dependencies(path: path, name: $0.key))
        }
        return dependencies
    }

    func dependencies(path: AbsolutePath, name: String) -> Set<GraphNode> {
        var dependencies: Set<GraphNode> = Set()
        var add: ((GraphNode) -> Void)!
        add = { node in
            guard let targetNode = node as? TargetNode else { return }
            targetNode.dependencies.forEach({ dependencies.insert($0) })
            targetNode.dependencies.compactMap({ $0 as? TargetNode }).forEach(add)
        }
        if let targetNode = self.targetNode(path: path, name: name) {
            add(targetNode)
        }
        return dependencies
    }

    func targetDependencies(path: AbsolutePath, name: String) -> [String] {
        guard let targetNode = self.targetNode(path: path, name: name) else { return [] }
        return targetNode.dependencies
            .compactMap({ $0 as? TargetNode })
            .filter({ $0.path == path })
            .map({ $0.target.name })
    }
    
    func staticLibraryDependencies(path: AbsolutePath, name: String) -> [DependencyReference] {
        
        guard let targetNode = self.targetNode(path: path, name: name) else {
            return [ ]
        }

        return targetNode.dependencies
            .compactMap{ $0 as? TargetNode }
            .filter{ $0.target.product == .staticLibrary }
            .map{ targetNode in
                return DependencyReference.product(targetNode.target.productName)
            }
        
    }

    func linkableDependencies(path: AbsolutePath, name: String) throws -> [DependencyReference] {
        guard let targetNode = self.targetNode(path: path, name: name) else { return [] }

        var references: [DependencyReference] = []

        /// Precompiled libraries and frameworks
        references.append(contentsOf: targetNode
            .dependencies
            .compactMap({ $0 as? PrecompiledNode })
            .map({ DependencyReference.absolute($0.path) }))
        
        switch targetNode.target.product {
        case .staticLibrary, .dynamicLibrary, .framework:
            // Ignore the products, they do not want to directly link the static libraries, the top level bundles will be responsible.
            break
        case .app, .unitTests, .uiTests:
            
            // Find all static libraries and add them to the references.

            var stack = Stack<TargetNode>()
            
            for node in targetNode.dependencies where node is TargetNode {
                stack.push(node as! TargetNode)
            }
            
            var visited: Set<GraphNode> = .init()
            var staticLibraries: [TargetNode] = [ ]
            
            while !stack.isEmpty {
                
                guard let node = stack.pop() else {
                    continue
                }
                
                if visited.contains(node) {
                    continue
                }
                
                visited.insert(node)
                
                if node.target.product == .staticLibrary {
                    staticLibraries.append(node)
                }
                
                for child in node.dependencies where !visited.contains(child) && child is TargetNode {
                    stack.push(child as! TargetNode)
                }
                
            }
            
            references.append(contentsOf: staticLibraries.map{
                DependencyReference.product($0.target.productName)
            })
            
        }
        
        // Link dynamic libraries and frameworks
        references.append(contentsOf: targetNode
            .dependencies
            .compactMap{ $0 as? TargetNode }
            .filter{ $0.target.product == .framework || $0.target.product == .dynamicLibrary }
            .map{ targetNode in
                return DependencyReference.product(targetNode.target.productName)
            })
        
        return references
    }

    func librariesPublicHeadersFolders(path: AbsolutePath, name: String) -> [AbsolutePath] {
        guard let targetNode = self.targetNode(path: path, name: name) else { return [] }
        return targetNode
            .dependencies
            .compactMap({ $0 as? LibraryNode })
            .map({ $0.publicHeaders })
    }

    func embeddableFrameworks(path: AbsolutePath,
                              name: String,
                              system: Systeming) throws -> [DependencyReference] {
        guard let targetNode = self.targetNode(path: path, name: name) else { return [] }

        let validProducts: [Product] = [
            .app,
            .unitTests,
            .uiTests,
//            .tvExtension,
//            .appExtension,
//            .watchExtension,
//            .watch2Extension,
//            .messagesExtension,
//            .watchApp,
//            .watch2App,
//            .messagesApplication,
        ]

        if !validProducts.contains(targetNode.target.product) { return [] }

        var references: [DependencyReference] = []
        let dependencies = self.dependencies(path: path, name: name)

        /// Precompiled frameworks
        references.append(contentsOf: try dependencies
            .compactMap({ $0 as? FrameworkNode })
            .filter({ try $0.linking(system: system) == .dynamic })
            .map({ DependencyReference.absolute($0.path) }))

        /// Other targets' frameworks.
        references.append(contentsOf: dependencies
            .compactMap({ $0 as? TargetNode })
            .filter({ $0.target.product == .framework })
            .map({ targetNode in
                return DependencyReference.product(targetNode.target.productName)
        }))
        return references
    }

    // MARK: - Fileprivate

    fileprivate func targetNode(path: AbsolutePath, name: String) -> TargetNode? {
        if let targetNode = self.entryNodes.compactMap({ $0 as? TargetNode }).first(where: {
            $0.path == path && $0.target.name == name
        }) {
            return targetNode
        }
        guard let targetNodes = cache.targetNodes[path] else { return nil }
        return targetNodes[name]
    }
}

public struct Stack<T> {
    fileprivate var array = [T]()
    
    public var isEmpty: Bool {
        return array.isEmpty
    }
    
    public var count: Int {
        return array.count
    }
    
    public mutating func push(_ element: T) {
        array.append(element)
    }
    
    public mutating func pop() -> T? {
        return array.popLast()
    }
    
    public var top: T? {
        return array.last
    }
}
