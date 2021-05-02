// AcmeAuthTests/AcmeAuthTests.swift
// 


import XCTest
@testable import AcmeAuth
import CryptoKit
import Combine

class AcmeAuthTests: XCTestCase {
    private var cancellable: AnyCancellable?

    func randomString(length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    func createCodeVerifier() -> String {
        return randomString(length: 64)
    }
    
    func codeChallenge(for code: String) -> String {
        return SHA256.hash(data: code.data(using: .utf8)!).compactMap { String(format: "%02x", $0) }.joined()
    }

    func testAuth() throws {
        let expectation = XCTestExpectation(description: "Login finished without errors")

        var comps = URLComponents(string: "https://id.acme.spilikin.dev/auth/realms/healthid/protocol/openid-connect/auth")!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: "aua.spilikin.dev"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        
        comps.queryItems?.append(URLQueryItem(name: "redirect_uri", value: "https://aua.spilikin.dev/login"))
        let codeVerifier = self.createCodeVerifier()
        let codeChallenge = self.codeChallenge(for: codeVerifier)

        comps.queryItems?.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
        comps.queryItems?.append(URLQueryItem(name: "scope", value: "openid"))

        let authManager = AuthManager()
        guard let authRequest = try AuthRequest(comps.url!) else {
            XCTFail("Bad URL")
            return
        }
        
        self.cancellable = authManager.authenticate(authRequest)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print(error)
                }
            }, receiveValue: { url in
                print(url)
                expectation.fulfill()
            })
        
        wait(for: [expectation], timeout: 3.0)
    }


}
