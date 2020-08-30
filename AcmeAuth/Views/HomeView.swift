import SwiftUI
import Combine

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State var cancellable: AnyCancellable? = nil

    func debug(_ text: String) {
        self.appState.debugLog = text + "\n" + self.appState.debugLog
    }
    
    @ViewBuilder var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .center) {
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
                }
                .navigationBarTitle(Text("Acme Companion"))
                .navigationBarItems(trailing: settingsButton)
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

    var debugView: some View {
        Text(self.appState.debugLog)
            .font(Font.system(.footnote, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading) {
            Text("""
Using this feature you can scan the QR code on a website to perform a remote login.
""")
                .padding()
                .lineLimit(3)
            Button(action: {
                appState.screenState = .scanning
                appState.isSpecialScreenState.toggle()
            }) {
                HStack(alignment: .center) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Scan Login Code")
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
