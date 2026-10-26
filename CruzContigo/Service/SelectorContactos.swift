//
//  SelectorContactos.swift
//  CruzContigo
//

import Contacts
import ContactsUI
import UIKit

final class SelectorContactos: NSObject, CNContactPickerDelegate {
    private static var actual: SelectorContactos?
    private let alElegir: (CNContact) -> Void

    private init(alElegir: @escaping (CNContact) -> Void) {
        self.alElegir = alElegir
    }

    static func presentar(alElegir: @escaping (CNContact) -> Void) {
        let escena = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var superior = escena?.keyWindow?.rootViewController
        while let presentado = superior?.presentedViewController {
            superior = presentado
        }
        let selector = SelectorContactos(alElegir: alElegir)
        actual = selector
        let picker = CNContactPickerViewController()
        picker.delegate = selector
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactBirthdayKey]
        superior?.present(picker, animated: true)
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        alElegir(contact)
        Self.actual = nil
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        Self.actual = nil
    }
}

extension FamiliarDraft {
    mutating func completar(con contacto: CNContact) {
        if contacto.isKeyAvailable(CNContactGivenNameKey), !contacto.givenName.isEmpty {
            nombre = contacto.givenName
        }
        if contacto.isKeyAvailable(CNContactFamilyNameKey), !contacto.familyName.isEmpty {
            apellidos = contacto.familyName
        }
        if contacto.isKeyAvailable(CNContactPhoneNumbersKey), let numero = contacto.phoneNumbers.first?.value.stringValue {
            telefono = numero
        }
        if contacto.isKeyAvailable(CNContactBirthdayKey), let cumple = contacto.birthday {
            if let d = cumple.day { dia = String(d) }
            if let m = cumple.month { mes = m }
            if let a = cumple.year { anio = String(a) }
        }
    }
}
