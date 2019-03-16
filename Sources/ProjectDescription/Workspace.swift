import Foundation

// MARK: - Workspace

public class Workspace: Codable {
    
    public let name: String
    public let projects: [String]
    public let additionalFiles: [Element]
    
    public init(name: String, projects: [String], additionalFiles: [Element] = [ ]) {
        self.name = name
        self.projects = projects
        self.additionalFiles = additionalFiles
        dumpIfNeeded(self)
    }
    
}

extension Workspace {
    public enum Element: Codable {
        case glob(pattern: String)
        case folderReference(path: String)
        
        enum TypeName: String, Codable {
            case glob
            case folderReference
        }
        private var typeName: TypeName {
            switch self {
            case .glob:
                return .glob
            case .folderReference:
                return .folderReference
            }
        }
        
        public enum CodingKeys: String, CodingKey {
            case type
            case pattern
            case path
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(TypeName.self, forKey: .type)
            switch type {
            case .glob:
                let pattern = try container.decode(String.self, forKey: .pattern)
                self = .glob(pattern: pattern)
            case .folderReference:
                let path = try container.decode(String.self, forKey: .path)
                self = .folderReference(path: path)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(typeName, forKey: .type)
            switch self {
            case let .glob(pattern: pattern):
                try container.encode(pattern, forKey: .pattern)
            case let .folderReference(path: path):
                try container.encode(path, forKey: .path)
            }
        }
    }
}

extension Workspace.Element: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .glob(pattern: value)
    }
}
