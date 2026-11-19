//
//  Config.swift
//  escrow
//
//  Environment-dependent settings. The simulator can reach the backend on
//  localhost; a physical device must use the Mac's LAN IP (both on the same
//  Wi-Fi). The chain is switched with `network`.
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

    enum Network {
        case anvil, sepolia
    }

    /// The chain the app talks to. `.anvil` needs a local `anvil` with the
    /// contract from contracts/script/Deploy.s.sol; `.sepolia` needs
    /// Secrets.swift (copy escrow/Secrets.example.swift).
    static let network: Network = .sepolia

    static var chainId: Int {
        switch network {
        case .anvil: return 31337
        case .sepolia: return 11155111
        }
    }

    static var rpcURL: String {
        switch network {
        case .anvil: return "http://127.0.0.1:8545"
        case .sepolia: return Secrets.sepoliaRPCURL
        }
    }

    static var escrowContract: String {
        switch network {
        case .anvil: return "0x5FbDB2315678afecb367f032d93F642f64180aa3"
        case .sepolia: return "0x9c5776bcF1f1eA263D35a73Eca07112ff132EA12"
        }
    }
}
