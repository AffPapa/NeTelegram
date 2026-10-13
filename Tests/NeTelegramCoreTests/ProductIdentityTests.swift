import Testing
@testable import NeTelegramCore

struct ProductIdentityTests {
    @Test func publicDisplayNameDoesNotContainTelegramAndKeepsRepositoryCodename() {
        #expect(ProductIdentity.displayName == "Neridian")
        #expect(!ProductIdentity.displayName.localizedCaseInsensitiveContains("telegram"))
        #expect(ProductIdentity.repositoryCodename == "NeTelegram")
    }
}
