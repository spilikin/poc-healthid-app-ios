//
//  IdentityView.swift
//  AcmeAuth
//  
//  Created on 22.04.21
//

import SwiftUI

struct Identity {
    var username: String
    var identifier: String
    var email: String
    var firstname: String
    var lastname: String
    var street: String
    var zip: String
    var locality: String
    var country: String
}

struct IdentityAttribute: Identifiable {
    var id: String { label }

    let label: String
    @State var value: String
    var verified = false
}

class IdentityViewModel {
    let identity: Identity
    let attributes: [IdentityAttribute]

    init(_ identity: Identity) {
        self.identity = identity
        attributes = [
            IdentityAttribute(label: "ID", value: identity.identifier, verified: true),
            IdentityAttribute(label: "Firsn name", value: identity.firstname, verified: true),
            IdentityAttribute(label: "Last name", value: identity.lastname, verified: true),
            IdentityAttribute(label: "Email", value: identity.email, verified: false),
            IdentityAttribute(label: "Address", value: identity.street, verified: true),
            IdentityAttribute(label: "Postal code", value: identity.zip, verified: true),
            IdentityAttribute(label: "Country", value: identity.country, verified: true),
        ]
    }


}

let mockIdentity = Identity(
    username: "user1",
    identifier: "38957982",
    email: "manu2000@example.com",
    firstname: "Manuela",
    lastname: "Mustermann",
    street: "Hauptstraße 155",
    zip: "10827",
    locality: "Berlin",
    country: "DE"
)


struct IdentityView: View {
    var model: IdentityViewModel

//    var backgroundColor = Color.blue
    var backgroundColor = Color(red: 250 / 255, green: 210 / 255, blue: 77 / 255)

    var body: some View {

        VStack(alignment: .center, spacing: 0) {


            Image("manuela")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 200, alignment: .center)
                .clipShape(Circle())

            Text("\(model.identity.firstname) \(model.identity.lastname)").font(.title)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(model.attributes) { attr in
                    Text(attr.label).font(.caption)
                    HStack() {
                        TextField("", text: attr.$value)
                            .disabled(true)
                            .font(.callout)
                        if (attr.verified) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    Divider()
                }
            }
            .padding()
        }

    }


    var settingsButton: some View {

        NavigationLink(destination: SettingsView()) {
            Image(systemName: "gear")
                .imageScale(.large)
                .foregroundColor(.primary)
        }.padding(3)

    }


}

struct IdentityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            IdentityView(model: IdentityViewModel(mockIdentity))
        }
    }
}
