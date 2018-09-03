import Foundation
@testable import TuistCoreTesting
@testable import TuistKit
import XCTest

final class SimCtlErrorTests: XCTestCase {
    func test_description() {
        XCTAssertEqual(SimCtlError.notFound.description, "simctl not found in the system")
        XCTAssertEqual(SimCtlError.invalidOutput.description, "Couldn't process the output from simctl")
    }

    func test_type() {
        XCTAssertEqual(SimCtlError.notFound.type, .abort)
        XCTAssertEqual(SimCtlError.invalidOutput.type, .abort)
    }
}

final class SimCtlTests: XCTestCase {
    var system: MockSystem!
    var subject: SimCtl!

    override func setUp() {
        super.setUp()
        system = MockSystem()
        subject = SimCtl(system: system)
    }

    func test_run_when_simctl_doesnt_exist() throws {
        system.stub(args: ["/usr/bin/xcrun", "-f", "simctl"],
                    stderror: "xcrun: error: unable to find utility \"simctl\", not a developer tool or in PATH",
                    stdout: nil,
                    exitstatus: 1)
        XCTAssertThrowsError(try subject.run([])) {
            XCTAssertEqual($0 as? SimCtlError, SimCtlError.notFound)
        }
    }

    func test_run() throws {
        let simctlPath = "simctl"
        system.stub(args: ["/usr/bin/xcrun", "-f", "simctl"],
                    stderror: nil,
                    stdout: simctlPath,
                    exitstatus: 0)
        system.stub(args: [simctlPath, "test"],
                    stderror: nil,
                    stdout: "works",
                    exitstatus: 0)

        XCTAssertEqual(try subject.run("test"), "works")
    }

    func test_runAndDecode() throws {
        let simctlPath = "simctl"
        system.stub(args: ["/usr/bin/xcrun", "-f", "simctl"],
                    stderror: nil,
                    stdout: simctlPath,
                    exitstatus: 0)
        system.stub(args: [simctlPath, "test"],
                    stderror: nil,
                    stdout: """
                    {
                      "name": "tuist"
                    }
                    """,
                    exitstatus: 0)
        XCTAssertEqual(try subject.runAndDecode("test", type: SimCtlTestStruct.self).name, "tuist")
    }
}

fileprivate struct SimCtlTestStruct: Decodable {
    let name: String
}
