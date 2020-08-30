// AcmeAuth/AuthView.swift
// 


import SwiftUI
import Combine
import AVFoundation

struct AuthView: View {
    @Binding var showSheetView: Bool
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    let authRequest: AuthRequest
    var authManager = AuthManager()
    @State var cancellable: AnyCancellable? = nil


    var body: some View {
        NavigationView {
            VStack() {
                Spacer()
                Text("Authenticate:").font(.headline)
                // TODO: fetch App Metadata/Federation Policy
                Text("HealthID Profile App").font(.largeTitle).bold()
                Text("(\(authRequest.redirectURI.host!))").font(.title).bold()
                Spacer()
                confirmButton
                Spacer()
                    .frame(height: 50)
            }
            .navigationBarTitle(Text("Please Authenticate"), displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                self.showSheetView = false
            }) {
                Image(systemName: "multiply.circle.fill")
                    .imageScale(.large)
                    .padding()
            })
        }
        .alert(isPresented: $showingErrorAlert) {
            errorAlert
        }


    }

    var errorAlert: Alert {
        Alert(
            title: Text("Error"),
            message: Text(errorMessage),
            dismissButton: .default(Text("Continue")) {
                showingErrorAlert = false
                showSheetView = false
            })

    }
        
    var confirmButton: some View {
        Button(action: {
            if !authRequest.isRemote {
                cancellable = authManager.authenticate(self.authRequest)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
                    }, receiveValue: { url in
                        notifySuccess()
                        showSheetView = false
                        UIApplication.shared.open(url)
                    })
            } else {
                cancellable = authManager.remoteAuthenticate(self.authRequest)
                    .receive(on: DispatchQueue.main)
                    .sink(receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
                    }, receiveValue: { _ in
                        notifySuccess()
                        showSheetView = false
                    })

            }
        }) {
            HStack(alignment: .center) {
                Spacer()
                Image(systemName: "lock.open.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text("Sign In")
                Spacer()
            }.padding()
            .foregroundColor(.white)
            .background(Color.green)
            .cornerRadius(15)
        }.padding()
    }

    func notifySuccess() {
        AudioServicesPlaySystemSound (1306)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

    }
}
