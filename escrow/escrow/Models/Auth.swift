//
//  Auth.swift
//  escrow
//
//  Models for Sign-In with Ethereum (SIWE). The wallet proves it controls an
//  address by signing a message; the backend recovers the signer and issues a
//  JWT. No password, no account — identity is just the address.
//

import Foundation

/// Reply to `GET /api/auth/nonce`.
struct NonceResponse: Decodable {
    let nonce: String
}

/// Reply to `POST /api/auth/verify`.
struct AuthResponse: Decodable {
    let accessToken: String
    let userId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case userId = "user_id"
    }
}

/// A SIWE (EIP-4361-style) message. The backend pulls the nonce out of the
/// formatted text (it scans for the "Nonce: " line), recovers the signer from
/// the signature, and checks it equals `address`.
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
