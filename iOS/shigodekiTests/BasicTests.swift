import XCTest

final class BasicTests: XCTestCase {
    
    func testBasicMath() {
        // Very simple test to verify test infrastructure works
        let result = 2 + 2
        XCTAssertEqual(result, 4, "Basic math should work")
    }
    
    func testStringComparison() {
        let greeting = "Hello"
        XCTAssertEqual(greeting, "Hello", "String comparison should work")
    }
}