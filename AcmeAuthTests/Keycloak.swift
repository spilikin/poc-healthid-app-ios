// AcmeAuth/Keycloak.swift
// 


import Foundation
import Combine
import SwiftSoup

struct PKCERequest {
    let endpoint: String
    let codeChallenge: String
    let clientId: String
    let redirectUri: String
}

struct KeycloakUsernameForm {
    let action: URL
}

struct KeycloakChallengeForm {
    let action: URL
    let challenge: String
}

enum KeycloakError: Error {
    case AuthRequestError(reason: String)
    case FormParseError
    case UsernameSubmitError
    case ChallengeSubmitError
}


@available(iOS 14.0, *)
class KeycloakLoginSession: NSObject, URLSessionTaskDelegate {
    var username = "user1"
    var session: URLSession?
    
    func parseErrorMessage(from data: Data) -> String {
        do {
            let doc: Document = try SwiftSoup.parse(String(decoding: data, as: UTF8.self))
            return try doc.getElementById("kc-error-message")?.text() ?? "Unknown Keycloak error"
        } catch {
            return "Unknown Keycloak error"
        }
    }
    
    func parseData(_ data: Data) throws -> Document? {
        do {
            return try SwiftSoup.parse(String(decoding: data, as: UTF8.self))
        } catch {
            throw KeycloakError.FormParseError
        }

    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // if error occured ahndle it and prevent redirect
        completionHandler(nil)
    }
    
    /*
     1. set original code request to keycloak
     1.1. keycloak returns username form
     2. submit the username to the form's action URL using POST
     2.1. keycloak returns challenge form (totp)
     3. submit the (signed) challenge to challenge form's action URL using POST
     3.1. keycloak send redirect to the client
     4. intercept the redirect in delegate
     */
    func authenticate(request: PKCERequest) -> AnyPublisher<URL, Error>  {
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.current)
        let step1 = requestCode(request: request)
        let step2 = submitUsername(previousStep: step1, username: "user1")
        let step3 = submitChallenge(previousStep: step2)
        return step3
    }
    
    func requestCode(request: PKCERequest) -> AnyPublisher<KeycloakUsernameForm, Error> {
        var comps = URLComponents(string: request.endpoint)!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: request.clientId),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        
        comps.queryItems?.append(URLQueryItem(name: "redirect_uri", value: request.redirectUri))
        comps.queryItems?.append(URLQueryItem(name: "code_challenge", value: request.codeChallenge))

        NSLog("Performing the PKCE request to Keycloak: \(comps.url!.description)")

        return self.session!.dataTaskPublisher(for: comps.url!)
            .mapError { $0 as Error }
            .tryMap { output -> KeycloakUsernameForm in
                let task = self.session!.dataTask(with: URL(string: "http://aua.spilikin.dev/")!)
                task.resume()

                let httpResponse = output.response as! HTTPURLResponse;
                if httpResponse.statusCode >= 400 {
                    throw KeycloakError.AuthRequestError(reason: self.parseErrorMessage(from: output.data))
                }
                                
                do {
                    let loginPage = try self.parseData(output.data)
                    let formElement = try loginPage?.getElementById("kc-form-login")
                    let formAction = try formElement?.attr("action")
                    let loginForm = KeycloakUsernameForm(action: URL(string: formAction!)!)
                    return loginForm
                } catch {
                    throw KeycloakError.FormParseError
                }
                
            }.eraseToAnyPublisher()
    }
    
    func submitUsername(previousStep: AnyPublisher<KeycloakUsernameForm, Error>, username: String) -> AnyPublisher<KeycloakChallengeForm, Error> {
        return previousStep.flatMap { usernameForm -> AnyPublisher<KeycloakChallengeForm, Error> in
            var request = URLRequest(url: usernameForm.action)
            request.httpMethod = "POST"

            request.httpBody = "username=\(username)".data(using: .utf8)
            return self.session!.dataTaskPublisher(for: request)
                .mapError { $0 as Error}
                .tryMap { output in
                    guard let response = output.response as? HTTPURLResponse, response.statusCode == 200 else {
                        throw KeycloakError.UsernameSubmitError
                    }
                    do {
                        let challengePage = try self.parseData(output.data)
                        let formElement = try challengePage?.getElementById("kc-totp-login-form")
                        let formAction = try formElement?.attr("action")
                        let challengeForm = KeycloakChallengeForm(action: URL(string: formAction!)!, challenge: "fake")
                        return challengeForm
                    } catch {
                        throw KeycloakError.FormParseError
                    }
                }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

    func submitChallenge(previousStep: AnyPublisher<KeycloakChallengeForm, Error>) -> AnyPublisher<URL, Error> {
        return previousStep.flatMap { challengeForm -> AnyPublisher<URL, Error> in
            var request = URLRequest(url: challengeForm.action)
            request.httpMethod = "POST"

            request.httpBody = "challenge_data=\(challengeForm.challenge)".data(using: .utf8)
            return self.session!.dataTaskPublisher(for: request)
                .mapError { $0 as Error}
                .tryMap { output in
                    guard let response = output.response as? HTTPURLResponse, response.statusCode == 302 else {
                        throw KeycloakError.ChallengeSubmitError
                    }
                    return URL(string: response.value(forHTTPHeaderField: "Location")!)!
                }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

}
