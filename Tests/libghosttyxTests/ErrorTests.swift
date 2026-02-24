import XCTest
@testable import libghosttyx

final class ErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let errors: [GhosttyError] = [
            .initializationFailed,
            .appCreationFailed,
            .configCreationFailed,
            .surfaceCreationFailed,
            .alreadyInitialized,
            .notInitialized,
            .configKeyNotFound("test-key"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }

        // Specific description check
        let keyError = GhosttyError.configKeyNotFound("font-size")
        XCTAssertTrue(keyError.errorDescription!.contains("font-size"))
    }
}
