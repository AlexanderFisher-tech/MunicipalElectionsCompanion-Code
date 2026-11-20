//
//  JWTDecoder.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation

/// Reads the expiry (`exp`) claim from a JWT so an expired session can be detected
/// locally, without waiting for the server to answer 401. The signature isn't checked
/// here; the server remains responsible for that.
enum JWTDecoder {
    static func expirationDate(of token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        // Base64URL → Base64 with padding
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    static func isExpired(_ token: String, now: Date = .now) -> Bool {
        guard let expiry = expirationDate(of: token) else { return false }
        return expiry <= now
    }
}
