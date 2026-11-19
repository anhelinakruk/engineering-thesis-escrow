//
//  SendView.swift
//  escrow
//
//  Sheet from the wallet home for a plain ETH transfer out of the wallet.
//  Same look as New transaction: amount card on top, then the recipient.
//

import SwiftUI

struct SendView: View {
    @EnvironmentObject private var vm: EscrowViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var recipient = ""
    @State private var confirming = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !amount.isEmpty && !recipient.isEmpty && !vm.isSending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    amountCard
                    recipientField
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(Color.appBackground)
            .navigationTitle("Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .tint(.brandTeal)
            .escrowErrorAlert(vm)
            .sheet(isPresented: $confirming) {
                ConfirmSheet(
                    icon: "arrow.up.circle",
                    title: "Send \(amount) ETH?",
                    message: "To \(recipient.shortAddress). Transfers can't be undone.",
                    confirmTitle: "Send",
                    sendsTransaction: true,
                    onConfirm: {
                        confirming = false
                        Task {
                            if await vm.transfer(to: recipient, amountEth: amount) { dismiss() }
                        }
                    },
                    onCancel: { confirming = false }
                )
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    focused = false
                    confirming = true
                } label: {
                    Text(vm.isSending ? "Sending…" : "Send")
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
                .opacity(canSend ? 1 : 0.5)
                .disabled(!canSend)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }

    private var amountCard: some View {
        VStack(spacing: 6) {
            Text("AMOUNT")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", text: $amount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .fixedSize()
                Text("ETH")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            Text("Available: \(ethText(vm.balanceWei)) ETH")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var recipientField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECIPIENT ADDRESS")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("0x…", text: $recipient)
                    .font(.callout.monospaced())
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                Button("Paste") {
                    recipient = UIPasteboard.general.string ?? recipient
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(14)
            .background(
                Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            // The field scrolls, so show the whole address once more to check.
            // One line, shrunk to fit: wrapping would let iOS hyphenate it.
            if !recipient.isEmpty {
                Text(recipient.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 4)
            }
        }
    }
}

#Preview {
    SendView()
        .environmentObject(EscrowViewModel())
        .preferredColorScheme(.dark)
}
