//
//  Escrow.swift
//  escrow
//
//  Domain models mirroring the on-chain escrow contract. Pure value types,
//  no UI and no networking — this is the shared vocabulary the rest of the
//  app (and later the Rust/UniFFI layer) speaks.
//

import Foundation

/// An Ethereum address, kept as the canonical lowercase hex string ("0x...").
/// A user's identity in this app is nothing more than their wallet address.
typealias EthAddress = String

/// Lifecycle of a single escrow, mirroring the contract's `State` enum exactly.
enum EscrowState: String {
    case created   // registered, funds not yet locked (never persisted on-chain)
    case funded    // buyer has locked the amount; waiting for / has a seller
    case shipped   // seller marked the item as sent
    case completed // funds released to the seller (terminal)
    case disputed  // a party escalated to the arbiter (only from shipped)
    case refunded  // funds returned to the buyer (terminal)
}

/// One escrow deal as seen by the app.
///
/// The amount is carried as a wei string because a wei value (up to ~10^18 per
/// ETH) overflows Swift's 64-bit integers, and the Rust/UniFFI boundary will
/// hand us u256 values as strings too. `seller` and the deadlines are optional
/// because they are empty until the matching step happens on-chain.
struct Escrow: Identifiable {
    /// Matches the contract id (the key in its `transactions` mapping).
    let id: UInt64
    let buyer: EthAddress
    /// `nil` until a seller joins via the shared link (on-chain: address(0)).
    let seller: EthAddress?
    /// Locked value, in wei.
    let amountWei: String
    let state: EscrowState
    /// By when the seller must ship; set when the escrow is funded.
    let shipDeadline: Date?
    /// By when the buyer must confirm; set when the seller ships.
    let confirmDeadline: Date?
}
