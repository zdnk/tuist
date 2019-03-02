import Basic
import Foundation
import TuistCore
@testable import TuistCoreTesting
@testable import TuistKit
import xcodeproj
import XCTest

final class ConfigGeneratorTests: XCTestCase {
    var pbxproj: PBXProj!
    var graph: Graph!
    var subject: ConfigGenerator!
    var pbxTarget: PBXNativeTarget!
    var fileHandler: MockFileHandler!
    var resourceLocator: MockResourceLocator!

    override func setUp() {
        super.setUp()
        pbxproj = PBXProj()
        pbxTarget = PBXNativeTarget(name: "Test")
        pbxproj.add(object: pbxTarget)
        resourceLocator = MockResourceLocator()
        fileHandler = try! MockFileHandler()
        resourceLocator.projectDescriptionStub = { AbsolutePath("/test") }
        subject = ConfigGenerator()
    }

    func test_generateProjectConfig_whenDebug() throws {
        try generateProjectConfig(config: .debug)
        XCTAssertEqual(pbxproj.configurationLists.count, 1)
        let configurationList: XCConfigurationList = pbxproj.configurationLists.first!

        let debugConfig: XCBuildConfiguration = configurationList.buildConfigurations.first!
        XCTAssertEqual(debugConfig.name, "Debug")
        XCTAssertEqual(debugConfig.buildSettings["Debug"] as? String, "Debug")
        XCTAssertEqual(debugConfig.buildSettings["Base"] as? String, "Base")
    }

    func test_generateProjectConfig_whenRelease() throws {
        try generateProjectConfig(config: .release)

        XCTAssertEqual(pbxproj.configurationLists.count, 1)
        let configurationList: XCConfigurationList = pbxproj.configurationLists.first!

        let releaseConfig: XCBuildConfiguration = configurationList.buildConfigurations.last!
        XCTAssertEqual(releaseConfig.name, "Release")
        XCTAssertEqual(releaseConfig.buildSettings["Release"] as? String, "Release")
        XCTAssertEqual(releaseConfig.buildSettings["Base"] as? String, "Base")
    }

    func test_generateProjectConfig_whenProjectConfigOnly() throws {
        // given
        let dir = try TemporaryDirectory(removeTreeOnDeinit: true)
        let xcconfigsDir = dir.path.appending(component: "xcconfigs")
        let projectConfigurations: [BuildConfiguration: Configuration?] = [
            BuildConfiguration(name: "Debug2", variant: .debug):
                Configuration(settings: ["DebugKey": "DebugValue"],
                              xcconfig: xcconfigsDir.appending(component: "debug.xcconfig"))]
        let target = createTarget(settings: nil)
        let project = createProject(configurations: projectConfigurations,
                                    targets: [target],
                                    path: dir.path)

        // when
        try generateProjectAndTargetsConfigs(project: project, path: dir.path)

        // then
        let buildConfigurations = pbxTarget.buildConfigurationList?.buildConfigurations
        let expected = [(name: "Debug2", ["SWIFT_VERSION": Constants.swiftVersion])]
        assertBuildSettings(buildConfigurations, expected)
    }

    func test_generateProjectConfig_whenTargetConfigOnly() throws {
        // given
        let dir = try TemporaryDirectory(removeTreeOnDeinit: true)
        let xcconfigsDir = dir.path.appending(component: "xcconfigs")
        let targetConfigurations: [BuildConfiguration: Configuration?] = [
            BuildConfiguration(name: "Debug2", variant: .debug):
                Configuration(settings: ["DebugKey": "DebugValue"],
                              xcconfig: xcconfigsDir.appending(component: "debug.xcconfig"))]
        let targetSettings = Settings(configurations: targetConfigurations)
        let target = createTarget(settings: targetSettings)
        let project = createProject(configurations: [:],
                                    targets: [target],
                                    path: dir.path)

        // when
        try generateProjectAndTargetsConfigs(project: project, path: dir.path)

        // then
        let buildConfigurations = pbxTarget.buildConfigurationList?.buildConfigurations
        let expected = [(name: "Debug2", ["SWIFT_VERSION": Constants.swiftVersion])]
        assertBuildSettings(buildConfigurations, expected)
    }

