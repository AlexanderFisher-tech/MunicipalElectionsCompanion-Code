//
//  FirebaseErrorMapper.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// A Firestore document that exists but doesn't match the expected shape.
enum FirestoreDataError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        "Some of your saved data couldn't be read. Pull to refresh, or remove and re-add the selection."
    }
}

/// Turns any error the app can hit (API, Firebase Auth, Firestore, validation) into a message
/// that's safe to show the user.
enum UserFacingError {
    static func message(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == AuthErrorDomain {
            return authMessage(for: AuthErrorCode(rawValue: nsError.code))
        }
        if nsError.domain == FirestoreErrorDomain {
            return firestoreMessage(for: FirestoreErrorCode.Code(rawValue: nsError.code))
        }
        if let urlError = error as? URLError {
            return APIError.from(urlError).errorDescription ?? fallback
        }
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return fallback
    }

    /// True when the error means the user must sign in again (JWT or Firebase session gone).
    static func requiresReauthentication(_ error: Error) -> Bool {
        if let apiError = error as? APIError, apiError == .unauthorized { return true }
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           FirestoreErrorCode.Code(rawValue: nsError.code) == .unauthenticated {
            return true
        }
        if nsError.domain == AuthErrorDomain {
            switch AuthErrorCode(rawValue: nsError.code) {
            case .userTokenExpired, .invalidUserToken, .requiresRecentLogin:
                return true
            default:
                return false
            }
        }
        return false
    }

    private static let fallback = "Something went wrong. Please try again."

    private static func authMessage(for code: AuthErrorCode?) -> String {
        switch code {
        case .networkError:
            return "Couldn't reach the sign-in service. Check your internet connection."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .userDisabled:
            return "This account has been disabled."
        case .invalidEmail:
            return "That email address isn't valid."
        case .weakPassword:
            return "Please choose a stronger password (at least 6 characters)."
        case .wrongPassword, .invalidCredential, .userNotFound:
            return "Invalid email or password."
        case .userTokenExpired, .invalidUserToken, .requiresRecentLogin:
            return "Your session has expired. Please log in again."
        case .operationNotAllowed:
            return "Email sign-in isn't enabled for this app's Firebase project."
        default:
            return "Couldn't sign in to cloud sync. Please try again."
        }
    }

    private static func firestoreMessage(for code: FirestoreErrorCode.Code?) -> String {
        switch code {
        case .unavailable, .deadlineExceeded:
            return "Couldn't reach the cloud database. Check your connection and try again."
        case .permissionDenied:
            return "You don't have permission to access this data. Try logging out and back in."
        case .unauthenticated:
            return "Your session has expired. Please log in again."
        case .notFound:
            return "That selection no longer exists. Pull to refresh."
        case .alreadyExists:
            return "That candidate is already in your selections."
        case .resourceExhausted:
            return "The cloud database is busy. Please try again shortly."
        case .failedPrecondition:
            return "The cloud database isn't ready for this request yet. Please try again later."
        case .dataLoss, .internal:
            return "The cloud database returned invalid data. Please try again."
        default:
            return "A cloud database error occurred. Please try again."
        }
    }
}
