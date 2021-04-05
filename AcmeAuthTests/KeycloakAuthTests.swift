// AcmeAuthTests/KeycloakAuthTest.swift
// 

import XCTest
import Combine
import SwiftSoup
import CryptoKit

@testable import AcmeAuth


@available(iOS 14.0, *)
class KeycloakAuthTests: XCTestCase {
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
    
    func parseErrorMessage(from data: Data) -> String {
        do {
            let doc: Document = try SwiftSoup.parse(String(decoding: data, as: UTF8.self))
            return try doc.getElementById("kc-error-message")?.text() ?? "Unknown Keycloak error"
        } catch {
            return "Unknown Keycloak error"
        }
    }
    
    func testKeycloakLogin() {
        let expectation = XCTestExpectation(description: "Login finished without errors")
        let loginSession = KeycloakLoginSession()
        let codeVerifier = self.createCodeVerifier()
        let codeChallenge = self.codeChallenge(for: codeVerifier)
        let request = PKCERequest(
            endpoint: "https://id.acme.spilikin.dev/auth/realms/healthid/protocol/openid-connect/auth",
            codeChallenge: codeChallenge,
            clientId: "aua.spilikin.dev",
            redirectUri: "https://aua.spilikin.dev/login")
        
        self.cancellable = loginSession.authenticate(request: request)
            .sink(receiveCompletion: { completition in
                switch(completition) {
                case .failure:
                    print("FAILURE")
                    print(completition)
                case .finished:
                    break
                }
            }, receiveValue: { url in
                print (url)
                var request = URLRequest(url: URL(string: "https://id.acme.spilikin.dev/auth/realms/healthid/protocol/openid-connect/token")!)
                request.httpMethod = "POST"

                                            /*
                                            client_id: "aua.spilikin.dev",
                                            code_verifier: ""+window.sessionStorage.getItem("code_verifier"),
                                            grant_type: "authorization_code",
                                            redirect_uri: location.href.replace(location.search, ''),
                                            code: code

                                            */
                                            
                request.httpBody = "client_id=aua.spilikin.dev".data(using: .utf8)
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    guard error == nil && data != nil else {
                        print(error)
                        return
                    }
                    print(data)
                    expectation.fulfill()
                }
                task.resume()


            })
            
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testSimpleRequest() throws {
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

        
        let delegate = KeycloakLoginSession()
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: OperationQueue.main)
                
        let expectation = XCTestExpectation(description: "Retrieve data from IdP")

        print(comps.url!.description)
        
        self.cancellable = session.dataTaskPublisher(for: comps.url!)
            .mapError { $0 as Error }
            .tryMap { output -> Data in
                let task = session.dataTask(with: URL(string: "http://aua.spilikin.dev/")!)
                task.resume()

                let httpResponse = output.response as! HTTPURLResponse;
                if httpResponse.statusCode >= 400 {
                    throw KeycloakError.AuthRequestError(reason: self.parseErrorMessage(from: output.data))
                }
                return output.data
            }
            .eraseToAnyPublisher()
            .sink(receiveCompletion: { completition in
                switch(completition) {
                case .failure:
                    print("???!!!!!!!!!")
                    print(completition)
                    print("???!!!!!!!!!")
                case .finished:
                    break
                }
            }, receiveValue: { data in
                expectation.fulfill()
            })

        wait(for: [expectation], timeout: 3.0)
    }
}
