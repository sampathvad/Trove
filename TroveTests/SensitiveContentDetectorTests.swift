import XCTest
@testable import Trove

final class SensitiveContentDetectorTests: XCTestCase {

    // MARK: - Credit cards (Luhn)
    func testValidVisa()        { XCTAssertTrue(SensitiveContentDetector.matchesCreditCard("4532015112830366")) }
    func testValidMastercard()  { XCTAssertTrue(SensitiveContentDetector.matchesCreditCard("5425233430109903")) }
    func testInvalidLuhn()      { XCTAssertFalse(SensitiveContentDetector.matchesCreditCard("1234567890123456")) }
    func testTooShort()         { XCTAssertFalse(SensitiveContentDetector.matchesCreditCard("123456789012")) }

    // MARK: - SSN
    func testValidSSN()   { XCTAssertTrue(SensitiveContentDetector.matchesSSN("123-45-6789")) }
    func testInvalidSSN() { XCTAssertFalse(SensitiveContentDetector.matchesSSN("123-456-789")) }
    func testNoSSN()      { XCTAssertFalse(SensitiveContentDetector.matchesSSN("Hello world")) }

    // MARK: - API keys
    func testOpenAIKey()    { XCTAssertTrue(SensitiveContentDetector.matchesAPIKey("sk-abc123def456ghi789jkl")) }
    func testGitHubPAT()    { XCTAssertTrue(SensitiveContentDetector.matchesAPIKey("ghp_16C7e42F292c6912E169643f1757EB3E2a")) }
    func testSlackToken()   { XCTAssertTrue(SensitiveContentDetector.matchesAPIKey("xoxb-123456789-abcdefghij")) }
    func testAWSKey()       { XCTAssertTrue(SensitiveContentDetector.matchesAPIKey("AKIAIOSFODNN7EXAMPLE")) }
    func testStripeSecret() { XCTAssertTrue(SensitiveContentDetector.matchesAPIKey("sk_live_abcdef1234567890")) }
    func testStripeTest()   { XCTAssertTrue(SensitiveContentDetector.matchesAPIKey("sk_test_abcdef1234567890")) }
    func testGoogleKey()    { XCTAssertTrue(SensitiveContentDetector.matchesAPIKey("AIzaFAKEKEY_FOR_TESTING_PURPOSES_ONLY__")) }
    func testNormalText()   { XCTAssertFalse(SensitiveContentDetector.matchesAPIKey("Hello world")) }
    func testURL()          { XCTAssertFalse(SensitiveContentDetector.matchesAPIKey("https://example.com")) }

    // MARK: - Private keys
    func testRSAPrivateKey() {
        let key = "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAK..."
        XCTAssertTrue(SensitiveContentDetector.matchesPrivateKey(key))
    }
    func testOpenSSHKey() {
        let key = "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC..."
        XCTAssertTrue(SensitiveContentDetector.matchesPrivateKey(key))
    }
    func testPublicKey() {
        let key = "-----BEGIN PUBLIC KEY-----\nMIIBIjANBg..."
        XCTAssertFalse(SensitiveContentDetector.matchesPrivateKey(key))
    }

    // MARK: - Password heuristic
    func testStrongPassword()    { XCTAssertTrue(SensitiveContentDetector.matchesPassword("Tr0ve@Secure!123")) }
    func testWeakPassword()      { XCTAssertFalse(SensitiveContentDetector.matchesPassword("hello")) }
    func testPasswordWithSpace() { XCTAssertFalse(SensitiveContentDetector.matchesPassword("hello world 123!")) }
    func testTooShort11Chars()   { XCTAssertFalse(SensitiveContentDetector.matchesPassword("Abc123!@#de")) }
    func testExactly12Chars()    { XCTAssertTrue(SensitiveContentDetector.matchesPassword("Abc123!@#def")) }

    // MARK: - High-entropy token
    func testHighEntropyToken() {
        XCTAssertTrue(SensitiveContentDetector.matchesHighEntropyToken(
            "a8f3d9e2b1c4f5a6d7e8f9a0b1c2d3e4f5a6b7c8"))
    }
    func testShortString() {
        XCTAssertFalse(SensitiveContentDetector.matchesHighEntropyToken("abc123"))
    }

    // MARK: - isSensitive (top-level)
    func testCreditCardSensitive()   { XCTAssertTrue(SensitiveContentDetector.isSensitive("4532015112830366")) }
    func testOpenAIKeySensitive()    { XCTAssertTrue(SensitiveContentDetector.isSensitive("sk-abcdefghijklmnopqrstuvwxyz")) }
    func testPlainTextNotSensitive() { XCTAssertFalse(SensitiveContentDetector.isSensitive("Hello, world!")) }
    func testURLNotSensitive()       { XCTAssertFalse(SensitiveContentDetector.isSensitive("https://example.com")) }
}
