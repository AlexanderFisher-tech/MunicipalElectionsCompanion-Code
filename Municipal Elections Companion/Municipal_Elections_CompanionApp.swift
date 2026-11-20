//
//  Municipal_Elections_CompanionApp.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher on 2026-10-23.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Reads GoogleService-Info.plist; must run before any Firebase Auth / Firestore call.
        FirebaseApp.configure()
        return true
    }
}

@main
struct Municipal_Elections_CompanionApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // App-wide state lives here, above every layout, so it survives rotation and size-class changes.
    @State private var session: SessionViewModel
    @State private var selections: SelectionsViewModel
    @State private var router = AppRouter()

    init() {
        let session = SessionViewModel()
        _session = State(initialValue: session)
        _selections = State(initialValue: SelectionsViewModel(session: session))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .environment(selections)
                .environment(router)
        }
    }
}
