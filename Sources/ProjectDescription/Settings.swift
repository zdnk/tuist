import Foundation

// MARK: - Configuration

public class Configuration: Codable {
    
    public enum Base {
        case debug, release
    }
    
    enum Kind {
        case base, debug, release, extended
    }
    
    let settings: [String: String]
    let xcconfig: String?
    let base: Base?
    let kind: Kind
    
    init(settings: [String: String],
         xcconfig: String? = nil,
         base: Base? = nil,
         kind: Kind) {
        self.settings = settings
        self.xcconfig = xcconfig
        self.base = base
        self.kind = kind
    }
    
    public static func base(settings: [String: String] = [:]) -> Configuration {
        return Configuration(settings: settings, kind: .base)
    }
    
    public static func debug(settings: [String: String] = [:], xcconfig: String? = nil) -> Configuration {
        return Configuration(settings: settings, xcconfig: xcconfig, kind: .debug)
    }
    
    public static func release(settings: [String: String] = [:], xcconfig: String? = nil) -> Configuration {
        return Configuration(settings: settings, xcconfig: xcconfig, kind: .release)
    }
    
    public static func extended(_ name: String, from: Base, settings: [String: String], xcconfig: String? = nil) -> Configuration {
        return Configuration(settings: settings, xcconfig: xcconfig, base: from, kind: .extended)
    }
    
    
}


//public class Configuration: Codable {
//    public let settings: [String: String]
//    public let xcconfig: String?
//
//    public enum CodingKeys: String, CodingKey {
//        case settings
//        case xcconfig
//    }
//
//    public init(settings: [String: String] = [:], xcconfig: String? = nil) {
//        self.settings = settings
//        self.xcconfig = xcconfig
//    }
//
//    public static func settings(_ settings: [String: String], xcconfig: String? = nil) -> Configuration {
//        return Configuration(settings: settings, xcconfig: xcconfig)
//    }
//}
//
//// MARK: - Settings
//
//public class Settings: Codable {
//    public let base: [String: String]
//    public let debug: Configuration?
//    public let release: Configuration?
//
//    public init(base: [String: String] = [:],
//                debug: Configuration? = nil,
//                release: Configuration? = nil) {
//        self.base = base
//        self.debug = debug
//        self.release = release
//    }
//}
