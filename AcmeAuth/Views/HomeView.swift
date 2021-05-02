import SwiftUI
import Combine

struct HomeView: View {
    @Environment(\.openURL) var openURL
    @EnvironmentObject var appState: AppState
    @State var cancellable: AnyCancellable? = nil
    
    @ViewBuilder var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center) {
                    if (appState.settings.isEnrolled) {
                        advertisement
                        IdentityView(model: IdentityViewModel(mockIdentity))
                    } else {
                        enrollButton
                    }


                    /*

                    if (appState.settings.isEnrolled) {
                        if (appState.enrollmentSuccess) {
                            VStack(alignment: .center) {
                                    Image(systemName: "checkmark.circle")
                                        .resizable()
                                        .frame(width: 150, height: 150)
                                        .foregroundColor(.green)
                                        .padding()
                            }
                        }

                        accountButton
                        scannerButton
                        readCardButton
                        visitWebButton

                    } else {
                        enrollButton
                    }
                    debugView
                    */
                }
                .navigationBarTitle(Text("HealthID"))
                .navigationBarItems(leading: scannerButton, trailing: settingsButton)
                .sheet(isPresented: $appState.isSpecialScreenState) {
                    sheetView()
                }
            }
        }

    }
        
    func sheetView() -> AnyView {
        
        switch appState.screenState {
        case .scanning:
            return AnyView(ScannerView(showSheetView: $appState.isSpecialScreenState))
        case .authenticating:
            return AnyView(AuthView(showSheetView: $appState.isSpecialScreenState, authRequest: appState.authRequest!))
        case .normal:
            return AnyView(Text(""))
        }
    }

    let smartcardManager = SmartcardManager()
    var readCardButton: some View {
        Button(action: {
            self.cancellable = smartcardManager.pollCardInfo()
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print ("Error while using smartcard: \(error)")
                }
            }, receiveValue: { _ in
            })

        }) {
            HStack(alignment: .center) {
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                Text("Add Smartcard")
                Spacer()
            }.padding()
                .foregroundColor(.white)
                .background(Color.accentColor)
                .cornerRadius(15)
        }
        .padding()

    }

    var advertisement: some View {
        Button(action: {
            openURL(URL(string: "https://aua.spilikin.dev")!)
        }) {
            HStack(alignment: .center) {
                Image("pain")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 65, height: 65)

                Text("Got pain? Try Aua.app!")
                Spacer()
                Image(systemName: "chevron.right")
            }.padding()
                .foregroundColor(.white)
                .background(Color(red: 250 / 255, green: 210 / 255, blue: 77 / 255))
                .cornerRadius(15)
        }
        .padding()

    }
    
    var accountButton: some View {
        VStack(alignment: .leading) {
            Text("HealtID Account:")
                .font(.callout)
                .bold()
            HStack() {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                TextField("", text: $appState.settings.acct)
                    .disabled(true)
                    .font(.callout)
                Spacer()
                Button(action: {
                    UIPasteboard.general.string = appState.settings.acct
                }) {
                    Image(systemName: "doc.on.doc")
                }
                
            }
            HStack {
                Spacer()
            }
        }
        .padding()
    }

    var enrollButton: some View {
        VStack(alignment: .leading) {

            Text("""
Enroll your identity at the Identity Provider and register this device as an autentication key
""")
                .padding()
                .lineLimit(3)

            NavigationLink(destination: EnrollmentView()) {
                HStack(alignment: .center) {
                    Image(systemName: "lock.shield.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Start enrollment")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
            }
        }
        .foregroundColor(.white)
        .background(Color.accentColor)
        .cornerRadius(20)
        .padding()
    }

    var scannerButton: some View {
        
        Button(action: {
            appState.screenState = .scanning
            appState.isSpecialScreenState.toggle()
        }) {
            // "person.crop.circle"
            Image(systemName: "qrcode.viewfinder")
                .imageScale(.large)
                .padding()
        }

    }
    
    var settingsButton: some View {
        
        NavigationLink(destination: SettingsView()) {
            // "person.crop.circle"
            Image(systemName: "slider.horizontal.3")
                .imageScale(.large)
                .padding()
        }

    }
    
    var visitWebButton: some View {
        Button(action: {
            if let url = URL(string: "https://acme.spilikin.dev/") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(alignment: .center) {
                Image(systemName: "safari")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                Text("Open website")

            }

        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
