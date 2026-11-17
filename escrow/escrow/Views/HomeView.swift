//
//  HomeView.swift
//  escrow
//
//  The wallet home: balance, address, and the list of escrow transactions
//  split into active and history, all read from the chain.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var vm: EscrowViewModel
    var onLogout: () -> Void = {}

    @State private var didCopyAddress = false
    @State private var showingNewTransaction = false
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                balanceSection
                if vm.escrows.isEmpty {
                    emptyState
                }
                if !vm.active.isEmpty {
                    transactionSection(title: "ACTIVE", items: vm.active)
                }
                if !vm.history.isEmpty {
                    transactionSection(title: "HISTORY", items: vm.history)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(Color.appBackground)
        .refreshable { await vm.refresh() }
        .task { await vm.refresh() }
        .navigationDestination(for: Escrow.self) { escrow in
            TransactionDetailView(escrow: escrow)
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLogoutConfirm = true
                } label: {
                    Text(String(vm.myAddress.dropFirst(2).prefix(2)).uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandTeal)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.brandTeal, lineWidth: 1.5))
                }
                .buttonBorderShape(.circle)
            }
        }
        .tint(.brandTeal)
        .safeAreaInset(edge: .bottom) {
            Button {
                showingNewTransaction = true
            } label: {
                Label("New transaction", systemImage: "plus")
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
        .sheet(isPresented: $showingNewTransaction) {
            NewTransactionView()
        }
        .sheet(item: $vm.invite) { escrow in
            JoinTransactionView(escrow: escrow, onJoin: {
                if await vm.perform(.join, id: escrow.id) {
                    vm.invite = nil
                }
            })
            .escrowErrorAlert(vm)
        }
        .escrowErrorAlert(vm)
        .sheet(isPresented: $showLogoutConfirm) {
            LogoutSheet(
                onConfirm: {
                    showLogoutConfirm = false
                    onLogout()
                },
                onCancel: { showLogoutConfirm = false }
            )
        }
    }

    // MARK: Balance

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("BALANCE")

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(ethText(vm.balanceWei))
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                    Text("ETH")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Text(fiatText(vm.balanceWei))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                addressPill
                    .padding(.top, 6)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
    }

    private var addressPill: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 0.36, green: 0.78, blue: 0.55))
                .frame(width: 8, height: 8)
            Text(vm.myAddress.shortAddress)
                .font(.callout)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = vm.myAddress
                withAnimation { didCopyAddress = true }
            } label: {
                Label(didCopyAddress ? "Copied" : "Copy",
                      systemImage: didCopyAddress ? "checkmark" : "doc.on.doc")
                    .font(.subheadline)
                    .foregroundStyle(Color.brandTeal)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            Color.brandTeal.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.brandTeal.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: Transactions

    private var emptyState: some View {
        Text(vm.isLoading ? "Loading…" : "No transactions yet. Create one and share the link with the seller.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private func transactionSection(title: String, items: [Escrow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, tx in
                    NavigationLink(value: tx) {
                        transactionRow(tx)
                    }
                    .buttonStyle(.plain)
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.leading, 56)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(
                Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
    }

    private func transactionRow(_ tx: Escrow) -> some View {
        let counterparty = tx.counterparty(of: vm.myAddress)
        return HStack(spacing: 12) {
            AddressAvatar(address: counterparty)

            VStack(alignment: .leading, spacing: 2) {
                Text(counterparty?.shortAddress ?? "Waiting for seller")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Escrow #\(tx.id) · \(tx.isBuyer(vm.myAddress) ? "Buying" : "Selling")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(ethText(tx.amountWei)) ETH")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(tx.state.color)
                        .frame(width: 6, height: 6)
                    Text(tx.state.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 14)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environmentObject(EscrowViewModel())
    .preferredColorScheme(.dark)
}
