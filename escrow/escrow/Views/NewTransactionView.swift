//
//  NewTransactionView.swift
//  escrow
//
//  Presented as a sheet from the wallet home. The buyer sets an amount and an
//  optional description, then locks the funds into a new escrow. Once it is
//  on-chain the sheet turns into the invite preview, ready to share.
//

import SwiftUI

struct NewTransactionView: View {
    @EnvironmentObject private var vm: EscrowViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var created: Escrow?
    @State private var amount = ""
    @State private var details = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case amount, details
    }

    var body: some View {
        if let created {
            NavigationStack {
                JoinTransactionView(escrow: created)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        } else {
            form
        }
    }

    private var form: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    amountCard
                    descriptionField
                    safetyBanner
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(Color.appBackground)
            .navigationTitle("New transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .tint(.brandTeal)
            .escrowErrorAlert(vm)
            .safeAreaInset(edge: .bottom) {
                Button {
                    focusedField = nil
                    Task {
                        guard let id = await vm.createEscrow(amountEth: amount, description: details) else { return }
                        created = await vm.escrow(id: id)
                        if created == nil { dismiss() }
                    }
                } label: {
                    Text(vm.isSending ? "Locking funds…" : "Create & lock funds")
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
                .opacity(amount.isEmpty || vm.isSending ? 0.5 : 1)
                .disabled(amount.isEmpty || vm.isSending)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    private var amountCard: some View {
        VStack(spacing: 6) {
            Text("TRANSACTION AMOUNT")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", text: $amount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($focusedField, equals: .amount)
                    .fixedSize()
                Text("ETH")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }

        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        // The amount field is small; let a tap anywhere on the card focus it.
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .amount }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DESCRIPTION / TERMS (OPTIONAL)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if details.isEmpty {
                    Text("e.g. MacBook Pro 14, 2023, excellent condition. Local pickup, Warsaw — Mokotów.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.horizontal, 5)
                }
                TextEditor(text: $details)
                    .font(.body)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .focused($focusedField, equals: .details)
                    // The backend rejects longer terms; stop typing at the limit instead.
                    .onChange(of: details) { _, new in
                        if new.count > 500 { details = String(new.prefix(500)) }
                    }
            }
            .padding(12)
            .background(
                Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
    }

    private var safetyBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.brandTeal)
                Text("Your funds stay safe")
                    .font(.headline)
                    .foregroundStyle(Color.brandTeal)
            }
            Text("Your ETH will be locked in a smart contract. If the seller doesn't join or ship in time, you can take it back.")
                .font(.subheadline)
                .foregroundStyle(.white)
            Label(networkFeeNote, systemImage: "fuelpump")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
    NewTransactionView()
        .environmentObject(EscrowViewModel())
        .preferredColorScheme(.dark)
}
