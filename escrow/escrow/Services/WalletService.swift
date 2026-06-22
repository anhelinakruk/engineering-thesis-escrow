//
//  WalletService.swift
//  escrow
//
//  The boundary for wallet/key operations. Like EscrowService, the UI depends
//  only on this protocol. The real implementation will live in Rust: BIP-39
//  mnemonic generation, key derivation, and storing the private key in the iOS
//  Keychain. Swift only ever sees the words it has to show — never the key.
//

import Foundation

/// A wallet recovery phrase — the ordered list of mnemonic words.
struct Mnemonic: Hashable {
    let words: [String]

    /// The phrase as a single space-separated string (for copy / import).
    var phrase: String { words.joined(separator: " ") }
}

/// Failures a wallet operation can surface.
enum WalletError: Error, LocalizedError {
    case invalidPhrase

    var errorDescription: String? {
        switch self {
        case .invalidPhrase:
            return "That recovery phrase isn't valid. Check the words and spacing."
        }
    }
}

/// Operations for creating and restoring the local wallet.
protocol WalletService {
    /// Creates a brand-new wallet and returns its recovery phrase to display.
    func createWallet() throws -> Mnemonic

    /// Restores a wallet from an existing recovery phrase. Throws if the phrase
    /// is invalid.
    func importWallet(phrase: String) throws
}

/// In-memory placeholder used while the Rust/UniFFI layer does not exist yet.
///
/// WARNING: this is NOT cryptographically secure and does NOT produce a real
/// BIP-39 phrase or a usable key. It only yields plausible-looking words so the
/// onboarding UI can be built and demoed. It must be replaced by the Rust
/// implementation before the wallet ever holds real funds.
struct MockWalletService: WalletService {
    private static let sampleWords = [
        "ocean", "target", "lemon", "puzzle", "garden", "velvet",
        "ridge", "comfort", "anchor", "sunny", "marble", "falcon",
        "harbor", "meadow", "copper", "ginger", "ladder", "orbit",
        "pepper", "willow", "cactus", "tunnel", "marble", "nectar",
        "pilot", "raven", "silver", "timber", "violet", "walnut",
    ]

    func createWallet() throws -> Mnemonic {
        let words = (0..<12).map { _ in Self.sampleWords.randomElement()! }
        return Mnemonic(words: words)
    }

    func importWallet(phrase: String) throws {
        // Mock check only: real BIP-39 validation (checksum, wordlist) belongs
        // to the Rust layer. Here we just require 12 whitespace-separated words.
        let words = phrase.split(whereSeparator: \.isWhitespace)
        guard words.count == 12 else { throw WalletError.invalidPhrase }
    }
}
