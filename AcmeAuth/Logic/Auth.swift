// AcmeAuth/Auth.swift
// 


import Foundation
import Combine
import JOSESwift
import SwiftSoup

struct PKCERequest {
    let endpoint: String
    let codeChallenge: String
    let clientId: String
    let redirectUri: String
}

struct KeycloakChallengeForm {
    let action: URL
    let challenge: String
}

enum AuthError: Error {
    case serverError
    case clientError(reason: String)
    case localSignatureError
    case formParseError
    case usernameSubmitError
    case challengeSubmitError
}

struct Challenge: Codable {
    let acct: String
    let nonce: String
}

struct SignedChallenge: Codable {
    let acct: String
    let nonce: String
    let signed_nonce: String
}

struct AuthenticationCode: Decodable {
    let code: String
}

enum AuthRequestError: Error {
    case NoClientId
    case NoRedirectUri
}

class AuthRequest {
    let url: URL
    let redirectURI: String
    let codeChallenge: String
    let isRemote: Bool = false
    let acct: String = "user1"
    let clientMetadata: ClientMetadata?
    
    static func param(from components: URLComponents?, withName: String) -> String? {
        return components?.queryItems?.first(where: { $0.name.lowercased() == withName})?.value
    }
    
    init?(_ url: URL) throws {
        self.url = url

        NSLog(url.absoluteString)

        let comps = URLComponents(string: url.description)
        
        guard let clientId = AuthRequest.param(from: comps, withName: "client_id") else {
            // client_id ist not specified - return with error
            throw AuthRequestError.NoClientId
        }
        
        self.clientMetadata = FederationQuery().clientMetadata(clientId)
                
        guard let redirectURI = AuthRequest.param(from: comps, withName: "redirect_uri") else {
            throw AuthRequestError.NoRedirectUri
        }
                
        self.redirectURI = redirectURI
        
        guard let codeChallenge = AuthRequest.param(from: comps, withName: "code_challenge") else {
            throw AuthRequestError.NoRedirectUri
        }
                
        self.codeChallenge = codeChallenge

    }
    
}

class AuthManager: NSObject, URLSessionTaskDelegate {
    var settings = AppSettings()
    var keyManager = KeyManager()
    var username = "user1"
    var session: URLSession?

    private func signChallenge(_ challenge: Challenge) throws -> SignedChallenge {
        let keyPair = try keyManager.loadKey()
        let header = JWSHeader(algorithm: .ES256)
        let payload = Payload(try JSONEncoder().encode(["nonce": challenge.nonce]))
        let signer = Signer(signingAlgorithm: .ES256, privateKey: keyPair.signingKey)!
        let jws = try JWS(header: header, payload: payload, signer: signer)
        let signedChallenge = SignedChallenge(
            acct: challenge.acct,
            nonce: challenge.nonce,
            signed_nonce: jws.compactSerializedString
        )
        return signedChallenge
    }

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
            throw AuthError.formParseError
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
     1.1. keycloak returns challenge form (totp)
     2. submit the (signed) challenge to challenge form's action URL using POST
     2.1. keycloak send redirect to the client
     3. intercept the redirect in delegate
     */
    func authenticate(_ authRequest: AuthRequest) -> AnyPublisher<URL, Error>  {
        let pkceRequest = PKCERequest(
            endpoint: settings.authEndpoint.description,
            codeChallenge: authRequest.codeChallenge,
            clientId: authRequest.clientMetadata!.id,
            redirectUri: authRequest.redirectURI)
        
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.current)
        let step1 = requestCode(request: pkceRequest)
        let step2 = submitChallenge(previousStep: step1, username: "user1")
        return step2
    }
    
    func requestCode(request: PKCERequest) -> AnyPublisher<KeycloakChallengeForm, Error> {
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
            .tryMap { output -> KeycloakChallengeForm in
                let task = self.session!.dataTask(with: URL(string: "http://aua.spilikin.dev/")!)
                task.resume()

                let httpResponse = output.response as! HTTPURLResponse;
                if httpResponse.statusCode >= 400 {
                    throw AuthError.clientError(reason: self.parseErrorMessage(from: output.data))
                }
                                
                do {
                    let challengePage = try self.parseData(output.data)
                    let formElement = try challengePage?.getElementById("kc-totp-login-form")
                    let formAction = try formElement?.attr("action")
                    let challengeForm = KeycloakChallengeForm(action: URL(string: formAction!)!, challenge: "fake")
                    return challengeForm
                } catch {
                    throw AuthError.formParseError
                }
                
            }.eraseToAnyPublisher()
    }
    
    func submitChallenge(previousStep: AnyPublisher<KeycloakChallengeForm, Error>, username: String) -> AnyPublisher<URL, Error> {
        return previousStep.flatMap { challengeForm -> AnyPublisher<URL, Error> in
            var request = URLRequest(url: challengeForm.action)
            request.httpMethod = "POST"

            request.httpBody = "challenge_data=\(challengeForm.challenge)&username=\(username)".data(using: .utf8)
            return self.session!.dataTaskPublisher(for: request)
                .mapError { $0 as Error}
                .tryMap { output in
                    guard let response = output.response as? HTTPURLResponse, response.statusCode == 302 else {
                        throw AuthError.challengeSubmitError
                    }
                    return URL(string: response.value(forHTTPHeaderField: "Location")!)!
                }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

}

