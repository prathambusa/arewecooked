import XCTest
@testable import AnthropicUsage

final class KeychainManagerTests: XCTestCase {

    private let testKey = "sk-ant-admin01-TESTKEY123"

    override func tearDown() {
        super.tearDown()
        KeychainManager.delete()
    }

    func testSaveAndLoad() {
        _ = KeychainManager.save(key: testKey)
        XCTAssertEqual(KeychainManager.load(), testKey)
    }

    func testOverwrite() {
        _ = KeychainManager.save(key: testKey)
        let newKey = "sk-ant-admin01-NEWKEY456"
        _ = KeychainManager.save(key: newKey)
        XCTAssertEqual(KeychainManager.load(), newKey)
    }

    func testDelete() {
        _ = KeychainManager.save(key: testKey)
        KeychainManager.delete()
        XCTAssertNil(KeychainManager.load())
    }

    func testLoadWhenEmpty() {
        KeychainManager.delete()
        XCTAssertNil(KeychainManager.load())
    }

    func testTrimmingNotDoneByManager() {
        // Trimming is the caller's responsibility (SettingsView does it)
        let keyWithSpace = "  \(testKey)  "
        _ = KeychainManager.save(key: keyWithSpace)
        XCTAssertEqual(KeychainManager.load(), keyWithSpace)
    }
}
