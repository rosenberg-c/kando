import Testing
@testable import TodoMacOS

struct RuntimeFlagsTests {
    @Test func shouldDisableKeychainWhenExplicitFlagSet() {
        let env = ["TODO_DISABLE_KEYCHAIN": "1"]
        #expect(RuntimeFlags.shouldDisableKeychain(environment: env, isXCTestRuntime: false))
    }

    @Test func shouldDisableKeychainWhenNotInTestOrFlagMode() {
        #expect(RuntimeFlags.shouldDisableKeychain(environment: [:], isXCTestRuntime: false) == false)
    }

    @Test func shouldUseMockBoardWhenUiTestModeEnabled() {
        let env = ["TODO_UITEST_MODE": "1"]
        #expect(RuntimeFlags.shouldUseMockBoard(environment: env, isXCTestRuntime: false))
    }

    @Test func shouldUseMockBoardWhenNotInTestOrFlagMode() {
        #expect(RuntimeFlags.shouldUseMockBoard(environment: [:], isXCTestRuntime: false) == false)
    }
}
