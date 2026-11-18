//
//  EscrowDisplay.swift
//  escrow
//
//  Presentation helpers shared by the escrow screens. Identity is just the
//  wallet address, so avatars, initials and colours are derived from it.
//

import SwiftUI

extension String {
    /// "0x7F3a9...E2b" -> "0x7F3a…9E2b"
    var shortAddress: String {
        count > 12 ? "\(prefix(6))…\(suffix(4))" : self
    }
}

func sameAddress(_ a: EthAddress?, _ b: EthAddress?) -> Bool {
    guard let a, let b else { return false }
    return a.lowercased() == b.lowercased()
}

/// Formats a wei amount as ETH with 2–4 decimals, e.g. "0.82" or "2.4810".
func ethText(_ wei: String) -> String {
    Wei.toEth(wei).formatted(.number.precision(.fractionLength(2...4)))
}

/// Shown before every action that sends a transaction (NFR11).
let networkFeeNote = "This is an Ethereum transaction and costs a small network fee (gas)."

/// Rough USD estimate shown under amounts.
// ponytail: fixed price; fetch a live rate if the fiat line has to be accurate.
func fiatText(_ wei: String) -> String {
    let usd = Wei.toEth(wei) * 3800
    return "≈ $" + usd.formatted(.number.precision(.fractionLength(2)))
}

struct AddressAvatar: View {
    let address: EthAddress?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let address {
                Text(String(address.dropFirst(2).prefix(2)).uppercased())
            } else {
                Image(systemName: "hourglass")
            }
        }
        .font(size > 60 ? .title2.weight(.semibold) : .subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(address.map(Self.color) ?? Color.white.opacity(0.08), in: Circle())
    }

    /// Stable hue from the address, so the same wallet always gets the same colour.
    private static func color(for address: EthAddress) -> Color {
        let hue = address.lowercased().unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 360 }
        return Color(hue: Double(hue) / 360, saturation: 0.45, brightness: 0.75)
    }
}

extension EscrowState {
    var label: String {
        switch self {
        case .created: return "Created"
        case .funded: return "Funded"
        case .shipped: return "Sent"
        case .completed: return "Completed"
        case .refunded: return "Refunded"
        case .disputed: return "Disputed"
        }
    }

    var color: Color {
        switch self {
        case .completed: return Color(red: 0.36, green: 0.78, blue: 0.55)
        case .funded: return Color(red: 0.55, green: 0.45, blue: 0.90)
        case .created: return Color(red: 0.78, green: 0.62, blue: 0.45)
        case .shipped: return Color(red: 0.40, green: 0.60, blue: 0.90)
        case .refunded: return Color(red: 0.90, green: 0.40, blue: 0.45)
        case .disputed: return Color(red: 0.90, green: 0.62, blue: 0.30)
        }
    }
}

extension Escrow {
    func isBuyer(_ me: EthAddress) -> Bool { sameAddress(buyer, me) }

    /// The other party from `me`'s point of view; nil while no seller has joined.
    func counterparty(of me: EthAddress) -> EthAddress? {
        isBuyer(me) ? seller : buyer
    }

    /// The key rides along so the link's holder can read the terms.
    var inviteURL: URL {
        var components = URLComponents()
        components.scheme = "escrow"
        components.host = "join"
        components.path = "/\(id)"
        if let inviteKey {
            components.queryItems = [URLQueryItem(name: "k", value: inviteKey)]
        }
        return components.url!
    }
}

extension View {
    /// Shows the escrow view-model's error. Attached per screen because an
    /// alert on a view covered by a sheet never appears.
    func escrowErrorAlert(_ vm: EscrowViewModel) -> some View {
        alert(
            "Something went wrong",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}
