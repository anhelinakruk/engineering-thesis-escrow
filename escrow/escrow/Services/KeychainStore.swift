//
//  KeychainStore.swift
//  escrow
//
//  Thin wrapper over the iOS Keychain for the wallet's secrets (mnemonic,
//  address). Values are stored as generic-password items under one service.
//  The mnemonic never leaves the device; Swift only holds it long enough to
//  hand to the Rust signing layer.
//

import Foundation
import Security

/// Shared Keychain identifiers so the wallet and auth layers agree on where the
/// secrets live.
enum WalletKeychainKeys {
    static let service = "com.escrow.wallet"
    static let mnemonic = "wallet_mnemonic"
    static let address = "wallet_address"
    static let token = "access_token"
}

struct KeychainStore {
    let service: String

    func save(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
