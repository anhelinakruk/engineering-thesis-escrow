//
//  JoinTransactionView.swift
//  escrow
//
//  What the seller sees after opening the buyer's shared link: the escrow
//  invitation. Reached via a deep link (not wired yet). Appearance only —
//  "Join transaction" will call the service to join the escrow later.
//

import SwiftUI

struct JoinTransactionView: View {
    var onJoin: () -> Void = {}

    // Sample invitation data; will come from the link / service.
    private let inviterName = "Jan Nowak"
    private let inviterInitials = "JN"
    private let inviterColor = Color(red: 0.52, green: 0.40, blue: 0.85)
    private let inviterAddress = "0×7F3a...9E2b"
    private let amountEth = "0.82"
    private let terms = "MacBook Pro 14, 2023, excellent condition. Local pickup, Warsaw, Mokotów."
    private let usdPerEth = 3800.0

    private var fiatText: String {
        let usd = (Double(amountEth) ?? 0) * usdPerEth
        return "≈ $" + usd.formatted(.number.precision(.fractionLength(2)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                invitationHeader
                amountCard
                protectionBanner
                termsSection
                Text("Created by \(inviterName) · \(inviterAddress)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .bottom) {
            Button(action: onJoin) {
                Text("Join transaction")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
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

    private var invitationHeader: some View {
        VStack(spacing: 14) {
            Text("ESCROW INVITATION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brandTeal)

            Text(inviterInitials)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(inviterColor, in: Circle())

            VStack(spacing: 4) {
                Text(inviterName)
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
            Text("\(amountEth) ETH")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
            Text(fiatText)
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

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRANSACTION TERMS")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(terms)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
    }
}

#Preview {
    JoinTransactionView()
        .preferredColorScheme(.dark)
}
