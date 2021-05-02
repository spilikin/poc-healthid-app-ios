// AcmeAuth/Auth.swift
// 


import Foundation
import Combine
import JOSESwift

enum AuthError: Error {
    case localSignatureError
    case challengeResponseError
}

enum AuthRequestError: Error {
    case NoClientId
    case NoRedirectUri
    case NoCodeChallenge
    case NoScope
}

struct ChallengeResource: Codable {
    var endpoint: String
    var challenge: String?
    var device_code: String?
    var authenticated: Bool?
}

class AuthRequest {
    let url: URL
    let redirectURI: String
    let codeChallenge: String
    let codeChallengeMethod = "S256"
    let scope: String
    let authnChallenge: String?
    let clientMetadata: ClientMetadata?
    var username = "user1"
    
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
            throw AuthRequestError.NoCodeChallenge
        }
                
        self.codeChallenge = codeChallenge

        guard let scope = AuthRequest.param(from: comps, withName: "scope") else {
            throw AuthRequestError.NoScope
        }
        
        self.scope = scope
        
        self.authnChallenge = AuthRequest.param(from: comps, withName: "authn_challenge")

    }
    
}

class AuthManager: NSObject, URLSessionTaskDelegate {
    var settings = AppSettings()
    var keyManager = KeyManager()
    var username = "user1"
    var session: URLSession?

    /*
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
     */
        
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // if error occured ahndle it and prevent redirect
        completionHandler(nil)
    }
    
    func remoteAuthenticate(_ authRequest: AuthRequest) -> AnyPublisher<ChallengeResource, Error>  {
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.current)
        let step1 = requestChallenge(authRequest)
        let step2 = replaceChallenge(previousStep: step1, authRequest: authRequest)
        let step3 = submitChallengeResponse(previousStep: step2, authRequest: authRequest)
        return step3
    }
    
    func replaceChallenge(previousStep: AnyPublisher<ChallengeResource, Error>, authRequest: AuthRequest) -> AnyPublisher<ChallengeResource, Error> {
        return previousStep.flatMap { challenge -> AnyPublisher<ChallengeResource, Error> in
            return Future<ChallengeResource, Error> { promise in
                let newChallenge = ChallengeResource(endpoint: challenge.endpoint, challenge: authRequest.authnChallenge!)
                promise(.success(newChallenge))
            }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }
    
    func authenticate(_ authRequest: AuthRequest) -> AnyPublisher<URL, Error>  {
        self.session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.current)
        let step1 = requestChallenge(authRequest)
        let step2 = submitChallengeResponse(previousStep: step1, authRequest: authRequest)
        let step3 = finishAuthentication(previousStep: step2)
        return step3
    }
    
    func requestChallenge(_ authRequest: AuthRequest) -> AnyPublisher<ChallengeResource, Error> {
        var comps = URLComponents(string: settings.authEndpoint.description)!
        comps.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: authRequest.clientMetadata?.id),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "redirect_uri", value: authRequest.redirectURI),
            URLQueryItem(name: "code_challenge", value: authRequest.codeChallenge),
            URLQueryItem(name: "scope", value: authRequest.scope),
        ]
        
        NSLog("Performing the PKCE request to Keycloak: \(comps.url!.description)")

        var request = URLRequest(url: comps.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return self.session!.dataTaskPublisher(for: request)
            .mapError { $0 as Error }
            .tryMap() { output -> Data in
                guard let httpResponse = output.response as? HTTPURLResponse,
                    httpResponse.statusCode == 200 else {
                    throw AuthError.challengeResponseError
                    }
                NSLog("Got challenge response")
                return output.data
            }
            .decode(type: ChallengeResource.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    func submitChallengeResponse(previousStep: AnyPublisher<ChallengeResource, Error>, authRequest: AuthRequest) -> AnyPublisher<ChallengeResource, Error> {
        return previousStep.flatMap { challenge -> AnyPublisher<ChallengeResource, Error> in
            var request = URLRequest(url: URL(string: challenge.endpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            request.httpBody = "command=challenge_response&signature=\(challenge.challenge!)&username=\(authRequest.username)".data(using: .utf8)
            return self.session!.dataTaskPublisher(for: request)
                .mapError { $0 as Error }
                .tryMap { output in
                    if let response = output.response as? HTTPURLResponse, response.statusCode != 200 {
                        throw AuthError.challengeResponseError
                    }
                    var newChallenge = try JSONDecoder().decode(ChallengeResource.self, from: output.data)
                    newChallenge.device_code = challenge.device_code
                    NSLog("Submitted the challenge response and got answer: authenticated=\(newChallenge.authenticated ?? false)")
                    return newChallenge
                }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }
    
    func finishAuthentication(previousStep: AnyPublisher<ChallengeResource, Error>) -> AnyPublisher<URL, Error> {
        return previousStep.flatMap { challenge -> AnyPublisher<URL, Error> in
            var request = URLRequest(url: URL(string: challenge.endpoint)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpBody = "command=finish&device_code=\(challenge.device_code!)".data(using: .utf8)
            return self.session!.dataTaskPublisher(for: request)
                .mapError { $0 as Error }
                .tryMap { output in
                    guard let response = output.response as? HTTPURLResponse, response.statusCode == 302 else {
                        throw AuthError.challengeResponseError
                    }
                    return URL(string: response.value(forHTTPHeaderField: "Location")!)!
                }.eraseToAnyPublisher()
        }.eraseToAnyPublisher()

    }

}

