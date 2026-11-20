//
//  APIError.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation

// Errors from the ASP.NET Core Web API, with user-friendly descriptions
enum APIError: LocalizedError, Equatable {
    case invalidURL
    /// The server's `{ "message": "..." }` text, shown to the user as-is.
    case serverError(String)
    case notFound(String)
    case decodingError
    /// 401 on a protected request: the JWT expired or is invalid.
    case unauthorized
    case offline
    case timedOut
    case network
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL."
        case .serverError(let message), .notFound(let message):
            return message
        case .decodingError:
            return "The server sent data the app couldn't read. Please try again later."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .offline:
            return "You appear to be offline. Check your internet connection and try again."
        case .timedOut:
            return "The server took too long to respond. Please try again."
        case .network:
            return "Couldn't reach the elections server. Please try again."
        case .unknown:
            return "An unexpected error occurred."
        }
    }

    /// Maps a `URLSession` failure to a friendly error.
    static func from(_ urlError: URLError) -> APIError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .offline
        case .timedOut:
            return .timedOut
        default:
            return .network
        }
    }
}
