// AcmeAuth/Auth.swift
// 


import Foundation
import Combine
import JOSESwift

enum AuthError: Error {
    case serverError
    case localSignatureError
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

class AuthRequest {
    let url: URL
    var redirectURI: URLComponents
    let keyManager = KeyManager()
    let isRemote: Bool
    let acct: String
    let nonce: String?
    
    init?(_ url: URL) {
        self.url = url
        let comps = URLComponents(string: url.description)

        guard let acct = comps?.queryItems?.first(where: { $0.name.lowercased() == "acct"})?.value else {
            return nil
        }
        self.acct = acct

        guard let redirectStr = comps?.queryItems?.first(where: { $0.name.lowercased() == "redirect_uri"})?.value else {
            return nil
        }
        guard let redirectComps = URLComponents(string: redirectStr) else {
            return nil
        }
        
        redirectURI = redirectComps

        // see if we have remove auth request
        isRemote = comps!.path.hasSuffix("auth/remote")
        
        if isRemote {
            self.nonce = comps?.queryItems?.first(where: { $0.name.lowercased() == "nonce"})?.value
        } else {
            self.nonce = nil
        }
        
    }
}

class AuthManager {
    var settings = AppSettings()
    var cancellable: AnyCancellable?
    var completition: ((Result<URL,Error>) -> Void)?
    var keyManager = KeyManager()
            
    private func getChallenge(acct: String, redirectUri: String) -> AnyPublisher<Challenge, Error> {
        return URLSession.shared.dataTaskPublisher(for: settings.apiURL(for: "auth/challenge", params: [ "acct": acct, "redirect_uri": redirectUri ]))
            .mapError { $0 as Error }
            .map { $0.data }
            .decode(type: Challenge.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
 
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
    
    private func postSignedChallenge(_ signedChallenge: SignedChallenge, isRemote: Bool = false) -> AnyPublisher<Data, Error> {
        
        return Just(signedChallenge)
            .encode(encoder: JSONEncoder())
            .map {data -> URLRequest in
                var request = URLRequest(url: self.settings.apiURL(for: isRemote ? "auth/remote" : "auth/challenge" ))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = data
                return request
            }
            .flatMap { request in
                return URLSession.shared.dataTaskPublisher(for: request)
                    .mapError { $0 as Error}
                    .map { $0.data }
            }
            .eraseToAnyPublisher()
        
    }
    
    func authenticate(_ authRequest: AuthRequest) -> AnyPublisher<URL, Error>  {
        let publisher = getChallenge(acct: authRequest.acct, redirectUri: authRequest.redirectURI.description)
            .tryMap { challenge  -> SignedChallenge in
                try self.signChallenge(challenge)
            }
            .flatMap({ signedChallenge in
                return self.postSignedChallenge(signedChallenge)
            })
            .decode(type: AuthenticationCode.self, decoder: JSONDecoder())
            .map({ code -> URL in
                authRequest.redirectURI.queryItems = [ URLQueryItem(name: "code", value: code.code)]
                return authRequest.redirectURI.url!
            })
            .eraseToAnyPublisher()
        return publisher
    }
    
    func remoteAuthenticate(_ authRequest: AuthRequest) -> AnyPublisher<Bool, Error>  {
        let publisher = Future<Challenge, Error> { promise in
                let challenge = Challenge(acct: authRequest.acct , nonce: authRequest.nonce!)
                promise(.success(challenge))
            }
            .tryMap { challenge  -> SignedChallenge in
                try self.signChallenge(challenge)
            }
            .flatMap { signedChallenge in
                return self.postSignedChallenge(signedChallenge, isRemote: true)
            }
            .map { _ in true }
            .eraseToAnyPublisher()
        return publisher
    }

}

