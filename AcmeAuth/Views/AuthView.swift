// AcmeAuth/AuthView.swift
// 


import SwiftUI
import Combine
import AVFoundation

class ImageLoader: ObservableObject {
    var didChange = PassthroughSubject<Data, Never>()
    var data = Data() {
        didSet {
            didChange.send(data)
        }
    }

    init(_ urlString:String) {
        guard let url = URL(string: urlString) else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else { return }
            DispatchQueue.main.async {
                self.data = data
            }
        }
        task.resume()
    }
}

struct AuthView: View {
    @Binding var showSheetView: Bool
    let authRequest: AuthRequest
    @ObservedObject var imageLoader:ImageLoader
    @State var clientIcon:UIImage = UIImage()
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    var authManager = AuthManager()
    @State var cancellable: AnyCancellable? = nil
   
    init(showSheetView: Binding<Bool>, authRequest: AuthRequest) {
        self._showSheetView = showSheetView
        self.authRequest = authRequest
        self.imageLoader = ImageLoader(authRequest.clientMetadata?.iconUri ?? "https://acme.spilikin.dev/img/logo.28c1d21d.png")
    }
 
    
    var body: some View {
        NavigationView {
            VStack() {
                Spacer()
                Text("Authenticate:").font(.headline)
                
                Image(uiImage: clientIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width:150, height:150)
                    .cornerRadius(20)
                    .onReceive(imageLoader.didChange) { data in
                        self.clientIcon = UIImage(data: data) ?? UIImage()
                    }
                                
                Text(authRequest.clientMetadata?.name ?? "Unknown").font(.largeTitle).bold()
                Text("(\(authRequest.clientMetadata!.id))").font(.title).bold()
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
                /*
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
                */

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
