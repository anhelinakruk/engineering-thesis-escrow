//
//  EscrowService.swift
//  escrow
//
//  The boundary between the SwiftUI layer and the escrows. On-chain work
//  (ABI encoding, signing, RPC) happens in Rust via AlloySwift; the deal
//  descriptions come from the backend. This file passes the Keychain-held
//  mnemonic / JWT down and maps the results to app models.
//

import Foundation
import AlloySwift

enum EscrowError: Error, LocalizedError {
    case noWallet
    case invalidAmount
    case invalidAddress
    /// The chain or the contract said no; carries its reason when there is one.
    case chain(String)

    var errorDescription: String? {
        switch self {
        case .noWallet:
            return "No wallet on this device."
        case .invalidAmount:
            return "Enter an amount greater than zero."
        case .invalidAddress:
            return "That isn't a valid Ethereum address."
        case .chain(let why):
            return why
        }
    }
}

protocol EscrowService {
    var myAddress: EthAddress { get }

    // MARK: Reads
    func listEscrows() async throws -> [Escrow]
    /// `inviteKey` comes from an invite link and unlocks the description for
    /// someone who isn't a party yet.
    func escrow(id: UInt64, inviteKey: String?) async throws -> Escrow
    func balanceWei() async throws -> String
    func pendingWithdrawalWei() async throws -> String

    // MARK: Writes
    /// Creates and funds a new escrow; returns the id to share with the seller.
    func createEscrow(amountWei: String) async throws -> UInt64
    /// Write-once deal terms; only the escrow's buyer may set them.
    func saveDescription(_ description: String, escrowId: UInt64) async throws
    func perform(_ action: EscrowAction, id: UInt64) async throws
    func withdraw() async throws
    /// Plain ETH transfer from the wallet to any address.
    func transfer(to: EthAddress, amountWei: String) async throws
}

struct AlloyEscrowService: EscrowService {
    private let keychain = KeychainStore(service: WalletKeychainKeys.service)
    private let backend = BackendService()
    private let rpcURL = AppConfig.rpcURL
    private let contract = AppConfig.escrowContract

    var myAddress: EthAddress {
        keychain.read(WalletKeychainKeys.address) ?? ""
    }

    func listEscrows() async throws -> [Escrow] {
        let escrows = try await mapErrors {
            try await listEscrowsFor(rpcUrl: rpcURL, contract: contract, address: myAddress)
                .map(Escrow.init)
        }
        return await withDescriptions(escrows)
    }

    func escrow(id: UInt64, inviteKey: String?) async throws -> Escrow {
        var escrow = try await mapErrors {
            Escrow(try await getEscrow(rpcUrl: rpcURL, contract: contract, id: id))
        }
        escrow = await withDescriptions([escrow])[0]
        if escrow.description == nil, let inviteKey,
           let token = keychain.read(WalletKeychainKeys.token) {
            escrow.description = try? await backend.inviteDescription(escrowId: id, key: inviteKey, token: token)
        }
        return escrow
    }

    func saveDescription(_ description: String, escrowId: UInt64) async throws {
        guard let token = keychain.read(WalletKeychainKeys.token) else {
            throw EscrowError.noWallet
        }
        try await backend.saveDescription(escrowId: escrowId, description: description, token: token)
    }

    /// Descriptions are a nice-to-have: if the backend is unreachable the
    /// escrows still show, just without their terms.
    private func withDescriptions(_ escrows: [Escrow]) async -> [Escrow] {
        guard let token = keychain.read(WalletKeychainKeys.token),
              let descriptions = try? await backend.descriptions(escrowIds: escrows.map(\.id), token: token)
        else { return escrows }
        return escrows.map { escrow in
            var escrow = escrow
            escrow.description = descriptions[escrow.id]?.description
            escrow.inviteKey = descriptions[escrow.id]?.inviteKey
            return escrow
        }
    }

    func balanceWei() async throws -> String {
        try await mapErrors { try await getBalance(rpcUrl: rpcURL, address: myAddress) }
    }

    func pendingWithdrawalWei() async throws -> String {
        try await mapErrors {
            try await pendingWithdrawal(rpcUrl: rpcURL, contract: contract, address: myAddress)
        }
    }

    func createEscrow(amountWei: String) async throws -> UInt64 {
        let mnemonic = try mnemonic()
        return try await mapErrors {
            try await AlloySwift.createEscrow(
                mnemonic: mnemonic, rpcUrl: rpcURL, contract: contract, amountWei: amountWei
            )
        }
    }

    func perform(_ action: EscrowAction, id: UInt64) async throws {
        let mnemonic = try mnemonic()
        _ = try await mapErrors {
            try await escrowAction(
                mnemonic: mnemonic, rpcUrl: rpcURL, contract: contract,
                action: action.alloy, id: id
            )
        }
    }

    func withdraw() async throws {
        let mnemonic = try mnemonic()
        _ = try await mapErrors {
            try await AlloySwift.withdraw(mnemonic: mnemonic, rpcUrl: rpcURL, contract: contract)
        }
    }

    func transfer(to: EthAddress, amountWei: String) async throws {
        guard isValidAddress(address: to) else { throw EscrowError.invalidAddress }
        let mnemonic = try mnemonic()
        _ = try await mapErrors {
            try await transferEth(mnemonic: mnemonic, rpcUrl: rpcURL, to: to, amountWei: amountWei)
        }
    }

    private func mnemonic() throws -> String {
        guard let mnemonic = keychain.read(WalletKeychainKeys.mnemonic) else {
            throw EscrowError.noWallet
        }
        return mnemonic
    }

    /// Rust errors arrive as one long provider string; keep only the
    /// contract's revert reason (e.g. "only buyer can confirm") when present,
    /// and turn an unreachable node into something a user can act on (NFR7).
    private func mapErrors<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as AlloyError {
            throw EscrowError.chain(Self.reason(error))
        }
    }

    static func reason(_ error: AlloyError) -> String {
        let message: String
        switch error {
        case .MnemonicError(let m), .AddressError(let m), .UrlError(let m), .ProviderError(let m):
            message = m
        }
        if message.contains("error sending request") {
            return "Can't reach the Ethereum network. Check your internet connection and try again."
        }
        guard let start = message.range(of: "execution reverted: ") else {
            return message
        }
        let reason = message[start.upperBound...]
        return String(reason.split(separator: ",", maxSplits: 1).first ?? reason)
    }
}

private extension Escrow {
    init(_ info: EscrowInfo) {
        self.init(
            id: info.id,
            buyer: info.buyer,
            seller: info.seller,
            amountWei: info.amountWei,
            state: EscrowState(info.state),
            shipDeadline: info.shipDeadline.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            confirmDeadline: info.confirmDeadline.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }
}

private extension EscrowState {
    init(_ state: AlloySwift.EscrowState) {
        switch state {
        case .created: self = .created
        case .funded: self = .funded
        case .shipped: self = .shipped
        case .completed: self = .completed
        case .disputed: self = .disputed
        case .refunded: self = .refunded
        }
    }
}

private extension EscrowAction {
    var alloy: AlloySwift.EscrowAction {
        switch self {
        case .join: return .join
        case .cancel: return .cancel
        case .markShipped: return .markShipped
        case .confirmReceipt: return .confirmReceipt
        case .refundExpired: return .refundExpired
        case .autoComplete: return .autoComplete
        case .raiseDispute: return .raiseDispute
        }
    }
}
