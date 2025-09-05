import XCTest
@testable import shigodeki

@MainActor
final class AIStateManagerTests: XCTestCase {
    
    private var sut: AIStateManager!
    private var mockKeychainManager: MockKeychainManager!
    
    override func setUp() {
        super.setUp()
        mockKeychainManager = MockKeychainManager()
        // AIStateManager will be created once it exists
        // sut = AIStateManager(keychainManager: mockKeychainManager)
    }
    
    override func tearDown() {
        sut = nil
        mockKeychainManager = nil
        super.tearDown()
    }
    
    // MARK: - Red Phase Tests (Should Fail Initially)
    
    func test_initialState_shouldBeIdle() {
        // Given: New AIStateManager instance
        // When: No action taken
        // Then: State should be idle
        XCTFail("AIStateManager not implemented yet")
        
        // This test will pass when implemented:
        // XCTAssertEqual(sut.state, .idle)
    }
    
    func test_checkConfiguration_whenNoAPIKeysConfigured_shouldShowNeedsConfiguration() {
        // Given: No API keys configured
        mockKeychainManager.configuredProviders = []
        
        // When: checkConfiguration is called
        // sut.checkConfiguration()
        
        // Then: State should be needsConfiguration
        XCTFail("AIStateManager.checkConfiguration not implemented yet")
        
        // This test will pass when implemented:
        // if case .needsConfiguration = sut.state {
        //     XCTAssert(true)
        // } else {
        //     XCTFail("Expected needsConfiguration state")
        // }
    }
    
    func test_checkConfiguration_whenAPIKeysConfigured_shouldShowReady() {
        // Given: API keys are configured
        mockKeychainManager.configuredProviders = [.openAI]
        
        // When: checkConfiguration is called
        // sut.checkConfiguration()
        
        // Then: State should be ready
        XCTFail("AIStateManager.checkConfiguration not implemented yet")
        
        // This test will pass when implemented:
        // XCTAssertEqual(sut.state, .ready)
    }
    
    func test_generateDetail_whenNotReady_shouldNotChangeState() {
        // Given: State is not ready
        // sut.state = .idle
        
        // When: generateDetail is called
        // sut.generateDetail(for: mockTask)
        
        // Then: State should remain unchanged
        XCTFail("AIStateManager.generateDetail not implemented yet")
        
        // This test will pass when implemented:
        // XCTAssertEqual(sut.state, .idle)
    }
    
    func test_generateDetail_whenReady_shouldShowLoading() {
        // Given: State is ready
        // sut.state = .ready
        
        // When: generateDetail is called
        // sut.generateDetail(for: mockTask)
        
        // Then: State should be loading
        XCTFail("AIStateManager.generateDetail not implemented yet")
        
        // This test will pass when implemented:
        // if case .loading(let message) = sut.state {
        //     XCTAssertFalse(message.isEmpty)
        // } else {
        //     XCTFail("Expected loading state")
        // }
    }
    
    func test_applyResult_shouldReturnToReady() {
        // Given: State is suggestion
        // sut.state = .suggestion(result: mockResult)
        
        // When: applyResult is called
        // sut.applyResult("Applied content")
        
        // Then: State should be ready
        XCTFail("AIStateManager.applyResult not implemented yet")
        
        // This test will pass when implemented:
        // XCTAssertEqual(sut.state, .ready)
    }
    
    func test_dismissResult_shouldReturnToReady() {
        // Given: State is suggestion
        // sut.state = .suggestion(result: mockResult)
        
        // When: dismissResult is called
        // sut.dismissResult()
        
        // Then: State should be ready
        XCTFail("AIStateManager.dismissResult not implemented yet")
        
        // This test will pass when implemented:
        // XCTAssertEqual(sut.state, .ready)
    }
    
    func test_retry_shouldCheckConfiguration() {
        // Given: State is error
        // sut.state = .error(message: "Test error")
        
        // When: retry is called
        // sut.retry()
        
        // Then: Should check configuration (state changes from error)
        XCTFail("AIStateManager.retry not implemented yet")
        
        // This test will pass when implemented:
        // XCTAssertNotEqual(sut.state, .error(message: "Test error"))
    }
}

// MARK: - Mock Classes

class MockKeychainManager {
    var configuredProviders: [KeychainManager.APIProvider] = []
    
    func getConfiguredProviders() -> [KeychainManager.APIProvider] {
        return configuredProviders
    }
}

// MARK: - Test Data

extension AIStateManagerTests {
    private var mockTask: ShigodekiTask {
        ShigodekiTask(
            title: "Test Task",
            description: "Test Description",
            assignedTo: nil,
            createdBy: "test-user",
            dueDate: nil,
            priority: .medium,
            listId: "test-list",
            phaseId: "test-phase", 
            projectId: "test-project",
            order: 0
        )
    }
    
    private var mockResult: AIDetailResult {
        AIDetailResult(content: "Mock AI generated content")
    }
}

// MARK: - Helper Types (Will be moved to actual implementation)

struct ConfigurationGuidance {
    let message: String
    let actionRequired: String
    
    static func createDefault() -> ConfigurationGuidance {
        return ConfigurationGuidance(
            message: "APIキーが設定されていません",
            actionRequired: "AI設定を開いてAPIキーを設定してください"
        )
    }
}

struct AIDetailResult {
    let content: String
}