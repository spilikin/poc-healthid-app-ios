//
//  Extention UITextField+UIApplication End Editing Button.swift
//  Time Is Money
//
//  Created by Sebastien REMY on 15/07/2020.
//  Copyright © 2020 MonkeyDev. All rights reserved.
//

import SwiftUI

// Usage
//var currencyFormatter: NumberFormatter {
//    let formatter = NumberFormatter()
//    formatter.locale = .current
//    formatter.numberStyle = .currency
//    return formatter
//}
//  DecimalTextField("Enter amount",
//                   value: defaultRate,
//                   formatter: self.currencyFormatter)

struct DecimalTextField: UIViewRepresentable {
    private var placeholder: String
    @Binding var value: Double
    private var formatter: NumberFormatter

    init(_ placeholder: String,
         value: Binding<Double>) {
        self.placeholder = placeholder
        self._value = value
        self.formatter = NumberFormatter()
        //    formatter.locale = .current
        //    formatter.numberStyle = .currency
        //    return formatter
    }

    func makeUIView(context: Context) -> UITextField {
        let textfield = UITextField()
        textfield.keyboardType = .decimalPad
        textfield.delegate = context.coordinator
        textfield.placeholder = placeholder
        textfield.text = formatter.string(for: value) ?? placeholder

        let toolBar = UIToolbar(frame: CGRect(x: 0,
                                              y: 0,
                                              width: textfield.frame.size.width,
                                              height: 44))
        let doneButton = UIBarButtonItem(title: "Done",
                                         style: .done,
                                         target: self,
                                         action: #selector(textfield.doneButtonTapped(button:)))
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace,
                                    target: nil,action: nil)
        toolBar.setItems([space, doneButton], animated: true)
        textfield.inputAccessoryView = toolBar
        return textfield
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Do nothing, needed for protocol
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DecimalTextField

        init(_ textField: DecimalTextField) {
            self.parent = textField
        }

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {

            // Allow only numbers and decimal characters
            let isNumber = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
            let withDecimal = (
                string == NumberFormatter().decimalSeparator &&
                    textField.text?.contains(string) == false
            )

            if isNumber || withDecimal,
                let currentValue = textField.text as NSString?
            {
                // Update Value
                let proposedValue = currentValue.replacingCharacters(in: range, with: string) as String

                let decimalFormatter = NumberFormatter()
                decimalFormatter.locale = Locale.current
                decimalFormatter.numberStyle = .decimal

                // Try currency formatter then Decimal formatrer
                let number = self.parent.formatter.number(from: proposedValue) ?? decimalFormatter.number(from: proposedValue) ?? 0.0

                // Set Value
                let double = number.doubleValue
                self.parent.value = double
            }

            return isNumber || withDecimal
        }

        func textFieldDidEndEditing(_ textField: UITextField,
                                    reason: UITextField.DidEndEditingReason) {
            // Format value with formatter at End Editing
            textField.text = self.parent.formatter.string(for: self.parent.value)
        }

    }
}

// MARK: extension for done button
extension  UITextField{
    @objc func doneButtonTapped(button:UIBarButtonItem) -> Void {
        self.resignFirstResponder()
    }

}

// MARK: extension for keyboard to dismiss
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
