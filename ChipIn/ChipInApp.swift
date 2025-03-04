//
//  ChipInApp.swift
//  ChipIn
//
//  Created by Andrey on 24/02/2025.
//

import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import GoogleSignIn


@main
struct ChipInApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            
            HomeView()
        }
    }
}