    func test_generateProjectConfig_whenProjectConfigurationsIsEmpty() throws {
        // given
        let dir = try TemporaryDirectory(removeTreeOnDeinit: true)
        let projectConfigurations: [BuildConfiguration: Configuration?] = [:]
        let target = createTarget(settings: nil)
        let project = createProject(configurations: projectConfigurations,
                                    targets: [target],
                                    path: dir.path)

        // when
        try generateProjectAndTargetsConfigs(project: project, path: dir.path)

        // then
        let buildConfigurations = pbxTarget.buildConfigurationList?.buildConfigurations
        let expected = ["Debug", "Release"].map { (name: $0, ["SWIFT_VERSION": Constants.swiftVersion]) }
        assertBuildSettings(buildConfigurations, expected)
    }

    func test_generateProjectConfig_whenProjectAndTargetConfig() throws {
        // given
        let dir = try TemporaryDirectory(removeTreeOnDeinit: true)
        let xcconfigsDir = dir.path.appending(component: "xcconfigs")
        let projectConfigurations: [BuildConfiguration: Configuration?] = [
            BuildConfiguration(name: "ProjectDebug", variant: .debug):
                Configuration(settings: ["DebugKey": "DebugValue"],
                              xcconfig: xcconfigsDir.appending(component: "debug.xcconfig"))]
        let targetConfigurations: [BuildConfiguration: Configuration?] = [
            BuildConfiguration(name: "TargetDebug", variant: .debug):
                Configuration(settings: ["DebugKey": "DebugValue"],
                              xcconfig: xcconfigsDir.appending(component: "debug.xcconfig"))]
        let targetSettings = Settings(configurations: targetConfigurations)
        let target = createTarget(settings: targetSettings)
        let project = createProject(configurations: projectConfigurations,
                                    targets: [target],
                                    path: dir.path)

        // when
        try generateProjectAndTargetsConfigs(project: project, path: dir.path)

        // then
        let buildConfigurations = pbxTarget.buildConfigurationList?.buildConfigurations
        let expected = ["ProjectDebug", "TargetDebug"].map { (name: $0, ["SWIFT_VERSION": Constants.swiftVersion]) }
        assertBuildSettings(buildConfigurations, expected)
    }

    func test_generateTargetConfig_whenCustomBuildConfiguration() throws {
        let dir = try TemporaryDirectory(removeTreeOnDeinit: true)
        let xcconfigsDir = dir.path.appending(component: "xcconfigs")
        let configurations: [BuildConfiguration: Configuration?] = [
            BuildConfiguration(name: "Alpha", variant: .debug): Configuration(settings: ["Debug": "Debug"],
                                                                              xcconfig: xcconfigsDir.appending(component: "alpha.xcconfig")),
            BuildConfiguration(name: "AppStore", variant: .release): Configuration(settings: ["Release": "Release"],
                                                                                   xcconfig: xcconfigsDir.appending(component: "appstore.xcconfig"))]
        _ = try generateTargetConfig(configurations: configurations)

        let configurationList = pbxproj.configurationLists.first
        let buildConfigurationNames = configurationList?.buildConfigurations.map { $0.name }

        XCTAssertEqual(pbxproj.configurationLists.count, 1)
        XCTAssertEqual(buildConfigurationNames, ["Alpha", "AppStore", "Debug", "Release"])
    }

