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
        #if targetEnvironment(simulator)
        return "http://localhost:3000"
        #else
        // TODO: set to your Mac's LAN IP when running on a physical device.
        return "http://192.168.1.100:3000"
        #endif
    }

    /// Sepolia testnet.
    static let chainId: Int = 11155111
}
