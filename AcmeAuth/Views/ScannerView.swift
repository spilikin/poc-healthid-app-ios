// AcmeAuth/ScannerView.swift
// 


import SwiftUI
import CodeScanner
import AVFoundation

struct ScannerView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSheetView: Bool

    var body: some View {
        NavigationView {
            CodeScannerView(codeTypes: [.qr], simulatedData: "https://appauth.acme.spilikin.dev/api/auth/challenge?acct=884874@healthid.life&redirect_uri=https://acme.spilikin.dev/Account/&remote_auth_uri=https://acme.spilikin.dev/SignIn/Authenticate", completion: self.handleScan)
            .navigationBarTitle(Text("Scan Login Code"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.showSheetView = false
            }) {
                Image(systemName: "multiply.circle.fill")
                    .imageScale(.large)
                    .padding()
            })
        }
    }

    func handleScan(result: Result<String, CodeScannerView.ScanError>) {
        
        switch result {
        case .success(let code):
            let url = URL(string: code)
            if appState.accepts(url: url) {
                let systemSoundID: SystemSoundID = 1108
                AudioServicesPlaySystemSound (systemSoundID)
                self.showSheetView = false
                appState.onOpenURL( url )
            }
        case .failure(let error):
            print(error.localizedDescription)
        }
        
    }
    

}
