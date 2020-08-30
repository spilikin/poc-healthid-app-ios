// AcmeAuth/Enroll.swift
//

import Foundation
import Combine
import JOSESwift
import LocalAuthentication

struct EnrollmentRequest: Codable {
    let acct: String
    let email: String
}

struct SignedEnrollmentRequest: Codable {
    let signed_enrollment: String
    let verifying_key: String
}

class EnrollmentManager {
    private let smartcardManager = SmartcardManager()
    
    func enroll(acct: String) -> AnyPublisher<String, Error> {
        
        return Just(acct)
            .map {acct -> EnrollmentRequest in
                return EnrollmentRequest(acct: acct, email: acct)
            }
            .tryMap { enrollmentRequest -> SignedEnrollmentRequest in
                return try self.signEnrollmentRequestWithEnclave(enrollmentRequest)
            }
            .flatMap { signedEnrollmentRequest in
                return self.postEnrollment(signedEnrollmentRequest)
            }.eraseToAnyPublisher()
        
    }
    
    func enrollWithSmartcard(acct: String, can: String, pin: String) -> AnyPublisher<String, Error> {
        // TODO: this code if fake, it just simulates that the Smartcard is being used
        return Just(acct)
            .map {acct -> EnrollmentRequest in
                return EnrollmentRequest(acct: acct, email: acct)
            }
            .tryMap { enrollmentRequest -> SignedEnrollmentRequest in
                return try self.signEnrollmentRequestWithEnclave(enrollmentRequest)
            }
            .flatMap { enrollment -> AnyPublisher<SignedEnrollmentRequest, Error> in
                return self.signEntollmentRequestWithSmartcard(enrollment)
            }
            .flatMap { signedEnrollmentRequest  in
                return self.postEnrollment(signedEnrollmentRequest)
            }.eraseToAnyPublisher()
    }

    private func signEntollmentRequestWithSmartcard(_ signedEnrollmentRequest: SignedEnrollmentRequest) -> AnyPublisher<SignedEnrollmentRequest, Error> {
        return smartcardManager.pollCardInfo()
            .map { Bool -> SignedEnrollmentRequest in
                return signedEnrollmentRequest
            }.eraseToAnyPublisher()
    }
    
    private func signEnrollmentRequestWithEnclave(_ enrollmentRequest: EnrollmentRequest) throws -> SignedEnrollmentRequest {
        let context = LAContext()
        
        #if !targetEnvironment(simulator)
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)  else {
            throw error!
        }
        #endif
        
        let keyManager = KeyManager()
        let keyPair = try keyManager.createKey()

        let header = JWSHeader(algorithm: .ES256)
        let payload = Payload(try JSONEncoder().encode(enrollmentRequest))
        let signer = Signer(signingAlgorithm: .ES256, privateKey: keyPair.signingKey)!
        let jws = try JWS(header: header, payload: payload, signer: signer)
        let signedEnrollmentRequest = SignedEnrollmentRequest(signed_enrollment: jws.compactSerializedString, verifying_key: keyPair.verifyingKeyAsPEM!)

        return signedEnrollmentRequest
    }
    
    private func postEnrollment(_ enrollment: SignedEnrollmentRequest) -> AnyPublisher<String, Error> {
        return Just(enrollment)
            .encode(encoder: JSONEncoder())
            .map {data -> URLRequest in
                var request = URLRequest(url: AppSettings().apiURL(for: "enroll"))
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = data
                return request
            }
            .flatMap { request in
                URLSession.shared.dataTaskPublisher(for: request)
                    .mapError { $0 as Error}
                    .map { String(decoding: $0.data, as: UTF8.self) }
            }
            .eraseToAnyPublisher()
        
    }
}
