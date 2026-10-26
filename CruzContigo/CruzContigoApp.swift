//
//  CruzContigoApp.swift
//  CruzContigo
//


import SwiftUI

@main
struct CruzContigoApp: App {
    init() {
        Tipografia.registrar()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
