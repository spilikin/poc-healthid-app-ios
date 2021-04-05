// AcmeAuth/Federation.swift
// 


import Foundation

// See https://openid.net/specs/openid-connect-registration-1_0.html#ClientMetadata
struct ClientMetadata {
    let id: String
    let name: String
    let iconUri: String
}

let FAKE_DATA: [ClientMetadata] = [
    ClientMetadata(id: "aua.spilikin.dev", name: "Aua.App: Pain Diary", iconUri: "https://aua.spilikin.dev/icon.png")
]

class FederationQuery {
    func clientMetadata(_ clientId: String) -> ClientMetadata? {
        return FAKE_DATA.first(where: { $0.id == clientId})
    }
}
