//
//  AppServices.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

/// The app's service graph, built once at launch and handed to the ViewModels.
/// Everything is typed by protocol so a ViewModel never depends on a concrete
/// networking or Firebase class.
struct AppServices {
    let apiClient: APIClient
    let elections: ElectionServiceProtocol
    let auth: AuthServiceProtocol
    let selections: SelectionServiceProtocol
    let profiles: UserProfileServiceProtocol

    /// The shared, production service graph. Creating it doesn't touch Firebase; the Firebase
    /// services resolve `Auth.auth()` / `Firestore.firestore()` only when first used, which is
    /// after `FirebaseApp.configure()` has run in the app delegate.
    static let shared = AppServices.live()

    static func live() -> AppServices {
        let client = APIClient()
        let store = KeychainService()
        // The JWT is read from the Keychain for every authorized request.
        client.tokenProvider = { store.load()?.token }

        return AppServices(
            apiClient: client,
            elections: ElectionService(client: client),
            auth: AuthService(
                api: AuthAPIService(client: client),
                firebase: FirebaseAuthService(),
                store: store
            ),
            selections: SelectionService(),
            profiles: UserProfileService()
        )
    }
}