    func test_generateTargetConfig() throws {
        try generateTargetConfig()
        let configurationList = pbxTarget.buildConfigurationList
        let debugConfig = try configurationList?.configuration(name: "Debug")
        let releaseConfig = try configurationList?.configuration(name: "Release")

        func assert(config: XCBuildConfiguration?) {
            XCTAssertEqual(config?.buildSettings["Base"] as? String, "Base")
            XCTAssertEqual(config?.buildSettings["INFOPLIST_FILE"] as? String, "$(SRCROOT)/Info.plist")
            XCTAssertEqual(config?.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String, "com.test.bundle_id")
            XCTAssertEqual(config?.buildSettings["CODE_SIGN_ENTITLEMENTS"] as? String, "$(SRCROOT)/Test.entitlements")
            XCTAssertEqual(config?.buildSettings["SWIFT_VERSION"] as? String, Constants.swiftVersion)

            let xcconfig: PBXFileReference? = config?.baseConfiguration
            XCTAssertEqual(xcconfig?.path, "\(config!.name.lowercased()).xcconfig")
        }

        assert(config: debugConfig)
        assert(config: releaseConfig)
    }

    // MARK: - Helpers

    private func generateProjectConfig(config _: BuildConfiguration) throws {
        let dir = try TemporaryDirectory(removeTreeOnDeinit: true)
        let xcconfigsDir = dir.path.appending(component: "xcconfigs")
        try fileHandler.createFolder(xcconfigsDir)
        try "".write(to: xcconfigsDir.appending(component: "debug.xcconfig").url, atomically: true, encoding: .utf8)
        try "".write(to: xcconfigsDir.appending(component: "release.xcconfig").url, atomically: true, encoding: .utf8)
        let configurations: [BuildConfiguration: Configuration?] = [
            .debug: Configuration(settings: ["Debug": "Debug"],
                                  xcconfig: xcconfigsDir.appending(component: "debug.xcconfig")),
            .release: Configuration(settings: ["Release": "Release"],
                                    xcconfig: xcconfigsDir.appending(component: "release.xcconfig"))]
        let project = Project(path: dir.path,
                              name: "Test",
                              settings: Settings(base: ["Base": "Base"], configurations: configurations),
                              targets: [])
        let fileElements = ProjectFileElements()
        let options = GenerationOptions()
        _ = try subject.generateProjectConfig(project: project,
                                              pbxproj: pbxproj,
                                              fileElements: fileElements,
                                              options: options)
    }

    private func generateTargetConfig() throws {
        let dir = try TemporaryDirectory(removeTreeOnDeinit: true)
        let xcconfigsDir = dir.path.appending(component: "xcconfigs")
        try fileHandler.createFolder(xcconfigsDir)
        try "".write(to: xcconfigsDir.appending(component: "debug.xcconfig").url, atomically: true, encoding: .utf8)
        try "".write(to: xcconfigsDir.appending(component: "release.xcconfig").url, atomically: true, encoding: .utf8)
        let configurations: [BuildConfiguration: Configuration?] = [
            .debug: Configuration(settings: ["Debug": "Debug"],
                                  xcconfig: xcconfigsDir.appending(component: "debug.xcconfig")),
            .release: Configuration(settings: ["Release": "Release"],
                                    xcconfig: xcconfigsDir.appending(component: "release.xcconfig"))]

        try generateTargetConfig(configurations: configurations, tempDir: dir)
    }

