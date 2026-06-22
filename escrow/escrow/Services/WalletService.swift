//
//  WalletService.swift
//  escrow
//
//  The boundary for wallet/key operations. The UI depends only on this
//  protocol. The cryptographic work lives in Rust (AlloySwift via UniFFI):
//  BIP-39 mnemonic generation, key derivation, signing. Swift only ever holds
//  the words long enough to show them and to pass them back to Rust — and keeps
//  them in the iOS Keychain. The private key itself never reaches Swift.
//

import Foundation
import Security
import AlloySwift

/// A wallet recovery phrase — the ordered list of mnemonic words.
struct Mnemonic: Hashable {
    let words: [String]

    /// The phrase as a single space-separated string (for copy / import).
    var phrase: String { words.joined(separator: " ") }
}

/// Failures a wallet operation can surface.
enum WalletError: Error, LocalizedError {
    case invalidPhrase
    case entropyFailure

    var errorDescription: String? {
        switch self {
        case .invalidPhrase:
            return "That recovery phrase isn't valid. Check the words and spacing."
        case .entropyFailure:
            return "Couldn't generate secure randomness for the wallet."
        }
    }
}

/// Operations for creating and restoring the local wallet.
protocol WalletService {
    /// Creates a brand-new wallet and returns its recovery phrase to display.
    func createWallet() async throws -> Mnemonic

    /// Restores a wallet from an existing recovery phrase. Throws if the phrase
    /// is invalid.
    func importWallet(phrase: String) async throws
}

/// Real implementation backed by the Rust layer (AlloySwift) and the Keychain.
struct AlloyWalletService: WalletService {
    private let keychain = KeychainStore(service: WalletKeychainKeys.service)

    func createWallet() async throws -> Mnemonic {
        // 128 bits of entropy -> a 12-word BIP-39 phrase.
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw WalletError.entropyFailure
        }

        let phrase = try await generateMnemonic(bytes: Data(bytes))
        let address = try await deriveAddressFromMnemonic(mnemonic: phrase)

        keychain.save(phrase, for: WalletKeychainKeys.mnemonic)
        keychain.save(address, for: WalletKeychainKeys.address)

        return Mnemonic(words: phrase.split(separator: " ").map(String.init))
    }

    func importWallet(phrase: String) async throws {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        guard words.count == 12 || words.count == 24 else {
            throw WalletError.invalidPhrase
        }

        // Rust validates BIP-39 (checksum + wordlist) and throws on a bad phrase.
        let address: String
        do {
            address = try await deriveAddressFromMnemonic(mnemonic: trimmed)
        } catch {
            throw WalletError.invalidPhrase
        }

        keychain.save(trimmed, for: WalletKeychainKeys.mnemonic)
        keychain.save(address, for: WalletKeychainKeys.address)
    }
}

/// In-memory placeholder kept for SwiftUI previews and tests.
///
/// WARNING: NOT cryptographically secure and NOT a real BIP-39 phrase. It only
/// yields plausible-looking words so screens can render without the Rust layer.
struct MockWalletService: WalletService {
    private static let sampleWords = [
        "ocean", "target", "lemon", "puzzle", "garden", "velvet",
        "ridge", "comfort", "anchor", "sunny", "marble", "falcon",
        "harbor", "meadow", "copper", "ginger", "ladder", "orbit",
        "pepper", "willow", "cactus", "tunnel", "marble", "nectar",
        "pilot", "raven", "silver", "timber", "violet", "walnut",
    ]

    func createWallet() async throws -> Mnemonic {
        let words = (0..<12).map { _ in Self.sampleWords.randomElement()! }
        return Mnemonic(words: words)
    }

    func importWallet(phrase: String) async throws {
        let words = phrase.split(whereSeparator: \.isWhitespace)
        guard words.count == 12 else { throw WalletError.invalidPhrase }
    }
}
