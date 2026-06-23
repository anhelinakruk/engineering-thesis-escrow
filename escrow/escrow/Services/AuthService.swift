//
//  AuthService.swift
//  escrow
//
//  Drives the SIWE handshake end to end: fetch a nonce, build the message, sign
//  it with the on-device key (Rust/AlloySwift), and exchange it for a JWT. The
//  mnemonic is read from the Keychain and only ever leaves the device as a
//  signature — never the key itself.
//

import Foundation
import AlloySwift

struct AuthService {
    private let backend: BackendService
    private let keychain = KeychainStore(service: WalletKeychainKeys.service)

    init(backend: BackendService = BackendService()) {
        self.backend = backend
    }

    enum AuthError: Error, LocalizedError {
        case noWallet

        var errorDescription: String? {
            switch self {
            case .noWallet:
                return "No wallet found on this device."
            }
        }
    }

    /// Fetches a nonce and builds the SIWE message to show the user before they
    /// sign. Read-only — no signing, no key access.
    func prepareSIWEMessage() async throws -> String {
        guard let address = keychain.read(WalletKeychainKeys.address) else {
            throw AuthError.noWallet
        }
        let nonce = try await backend.getNonce()
        return SIWEMessage(
            domain: URL(string: AppConfig.backendBaseURL)?.host ?? "localhost",
            address: address,
            statement: "Sign in to Escrow",
            uri: AppConfig.backendBaseURL,
            version: "1",
            chainId: AppConfig.chainId,
            nonce: nonce
        ).format()
    }

    /// Signs the given SIWE message on-device (Rust) and verifies it on the
    /// backend, caching the returned JWT in the Keychain.
    @discardableResult
    func completeLogin(message: String) async throws -> AuthResponse {
        guard let mnemonic = keychain.read(WalletKeychainKeys.mnemonic),
              let address = keychain.read(WalletKeychainKeys.address) else {
            throw AuthError.noWallet
        }
        let signature = try await signMessage(mnemonic: mnemonic, message: message)
        let auth = try await backend.verifyAndLogin(
            message: message,
            signature: signature,
            address: address
        )
        keychain.save(auth.accessToken, for: WalletKeychainKeys.token)
        return auth
    }

    /// Convenience: prepare + complete in one shot (e.g. silent re-login).
    @discardableResult
    func login() async throws -> AuthResponse {
        let message = try await prepareSIWEMessage()
        return try await completeLogin(message: message)
    }
}
