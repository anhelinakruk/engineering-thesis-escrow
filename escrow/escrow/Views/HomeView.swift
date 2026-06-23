//
//  HomeView.swift
//  escrow
//
//  The wallet home: balance, address, and the list of escrow transactions
//  split into active and history. Appearance only for now — everything is fed
//  by sample data; real values will come from the service layer later.
//

import SwiftUI
import UIKit

enum TxStatus {
    case send, created, funded, shipped, completed, refunded, disputed

    var label: String {
        switch self {
        case .send: return "Send"
        case .created: return "Created"
        case .funded: return "Funded"
        case .shipped: return "Shipped"
        case .completed: return "Completed"
        case .refunded: return "Refunded"
        case .disputed: return "Disputed"
        }
    }

    var color: Color {
        switch self {
        case .send, .completed: return Color(red: 0.36, green: 0.78, blue: 0.55)
        case .funded: return Color(red: 0.55, green: 0.45, blue: 0.90)
        case .created: return Color(red: 0.78, green: 0.62, blue: 0.45)
        case .shipped: return Color(red: 0.40, green: 0.60, blue: 0.90)
        case .refunded: return Color(red: 0.90, green: 0.40, blue: 0.45)
        case .disputed: return Color(red: 0.90, green: 0.62, blue: 0.30)
        }
    }
}

struct WalletTransaction: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let item: String
    let amountEth: String
    let initials: String
    let avatarColor: Color
    let status: TxStatus
}

extension WalletTransaction {
    static let activeSamples: [WalletTransaction] = [
        .init(name: "Anna Kowalska", item: "MacBook Pro 14", amountEth: "0.82",
              initials: "AK", avatarColor: Color(red: 0.30, green: 0.45, blue: 0.85), status: .send),
        .init(name: "Tomasz Wiśniewski", item: "iPhone 15 Pro", amountEth: "0.45",
              initials: "TW", avatarColor: Color(red: 0.52, green: 0.40, blue: 0.85), status: .funded),
        .init(name: "Marek Zieliński", item: "Concert tickets", amountEth: "0.12",
              initials: "MZ", avatarColor: Color(red: 0.35, green: 0.65, blue: 0.55), status: .created),
    ]

    static let historySamples: [WalletTransaction] = [
        .init(name: "Karolina Nowak", item: "Sony A7 camera", amountEth: "1.10",
              initials: "KN", avatarColor: Color(red: 0.60, green: 0.50, blue: 0.40), status: .completed),
        .init(name: "Piotr Lewandowski", item: "Mountain bike", amountEth: "0.30",
              initials: "PL", avatarColor: Color(red: 0.85, green: 0.35, blue: 0.65), status: .refunded),
    ]
}

struct HomeView: View {
    var onLogout: () -> Void = {}

    private let address = "0×7F3a...9E2b"
    @State private var didCopyAddress = false
    @State private var showingNewTransaction = false
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                balanceSection
                transactionSection(title: "ACTIVE", items: WalletTransaction.activeSamples)
                transactionSection(title: "HISTORY", items: WalletTransaction.historySamples)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(Color.appBackground)
        .navigationDestination(for: WalletTransaction.self) { tx in
            TransactionDetailView(transaction: tx)
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLogoutConfirm = true
                } label: {
                    Text("JK")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.brandTeal)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                        .overlay(Circle().stroke(Color.brandTeal, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
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
                    Text("2.4810")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                    Text("ETH")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Text("≈ $9,427.80")
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
            Text(address)
                .font(.callout)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = address
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

    private func transactionSection(title: String, items: [WalletTransaction]) -> some View {
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

    private func transactionRow(_ tx: WalletTransaction) -> some View {
        HStack(spacing: 12) {
            Text(tx.initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(tx.avatarColor, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(tx.item)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(tx.amountEth) ETH")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(tx.status.color)
                        .frame(width: 6, height: 6)
                    Text(tx.status.label)
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
    .preferredColorScheme(.dark)
}
