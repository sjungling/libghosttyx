import XCTest
@testable import libghosttyx

final class ConfigurationTests: XCTestCase {
    func testDefaultConfiguration() {
        let config = TerminalConfiguration()
        XCTAssertNil(config.fontFamily)
        XCTAssertEqual(config.fontSize, 0)
        XCTAssertNil(config.customConfigPath)
        XCTAssertNil(config.workingDirectory)
        XCTAssertNil(config.command)
        XCTAssertTrue(config.environmentVariables.isEmpty)
    }

    func testCustomConfiguration() {
        let config = TerminalConfiguration(
            fontFamily: "JetBrains Mono",
            fontSize: 14,
            workingDirectory: "/tmp",
            command: "/bin/zsh",
            environmentVariables: [("TERM", "xterm-256color")]
        )

        XCTAssertEqual(config.fontFamily, "JetBrains Mono")
        XCTAssertEqual(config.fontSize, 14)
        XCTAssertEqual(config.workingDirectory, "/tmp")
        XCTAssertEqual(config.command, "/bin/zsh")
        XCTAssertEqual(config.environmentVariables.count, 1)
        XCTAssertEqual(config.environmentVariables[0].key, "TERM")
        XCTAssertEqual(config.environmentVariables[0].value, "xterm-256color")
    }
}
