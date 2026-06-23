//
//  TransactionDetailView.swift
//  escrow
//
//  Detail screen for a single escrow, pushed from the wallet list. Shows the
//  state-machine progress, amount, counterparty, and description, plus the
//  actions available in the current state. Appearance only for now.
//

import SwiftUI

struct TransactionDetailView: View {
    let transaction: WalletTransaction

    var onConfirm: () -> Void = {}
    var onDispute: () -> Void = {}

    private let steps = ["Created", "Funded", "Sent", "Completed"]
    private let usdPerEth = 3800.0

    private let details = "MacBook Pro 14, 2023, excellent condition. Local pickup, Warsaw, Mokotów."

    @State private var showingInviteLink = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statusCard
                amountCard
                sellerSection
                descriptionSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(Color.appBackground)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingInviteLink = true
                } label: {
                    Image(systemName: "link")
                }
            }
        }
        .sheet(isPresented: $showingInviteLink) {
            JoinTransactionView()
        }
        .safeAreaInset(edge: .bottom) {
            if showsBuyerActions {
                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Confirm receipt")
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

                    Button(action: onDispute) {
                        Text("Report a dispute")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.90, green: 0.40, blue: 0.45))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("CURRENT STATUS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(statusTitle)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.brandTeal)
                Text(statusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            stepper
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var stepper: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                if index > 0 {
                    Rectangle()
                        .fill(index <= currentStep ? Color.brandTeal : Color.white.opacity(0.15))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 13)
                }
                VStack(spacing: 8) {
                    stepCircle(index: index)
                    Text(label)
                        .font(.caption)
                        .fontWeight(index == currentStep ? .semibold : .regular)
                        .foregroundStyle(index == currentStep ? .white : .secondary)
                }
            }
        }
    }

    private func stepCircle(index: Int) -> some View {
        ZStack {
            Circle()
                .fill(index <= currentStep ? Color.brandTeal : Color.white.opacity(0.15))
                .frame(width: 28, height: 28)
            if index < currentStep {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            } else if index == currentStep {
                Circle().fill(.white).frame(width: 10, height: 10)
            }
        }
    }

    // MARK: Amount

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            label("AMOUNT")
            HStack(alignment: .center) {
                Text("\(transaction.amountEth) ETH")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                securedBadge
            }
            Text(fiatText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var securedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill").font(.caption2)
            Text("Secured").font(.subheadline.weight(.medium))
        }
        .foregroundStyle(Color.brandTeal)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.brandTeal.opacity(0.12), in: Capsule())
    }

    // MARK: Seller / description

    private var sellerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("SELLER")
            HStack(spacing: 12) {
                Text(transaction.initials)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(transaction.avatarColor, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("0×7F3a...9E2b")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("DESCRIPTION")
            Text(details)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: Derived

    private var currentStep: Int {
        switch transaction.status {
        case .created: return 0
        case .funded: return 1
        case .send, .shipped, .disputed: return 2
        case .completed, .refunded: return 3
        }
    }

    private var statusTitle: String {
        switch transaction.status {
        case .send, .shipped: return "Sent"
        default: return transaction.status.label
        }
    }

    private var statusSubtitle: String {
        switch transaction.status {
        case .created: return "Escrow created. Waiting for the buyer to lock the funds."
        case .funded: return "Funds are locked. Waiting for the seller to ship the item."
        case .send, .shipped: return "The seller has shipped the item. Once it arrives, confirm receipt to release the funds."
        case .completed: return "The deal is complete. The funds were released to the seller."
        case .refunded: return "The funds were returned to the buyer."
        case .disputed: return "A dispute is under review by the arbiter."
        }
    }

    private var showsBuyerActions: Bool {
        transaction.status == .send || transaction.status == .shipped
    }

    private var fiatText: String {
        let eth = Double(transaction.amountEth) ?? 0
        let usd = eth * usdPerEth
        return "≈ $" + usd.formatted(.number.precision(.fractionLength(2)))
    }
}

#Preview {
    NavigationStack {
        TransactionDetailView(transaction: WalletTransaction.activeSamples[0])
    }
    .preferredColorScheme(.dark)
}
