import XCTest
@testable import libghosttyx

final class ResourceTests: XCTestCase {
    func testTerminfoFileExists() throws {
        let bundleURL = try XCTUnwrap(
            Bundle.module.resourceURL,
            "Bundle.module.resourceURL is nil — resources not declared in Package.swift"
        )
        let terminfo = bundleURL.appendingPathComponent("terminfo/78/xterm-ghostty")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: terminfo.path),
            "xterm-ghostty terminfo not found at \(terminfo.path)"
        )
    }

    func testGhosttyResourceDirectoryExists() throws {
        let bundleURL = try XCTUnwrap(Bundle.module.resourceURL)
        let ghosttyDir = bundleURL.appendingPathComponent("ghostty")
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: ghosttyDir.path, isDirectory: &isDir)
        XCTAssertTrue(exists && isDir.boolValue, "ghostty dir not found at \(ghosttyDir.path)")
    }
}
