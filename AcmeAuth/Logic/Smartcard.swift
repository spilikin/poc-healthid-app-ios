// AcmeAuth/Smartcard.swift
// 


import Foundation
import Combine
import CoreNFC

enum NFCError: LocalizedError {
    case unavailable
    case timeout
    case cardNotFound

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "NFC Reader Not Available"
        case .timeout:
            return "Timeout occured"
        case .cardNotFound:
            return "Card not found"
        }
    }

}

class SmartcardManager: NSObject {
    private var session: NFCTagReaderSession?
    private var promise: ((Result<Bool, Error>) -> Void)?
    
    public func pollCardInfo() -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            self.promise = promise
            self.startCardPolling()
        }.eraseToAnyPublisher()
    }
    
    private func startCardPolling() {

        guard NFCTagReaderSession.readingAvailable else {
            print("NFC is not available on this device")
            promise?(.failure(NFCError.unavailable))
            return
        }
        
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.alertMessage = "Hold a smartcard next to your device"
        session?.begin()

    }
    
    func invalidateSession() {
        session?.invalidate()
        session = nil
    }

}

extension SmartcardManager: NFCTagReaderSessionDelegate {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
     }

     public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Swift.Error) {
        if let nfcerror = error as? NFCReaderError {
            promise?(.failure(nfcerror))
            print ("NFC error code: \(nfcerror.errorCode)")
        }
        invalidateSession()
     }

     public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        

        guard let tag = tags.first else {
            session.alertMessage = "Card not found"
            return
        }

        guard case .iso7816(let smartcard) = tag else {
            session.alertMessage = "Invalid card"
            return
        }

        
        session.alertMessage = "Connecting"

        // Connect to tag
        session.connect(to: tag) { [unowned self] (error: Swift.Error?) in
            if let error = error {
                promise?(.failure(error))
                self.invalidateSession()
                return
            }
            
            // Smartcard Karate would start here
            // since it's only a PoC we just put delay here
            let apdu = NFCISO7816APDU(instructionClass: 0, instructionCode: 0, p1Parameter: 0, p2Parameter: 0, data: Data(), expectedResponseLength: 256)
            for num in 1...400 {
                smartcard.sendCommand(apdu: apdu, completionHandler: { lData, lSw1, lSw2, err in
                    if let _ = err {
                        smartcard.session?.invalidate(errorMessage: "Error during smartcard Karate")
                    } else {
                        session.alertMessage = "\(num/5)%"
                    }
                    if (num == 400) {
                        session.alertMessage = "Done"
                        smartcard.session?.invalidate()
                        promise?(.success(true))
                    }
                })
            }
            
            /*
            session.alertMessage = "Connected to smartcard"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                session.alertMessage = "Doing smartcard Karate"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                session.alertMessage = "Even more smartcard Karate"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                session.alertMessage = "Almost there"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                session.alertMessage = "Done"
                smartcard.session?.invalidate()
            }
            */
         }
     }
}
