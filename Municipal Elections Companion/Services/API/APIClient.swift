//
//  APIClient.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher & Gemini
//

import Foundation

/// Low-level HTTP client for the ASP.NET Core Web API.
///
/// Builds URLs with `URLComponents` (so "Pitt Meadows" becomes `Pitt%20Meadows`), attaches the
/// JWT to authorized requests, decodes `{ "message": "..." }` error bodies, and reports a 401 on an
/// authorized request through `onUnauthorized` so the session can be cleared in one place.
final class APIClient {
    static let baseURL = URL(string: "https://mems-api-afisher-ane9a7cmfpb9b9at.canadacentral-01.azurewebsites.net")!

    private let session: URLSession
    private let decoder = JSONDecoder.api
    private let encoder = JSONEncoder()

    /// Returns the current JWT, or nil when logged out.
    var tokenProvider: () -> String? = { nil }
    /// Called when an authorized request comes back 401.
    var onUnauthorized: () -> Void = {}

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get<Response: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        authorized: Bool = true
    ) async throws -> Response {
        let request = try makeRequest(path: path, method: "GET", query: query, authorized: authorized)
        let data = try await send(request)
        return try decode(Response.self, from: data)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        authorized: Bool = true
    ) async throws -> Response {
        let data = try await sendPost(path, body: body, authorized: authorized)
        return try decode(Response.self, from: data)
    }

    /// POST for endpoints whose success body we don't need (e.g. register returns `{ message }`).
    func post<Body: Encodable>(_ path: String, body: Body, authorized: Bool = true) async throws {
        _ = try await sendPost(path, body: body, authorized: authorized)
    }

    // MARK: - Private

    private func sendPost<Body: Encodable>(_ path: String, body: Body, authorized: Bool) async throws -> Data {
        var request = try makeRequest(path: path, method: "POST", query: [], authorized: authorized)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    private func makeRequest(path: String, method: String, query: [URLQueryItem], authorized: Bool) throws -> URLRequest {
        guard var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.from(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? decoder.decode(APIMessageResponse.self, from: data))?.message
            let isAuthorized = request.value(forHTTPHeaderField: "Authorization") != nil

            switch http.statusCode {
            case 401 where isAuthorized:
                onUnauthorized()
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound(message ?? "The requested information couldn't be found.")
            default:
                throw APIError.serverError(message ?? "The server returned an error (\(http.statusCode)).")
            }
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            print("Decoding error for \(T.self): \(error)")
            throw APIError.decodingError
        }
    }
}

extension JSONDecoder {
    /// Decoder for the Web API. `electionDate` comes without a time zone
    /// (`"2026-10-17T00:00:00"`), which `.iso8601` rejects, so dates are parsed with
    /// POSIX `DateFormatter`s instead.
    static var api: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            for formatter in APIDateFormatters.all {
                if let date = formatter.date(from: string) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return decoder
    }
}

private nonisolated enum APIDateFormatters {
    static let all: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Election dates are local BC dates; keep them in the device's zone so they don't shift a day.
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }
}
