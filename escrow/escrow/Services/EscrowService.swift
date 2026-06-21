//
//  EscrowService.swift
//  escrow
//
//  The boundary between the SwiftUI layer and everything below it. Today a
//  mock fulfils this protocol; later the Rust core (Alloy) will, exposed to
//  Swift through UniFFI. The UI depends only on this protocol, never on how
//  the work is actually done.
//

import Foundation

/// Failures a service operation can surface, mirroring the contract's reverts.
enum EscrowError: Error, LocalizedError {
    case notFound
    case unauthorized(String)
    case invalidState(String)
    case deadlineNotReached
    case nothingToWithdraw

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Escrow does not exist."
        case .unauthorized(let why):
            return why
        case .invalidState(let why):
            return why
        case .deadlineNotReached:
            return "The deadline has not been reached yet."
        case .nothingToWithdraw:
            return "Nothing to withdraw."
        }
    }
}

/// Every operation the local wallet can perform against the escrow contract.
///
/// Calls are `async` because the real implementation talks to the Sepolia
/// network, and `throws` because the chain can reject a transaction (wrong
/// state, wrong caller, deadline not reached, ...). Mutating calls return the
/// escrow's fresh state so the UI can refresh without a second round-trip.
protocol EscrowService {
    /// The local wallet's address (from the iOS Keychain in the real impl).
    var myAddress: EthAddress { get }

    // MARK: Reads
    func listEscrows() async throws -> [Escrow]
    func escrow(id: UInt64) async throws -> Escrow
    /// How much ETH (in wei) the local wallet may currently withdraw.
    func pendingWithdrawalWei() async throws -> String

    // MARK: Buyer actions
    func createEscrow(amountWei: String) async throws -> Escrow
    func cancelEscrow(id: UInt64) async throws -> Escrow
    func confirmReceipt(id: UInt64) async throws -> Escrow
    func refundExpired(id: UInt64) async throws -> Escrow

    // MARK: Seller actions
    func joinEscrow(id: UInt64) async throws -> Escrow
    func markShipped(id: UInt64) async throws -> Escrow
    func autoComplete(id: UInt64) async throws -> Escrow

    // MARK: Either party
    func raiseDispute(id: UInt64) async throws -> Escrow

    // MARK: Arbiter
    func resolveForSeller(id: UInt64) async throws -> Escrow
    func resolveForBuyer(id: UInt64) async throws -> Escrow

    // MARK: Funds
    /// Drains the local wallet's entire pending balance to itself.
    func withdraw() async throws
}
