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


protocol EscrowService {
    var myAddress: EthAddress { get }

    // MARK: Reads
    func listEscrows() async throws -> [Escrow]
    func escrow(id: UInt64) async throws -> Escrow
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
    func withdraw() async throws
}
