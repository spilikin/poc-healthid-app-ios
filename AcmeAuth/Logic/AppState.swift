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
        //onOpenURL(URL(string: "https://appauth.acme.spilikin.dev/api/auth/challenge?acct=884874@healthid.life&redirect_uri=https://acme.spilikin.dev/Account/&remote_auth_uri=https://acme.spilikin.dev/SignIn/Authenticate")!)
    }
    
    func accepts(url: URL?) -> Bool {
        guard let url = url else {
            // no URL was specified
            return false
        }
        
        return AuthRequest(url) != nil
    }
    
    func onOpenURL(_ url: URL?) {
        guard let url = url else {
            // no URL was specified
            return
        }
        
        //debugLog = url.description + "\n" + debugLog
        
        authRequest = AuthRequest(url)
        if let _ = authRequest {
            isSpecialScreenState = true
            screenState = .authenticating
        } else {
            isSpecialScreenState = false
            screenState = .normal
        }
    }
    

    
}
