import XCTest
@testable import NeTelegramCore

final class ChatDisplayTitlePolicyTests: XCTestCase {
    func testMissingTitleUsesHonestFallbackWithoutInternalID() {
        XCTAssertEqual(ChatDisplayTitlePolicy.resolve(nil), "Чат без названия")
        XCTAssertEqual(ChatDisplayTitlePolicy.resolve("  \n "), "Чат без названия")
        XCTAssertFalse(ChatDisplayTitlePolicy.unavailableTitle.contains("123456"))
    }

    func testServerTitleIsTrimmedAndPreserved() {
        XCTAssertEqual(ChatDisplayTitlePolicy.resolve("  Рабочая группа  "), "Рабочая группа")
    }
}
