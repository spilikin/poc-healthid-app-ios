// AcmeAuth/AppState.swift
// 


import Foundation


enum ScreenState {
    case normal
    case scanning
    case authenticating
}

class AppState: ObservableObject {
    @Published var debugLog = ""
    @Published var authRequest: AuthRequest?
    @Published var screenState: ScreenState = .normal
    @Published var isSpecialScreenState = false
    @Published var settings = AppSettings()
    @Published var enrollmentSuccess = false
    
    init() {
        //onOpenURL(URL(string: "https://id.acme.spilikin.dev/auth/realms/healthid/protocol/openid-connect/auth?response_type=code&client_id=aua.spilikin.dev&code_challenge_method=S256&code_challenge=leDpL-Rywd20NV_EgY31k_m4VcENQvAgDDKNJM9GeTE&redirect_uri=https%3A%2F%2Faua.spilikin.dev%2Flogin")!)
    }
    
    func accepts(url: URL?) -> Bool {
        guard let url = url else {
            // no URL was specified
            return false
        }
        
        return (try? AuthRequest(url)) != nil
    }
    
    func onOpenURL(_ url: URL?) {
        guard let url = url else {
            // no URL was specified
            return
        }
        
        //debugLog = url.description + "\n" + debugLog
        
        try? authRequest = AuthRequest(url)
        if let _ = authRequest {
            isSpecialScreenState = true
            screenState = .authenticating
        } else {
            isSpecialScreenState = false
            screenState = .normal
        }
    }
    

    
}
