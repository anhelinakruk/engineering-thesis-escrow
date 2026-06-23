//
//  Config.swift
//  escrow
//
//  Environment-dependent settings. The simulator can reach the backend on
//  localhost; a physical device must use the Mac's LAN IP (both on the same
//  Wi-Fi). Chain is the Sepolia testnet.
//

import Foundation

enum AppConfig {
    /// Base URL of the Rust backend (SIWE auth, later escrow metadata).
    static var backendBaseURL: String {
        // 127.0.0.1 (not "localhost"): the server binds 0.0.0.0 (IPv4 only), but
        // "localhost" resolves to ::1 (IPv6) first, which is refused.
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:3000"
        #else
        // TODO: set to your Mac's LAN IP when running on a physical device.
        return "http://192.168.1.100:3000"
        #endif
    }

    /// Sepolia testnet.
    static let chainId: Int = 11155111
}
