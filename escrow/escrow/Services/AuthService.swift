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

    /// Signs in with the wallet stored in the Keychain. Returns the JWT response
    /// and caches the token in the Keychain.
    @discardableResult
    func login() async throws -> AuthResponse {
        guard let mnemonic = keychain.read(WalletKeychainKeys.mnemonic),
              let address = keychain.read(WalletKeychainKeys.address) else {
            throw AuthError.noWallet
        }

        let nonce = try await backend.getNonce()

        let message = SIWEMessage(
            domain: URL(string: AppConfig.backendBaseURL)?.host ?? "localhost",
            address: address,
            statement: "Sign in to Escrow",
            uri: AppConfig.backendBaseURL,
            version: "1",
            chainId: AppConfig.chainId,
            nonce: nonce
        ).format()

        let signature = try await signMessage(mnemonic: mnemonic, message: message)
        let auth = try await backend.verifyAndLogin(
            message: message,
            signature: signature,
            address: address
        )

        keychain.save(auth.accessToken, for: WalletKeychainKeys.token)
        return auth
    }
}
