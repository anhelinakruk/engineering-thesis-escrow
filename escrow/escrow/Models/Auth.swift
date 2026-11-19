//
//  Auth.swift
//  escrow
//
//  Models for Sign-In with Ethereum (SIWE). The wallet proves it controls an
//  address by signing a message; the backend recovers the signer and issues a
//  JWT. No password, no account — identity is just the address.
//

import Foundation

/// `GET /api/auth/nonce`.
struct NonceResponse: Decodable {
    let nonce: String
}

/// `POST /api/auth/verify`.
struct AuthResponse: Decodable {
    let accessToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
    }
}

struct SIWEMessage {
    let domain: String
    let address: String
    let statement: String
    let uri: String
    let version: String
    let chainId: Int
    let nonce: String

    func format() -> String {
        """
        \(domain) wants you to sign in with your Ethereum account:
        \(address)

        \(statement)

        URI: \(uri)
        Version: \(version)
        Chain ID: \(chainId)
        Nonce: \(nonce)
        """
    }
}

/// Reads the backend JWT's `exp` claim. No signature check: the server
/// verifies tokens; the app only needs to know when to ask for a new one.
enum JWT {
    static func expiry(of token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = claims["exp"] as? Double
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// True for an unreadable token or one that expires within `margin`.
    static func needsRenewal(_ token: String, now: Date = .now, margin: TimeInterval = 60) -> Bool {
        guard let expiry = expiry(of: token) else { return true }
        return expiry.timeIntervalSince(now) < margin
    }
}
