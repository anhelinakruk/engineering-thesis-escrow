//
//  JoinTransactionView.swift
//  escrow
//
//  What the seller sees after opening the buyer's shared link: the escrow
//  invitation. Reached via an `escrow://join/<id>` deep link. Without `onJoin`
//  it is the buyer's preview of the same screen, with a share button instead.
//

import SwiftUI

struct JoinTransactionView: View {
    @EnvironmentObject private var vm: EscrowViewModel
    let escrow: Escrow
    var onJoin: (() async -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                invitationHeader
                amountCard
                protectionBanner
                Text("Escrow #\(escrow.id) · created by \(escrow.buyer.shortAddress)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            Group {
                if let onJoin {
                    Button {
                        Task { await onJoin() }
                    } label: {
                        buttonLabel(vm.isSending ? "Joining…" : "Join transaction")
                    }
                    .disabled(vm.isSending)
                } else {
                    ShareLink(item: escrow.inviteURL) {
                        buttonLabel("Share invite link")
                    }
                }
            }
            .background(
                Color.brandTeal,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Color.brandTeal.opacity(0.4), radius: 16, y: 4)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private func buttonLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
    }

    private var invitationHeader: some View {
        VStack(spacing: 14) {
            Text("ESCROW INVITATION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTeal)

            AddressAvatar(address: escrow.buyer, size: 72)

            VStack(spacing: 4) {
                Text(escrow.buyer.shortAddress)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("invites you to a secure transaction")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var amountCard: some View {
        VStack(spacing: 6) {
            Text("TRANSACTION AMOUNT")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(ethText(escrow.amountWei)) ETH")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Text(fiatText(escrow.amountWei))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var protectionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.brandTeal)
                Text("How escrow protects you")
                    .font(.headline)
                    .foregroundStyle(Color.brandTeal)
            }
            Text("The funds are already secured in a smart contract. You'll receive them automatically once the buyer confirms receipt.")
                .font(.subheadline)
                .foregroundStyle(.white)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.brandTeal.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.brandTeal.opacity(0.6), lineWidth: 1)
        )
    }
}

#Preview {
    JoinTransactionView(escrow: Escrow(
        id: 7, buyer: "0x7F3a5b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e9E2b", seller: nil,
        amountWei: "820000000000000000", state: .funded, shipDeadline: nil, confirmDeadline: nil
    ))
    .environmentObject(EscrowViewModel())
    .preferredColorScheme(.dark)
}
