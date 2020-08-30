// AcmeAuth/KeyManagement.swift
// 


import Foundation

let HealthIDKeyTag = "dev.spilikin.acme.healthid.signing-key".data(using: .utf8)!

enum KeyLoadError: Error {
    case keyNotFound
}

class KeyManager {
    
    var query: [String: Any] {
        get {
            return  [
                kSecClass as String: kSecClassKey,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrApplicationTag as String: HealthIDKeyTag,
                kSecReturnRef as String: true,
                kSecUseOperationPrompt as String: "HealthID Credentials required",
//                kSecUseAuthenticationContext as String: context,
            ]
        }
    }
    
    func loadKey() throws -> KeyPair {        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw KeyLoadError.keyNotFound   }
        let key = item as! SecKey
        return KeyPair(signingKey: key, verifyingKey: SecKeyCopyPublicKey(key)!)
    }
    
    func createKey() throws -> KeyPair  {
        // remove old key first
        SecItemDelete(query as CFDictionary)
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                                           kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                           [.biometryCurrentSet, .privateKeyUsage],
                                                           &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        
        var attributes: [String: Any] = [
          kSecAttrKeyType as String:            kSecAttrKeyTypeEC,
          kSecAttrKeySizeInBits as String:      256,
          kSecAttrTokenID as String:            kSecAttrTokenIDSecureEnclave,
          kSecPrivateKeyAttrs as String: [
            kSecAttrIsPermanent as String:      true,
            kSecAttrApplicationTag as String:   HealthIDKeyTag,
            kSecAttrAccessControl as String:    access
          ]
        ]
        
        #if targetEnvironment(simulator)
            // if we run in a simulator allow to create a key outside of secure enclave
            attributes.removeValue(forKey: kSecAttrTokenID as String)
        #endif
        
        guard let _ = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        return try loadKey()
    }
}

struct KeyPair {
    let signingKey: SecKey
    let verifyingKey: SecKey
    var verifyingKeyAsPEM: String? {
        get {
            var error:Unmanaged<CFError>?
            let secp256r1Header = Data([
                0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a,
                0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00
                ])
            if let cfdata = SecKeyCopyExternalRepresentation(verifyingKey, &error) {
                var data: Data = cfdata as Data
                data = secp256r1Header+data
                let str = data.base64EncodedString(options: .lineLength64Characters)
                return """
-----BEGIN PUBLIC KEY-----
\(str)
-----END PUBLIC KEY-----
"""
            } else {
                return nil
            }
        }
    }
    
    
}
