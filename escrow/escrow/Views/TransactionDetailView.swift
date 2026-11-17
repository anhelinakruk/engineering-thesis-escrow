//
//  TransactionDetailView.swift
//  escrow
//
//  Detail screen for a single escrow, pushed from the wallet list. Shows the
//  state-machine progress, amount and counterparty, plus the actions the
//  contract allows for this user's role in the current state.
//

import SwiftUI

/// A button the detail screen can show; every one maps to a contract call.
private struct DetailAction: Identifiable {
    let action: EscrowAction
    let title: String
    let confirmation: String
    var id: String { title }
}

struct TransactionDetailView: View {
    @EnvironmentObject private var vm: EscrowViewModel
    let escrow: Escrow

    private let steps = ["Created", "Funded", "Sent", "Completed"]

    @State private var showingInviteLink = false
    @State private var pendingAction: DetailAction?

    /// The list refreshes after every action; show the fresh copy when there is one.
    private var transaction: Escrow {
        vm.escrows.first { $0.id == escrow.id } ?? escrow
    }

    private var isBuyer: Bool { transaction.isBuyer(vm.myAddress) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statusCard
                amountCard
                counterpartySection
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(Color.appBackground)
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isBuyer && transaction.seller == nil && transaction.state == .funded {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInviteLink = true
                    } label: {
                        Image(systemName: "link")
                    }
                }
            }
        }
        .sheet(isPresented: $showingInviteLink) {
            JoinTransactionView(escrow: transaction)
        }
        .confirmationDialog(
            pendingAction?.title ?? "",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingAction
        ) { item in
            Button(item.title) {
                Task { await vm.perform(item.action, id: transaction.id) }
            }
        } message: { item in
            Text(item.confirmation)
        }
        .escrowErrorAlert(vm)
        .safeAreaInset(edge: .bottom) {
            if primaryAction != nil || secondaryAction != nil {
                VStack(spacing: 12) {
                    if let primary = primaryAction {
                        Button {
                            pendingAction = primary
                        } label: {
                            Text(vm.isSending ? "Sending…" : primary.title)
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
                    }

                    if let secondary = secondaryAction {
                        Button {
                            pendingAction = secondary
                        } label: {
                            Text(secondary.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(red: 0.90, green: 0.40, blue: 0.45))
                        }
                    }
                }
                .disabled(vm.isSending)
                .opacity(vm.isSending ? 0.6 : 1)
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
                Text("\(ethText(transaction.amountWei)) ETH")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                securedBadge
            }
            Text(fiatText(transaction.amountWei))
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

    // MARK: Counterparty

    private var counterpartySection: some View {
        let other = transaction.counterparty(of: vm.myAddress)
        return VStack(alignment: .leading, spacing: 10) {
            label(isBuyer ? "SELLER" : "BUYER")
            HStack(spacing: 12) {
                AddressAvatar(address: other)
                VStack(alignment: .leading, spacing: 2) {
                    Text(other?.shortAddress ?? "Waiting for the seller")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(other == nil ? "Share the invite link to let them join" : "Escrow #\(transaction.id)")
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

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: Derived

    private var currentStep: Int {
        switch transaction.state {
        case .created: return 0
        case .funded: return 1
        case .shipped, .disputed: return 2
        case .completed, .refunded: return 3
        }
    }

    private var statusTitle: String {
        transaction.state.label
    }

    private var statusSubtitle: String {
        switch transaction.state {
        case .created: return "Escrow created. Waiting for the buyer to lock the funds."
        case .funded where transaction.seller == nil: return "Funds are locked. Waiting for the seller to join."
        case .funded: return "Funds are locked. Waiting for the seller to ship the item."
        case .shipped: return "The seller has shipped the item. Once it arrives, confirm receipt to release the funds."
        case .completed: return "The deal is complete. The funds were released to the seller."
        case .refunded: return "The funds were returned to the buyer."
        case .disputed: return "A dispute is under review by the arbiter."
        }
    }

    private func passed(_ deadline: Date?) -> Bool {
        deadline.map { $0 <= .now } ?? false
    }

    /// Mirrors the contract's require() checks so only callable actions show up.
    private var primaryAction: DetailAction? {
        switch (transaction.state, isBuyer) {
        case (.funded, true) where transaction.seller == nil:
            return DetailAction(action: .cancel, title: "Cancel escrow",
                                confirmation: "Your funds will be returned to you for withdrawal.")
        case (.funded, true) where passed(transaction.shipDeadline):
            return DetailAction(action: .refundExpired, title: "Reclaim funds",
                                confirmation: "The seller missed the shipping deadline. Your funds will be returned to you.")
        case (.funded, false):
            return DetailAction(action: .markShipped, title: "Mark as shipped",
                                confirmation: "The buyer will have 7 days to confirm receipt.")
        case (.shipped, true):
            return DetailAction(action: .confirmReceipt, title: "Confirm receipt",
                                confirmation: "The funds will be released to the seller. This cannot be undone.")
        case (.shipped, false) where passed(transaction.confirmDeadline):
            return DetailAction(action: .autoComplete, title: "Release funds",
                                confirmation: "The buyer didn't confirm in time. The funds will be released to you.")
        default:
            return nil
        }
    }

    private var secondaryAction: DetailAction? {
        guard transaction.state == .shipped else { return nil }
        return DetailAction(action: .raiseDispute, title: "Report a dispute",
                            confirmation: "The arbiter will decide who receives the funds.")
    }
}

#Preview {
    NavigationStack {
        TransactionDetailView(escrow: Escrow(
            id: 7, buyer: "0x7F3a5b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e9E2b",
            seller: "0x4b2c5b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e11aF",
            amountWei: "820000000000000000", state: .shipped,
            shipDeadline: nil, confirmDeadline: nil
        ))
    }
    .environmentObject(EscrowViewModel())
    .preferredColorScheme(.dark)
}
