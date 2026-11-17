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

/// State-changing calls on an existing escrow (everything except create and withdraw).
enum EscrowAction {
    case join
    case cancel
    case markShipped
    case confirmReceipt
    case refundExpired
    case autoComplete
    case raiseDispute
}

struct Escrow: Identifiable, Hashable {
    let id: UInt64
    let buyer: EthAddress
    let seller: EthAddress?
    let amountWei: String
    let state: EscrowState
    let shipDeadline: Date?
    let confirmDeadline: Date?
}

/// Exact ETH <-> wei conversion. Decimal, not Double: amounts are money and
/// 18 decimal places don't fit in a Double.
enum Wei {
    private static let perEth = Decimal(sign: .plus, exponent: 18, significand: 1)

    /// "0.5" or "0,5" -> "500000000000000000"; nil for empty, negative or
    /// more precise than 1 wei.
    static func from(eth: String) -> String? {
        let normalized = eth.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value > 0
        else { return nil }

        var wei = value * perEth
        var rounded = Decimal()
        NSDecimalRound(&rounded, &wei, 0, .plain)
        guard rounded == wei else { return nil }
        return rounded.description
    }

    static func toEth(_ wei: String) -> Decimal {
        (Decimal(string: wei) ?? 0) / perEth
    }
}