    private func generateTargetConfig(configurations: [BuildConfiguration: Configuration?],
                                      tempDir: TemporaryDirectory? = nil) throws {
        let dir = try tempDir ?? TemporaryDirectory(removeTreeOnDeinit: true)
        let target = Target.test(name: "Test",
                                 settings: Settings(base: ["Base": "Base"], configurations: configurations))
        let project = Project(path: dir.path,
                              name: "Test",
                              settings: Settings.default,
                              targets: [target])
        let fileElements = ProjectFileElements()
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj, sourceRootPath: dir.path)
        let graph = Graph.test()
        fileElements.generateProjectFiles(project: project,
                                          graph: graph,
                                          groups: groups,
                                          pbxproj: pbxproj,
                                          sourceRootPath: project.path)
        let options = GenerationOptions()
        _ = try subject.generateTargetConfig(target,
                                             pbxTarget: pbxTarget,
                                             pbxproj: pbxproj,
                                             projectSettings: project.settings,
                                             fileElements: fileElements,
                                             options: options,
                                             sourceRootPath: AbsolutePath("/"))
    }

    private func generateTargetConfig(for target: Target) throws -> XCConfigurationList? {
        let project = Project.test(targets: [target])
        let fileElements = ProjectFileElements()
        let groups = ProjectGroups.generate(project: project,
                                            pbxproj: pbxproj,
                                            sourceRootPath: project.path)
        let graph = Graph.test()
        fileElements.generateProjectFiles(project: project,
                                          graph: graph,
                                          groups: groups,
                                          pbxproj: pbxproj,
                                          sourceRootPath: project.path)
        let options = GenerationOptions()
        try subject.generateTargetConfig(target,
                                         pbxTarget: pbxTarget,
                                         pbxproj: pbxproj,
                                         projectSettings: project.settings,
                                         fileElements: fileElements,
                                         options: options,
                                         sourceRootPath: project.path)
        return pbxTarget.buildConfigurationList
    }

    private func generateProjectAndTargetsConfigs(project: Project, path: AbsolutePath) throws {
        let fileElements = ProjectFileElements()
        let options = GenerationOptions()
        let groups = ProjectGroups.generate(project: project, pbxproj: pbxproj, sourceRootPath: path)
        let graph = Graph.test()
        fileElements.generateProjectFiles(project: project,
                                          graph: graph,
                                          groups: groups,
                                          pbxproj: pbxproj,
                                          sourceRootPath: path)

        _ = try subject.generateProjectConfig(project: project,
                                              pbxproj: pbxproj,
                                              fileElements: fileElements,
                                              options: options)

        try project.targets.forEach { target in
            try subject.generateTargetConfig(target,
                                             pbxTarget: pbxTarget,
                                             pbxproj: pbxproj,
                                             projectSettings: project.settings,
                                             fileElements: fileElements,
                                             options: options,
                                             sourceRootPath: project.path)
        }
    }

    private func createTarget(name: String = "Target1", settings: Settings?) -> Target {
        return Target(name: name,
                      platform: .iOS,
                      product: .framework,
                      bundleId: "target.bundle.id",
                      infoPlist: AbsolutePath("/path/to/Info.plist"),
                      settings: settings)
    }

    private func createProject(name: String = "Project1",
                               configurations: [BuildConfiguration: Configuration?],
                               targets: [Target] = [],
                               path: AbsolutePath) -> Project {
        return Project(path: path,
                       name: "Project1",
                       settings: Settings(base: ["BaseKey": "BaseValue"], configurations: configurations),
                       targets: targets)
    }

    func assertBuildSettings(_ actual: xcodeproj.XCBuildConfiguration?,
                             _ expected: (name: String, settings: [String: String]),
                             file: StaticString = #file,
                             line: UInt = #line) {
        XCTAssertEqual(actual?.name, expected.name, file: file, line: line)
        expected.settings.forEach {
            XCTAssertEqual(actual?.buildSettings[$0.key] as? String, $0.value, file: file, line: line)
        }
    }

    func assertBuildSettings(_ actual: [xcodeproj.XCBuildConfiguration]?,
                             _ expected: [(name: String, settings: [String: String])],
                             file: StaticString = #file,
                             line: UInt = #line) {
        XCTAssertEqual(actual?.count, expected.count,
                       "build configurations count mismatch",
                       file: file,
                       line: line)
        guard actual?.count == expected.count else { return }
        expected.enumerated().forEach { (_, element) in
            assertBuildSettings(actual?.first(where: { $0.name == element.name }),
                                element,
                                file: file,
                                line: line)
        }
    }
}
