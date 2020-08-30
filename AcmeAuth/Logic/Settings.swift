// AcmeAuth/Settings.swift
// 


import Foundation

struct ConnectorSettings {
    var host: String = "konnektor.local"
    var username = "CompanionApp"
    var password = ""
    var x509Cert = ""
    var mandantId: String = "CompanionAppMandant"
    var clientSystemId: String = "CompanionAppClient"
    var workSpaceId: String = "CompanionAppWorkspace"
}

class AppSettings: ObservableObject {
    @Published var connector = ConnectorSettings()
    @Published var apiBaseURL = URL(string: "https://appauth.acme.spilikin.dev/api/")!
    @Published var acct: String {
         didSet {
            UserDefaults.standard.set(acct, forKey: "acct")
         }
     }

    @Published var isEnrolled: Bool {
         didSet {
             UserDefaults.standard.set(isEnrolled, forKey: "isEnrolled")
         }
     }

    init() {
        if let acct = UserDefaults.standard.string(forKey: "acct") {
            self.acct = acct
        } else {
            let acct = "\(AppSettings.randomID(length: 6))@healthid.life"
            self.acct = acct
            UserDefaults.standard.set(acct, forKey: "acct")
        }
        self.isEnrolled = UserDefaults.standard.bool(forKey: "isEnrolled")

    }
    
    private static func randomID(length: Int) -> String {
        let letters = "0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
    }

    
    func apiURL(for resource: String, params: [String: String] = [:]) -> URL {
        var builder = URLComponents(string: URL(string: resource, relativeTo: apiBaseURL)!.absoluteURL.description )!
        if !params.isEmpty {
            builder.queryItems = params.map { (k,v) in
                URLQueryItem(name: k, value: v)
            }
        }
        return builder.url!
    }
    
    func reset() {
        self.isEnrolled = false
    }
}
