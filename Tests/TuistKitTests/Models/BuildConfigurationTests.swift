import Foundation
@testable import TuistKit
import XCTest

final class BuildConfigurationTests: XCTestCase {
    func test_name_returnsTheRightValue_whenDebug() {
        XCTAssertEqual(BuildConfiguration.debug.name, "Debug")
    }

    func test_name_returnsTheRightValue_whenRelease() {
        XCTAssertEqual(BuildConfiguration.release.name, "Release")
    }

    func test_xcodeValue_returnsTheRightValue_whenDebug() {
        XCTAssertEqual(BuildConfiguration.debug.xcodeValue, "Debug")
    }

    func test_xcodeValue_returnsTheRightValue_whenRelease() {
        XCTAssertEqual(BuildConfiguration.release.xcodeValue, "Release")
    }
}
