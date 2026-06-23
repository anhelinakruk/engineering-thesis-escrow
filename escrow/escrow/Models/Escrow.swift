//
//  Escrow.swift
//  escrow
//
//  Domain models mirroring the on-chain escrow contract. Pure value types,
//  no UI and no networking — this is the shared vocabulary the rest of the
//  app (and later the Rust/UniFFI layer) speaks.
//

import Foundation

typealias EthAddress = String

enum EscrowState: String {
    case created
    case funded
    case shipped
    case completed
    case disputed
    case refunded
}

struct Escrow: Identifiable {
    let id: UInt64
    let buyer: EthAddress
    let seller: EthAddress?
    let amountWei: String
    let state: EscrowState
    let shipDeadline: Date?
    let confirmDeadline: Date?
}
