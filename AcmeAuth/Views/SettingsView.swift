import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            Section(header: Text("ACCOUNT")) {
                TextField("Account", text: $appState.settings.acct).disabled(true)
            }

            Text("KONNEKTOR").font(.headline)
            Section(header: Text("Host")) {
                TextField("Host", text: $appState.settings.connector.host)
            }
            Section(header: Text("Username")) {
                TextField("Username", text: $appState.settings.connector.username)
            }
            Section(header: Text("Password")) {
                SecureField("Password", text: $appState.settings.connector.password)
            }
            Section(header: Text("Mandant ID")) {
                TextField("Mandant ID", text: $appState.settings.connector.mandantId)
            }
            Section(header: Text("Clientsystem ID")) {
                TextField("Clientsystem ID", text: $appState.settings.connector.clientSystemId)
            }
            Section(header: Text("Workplace ID")) {
                TextField("Workplace ID", text: $appState.settings.connector.workSpaceId)
            }
            
            Section {
                Button(action: {
                    appState.settings.reset()
                    // TODO: mage bette state change
                    appState.debugLog = ""
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Reset All Settings")
                        .foregroundColor(Color.red)
                }
            }
        }
        .navigationBarTitle(Text("Settings"))
    }

}

