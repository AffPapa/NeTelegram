import XCTest
@testable import NeTelegramCore

final class PhotoDownloadSlotPolicyTests: XCTestCase {
    func testCompletionReleasesSlotsAcrossChatsButKeepsOtherAccount() {
        let account = AccountUUID()
        let otherAccount = AccountUUID()
        let firstChat = ConversationKey(account: account, chatID: 10)
        let secondChat = ConversationKey(account: account, chatID: 20)
        let other = ConversationKey(account: otherAccount, chatID: 10)
        var active: [ConversationKey: Set<Int32>] = [
            firstChat: [7, 8],
            secondChat: [7],
            other: [7],
        ]

        let released = PhotoDownloadSlotPolicy.releaseCompleted(account: account, fileID: 7, from: &active)

        XCTAssertEqual(released, [firstChat, secondChat])
        XCTAssertEqual(active[firstChat], [8])
        XCTAssertNil(active[secondChat])
        XCTAssertEqual(active[other], [7])
    }

    func testRepeatedCompletionIsHarmless() {
        let account = AccountUUID()
        let conversation = ConversationKey(account: account, chatID: 10)
        var active: [ConversationKey: Set<Int32>] = [conversation: [7]]

        XCTAssertEqual(PhotoDownloadSlotPolicy.releaseCompleted(account: account, fileID: 7, from: &active), [conversation])
        XCTAssertTrue(PhotoDownloadSlotPolicy.releaseCompleted(account: account, fileID: 7, from: &active).isEmpty)
        XCTAssertTrue(active.isEmpty)
    }
}
