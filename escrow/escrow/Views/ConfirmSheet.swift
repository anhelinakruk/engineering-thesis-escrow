//
//  ConfirmSheet.swift
//  escrow
//
//  On-brand confirmation before an action that can't be undone (an escrow
//  action, a transfer, logging out). Replaces the system confirmationDialog,
//  which on iOS 26 is a small popover that undersells what is at stake.
//

import SwiftUI

struct ConfirmSheet: View {
    let icon: String
    let title: String
    let message: String
    let confirmTitle: String
    var isDestructive = false
    /// Actions that send a transaction state the fee up front (NFR11).
    var sendsTransaction = false
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// Measured content height; the sheet is exactly as tall as what it shows.
    @State private var height: CGFloat = 420

    private var tint: Color {
        isDestructive ? Color(red: 0.95, green: 0.45, blue: 0.45) : .brandTeal
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.12), in: Circle())
                .padding(.top, 12)

            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if sendsTransaction {
                Label(networkFeeNote, systemImage: "fuelpump")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(action: onConfirm) {
                Text(confirmTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 8)

            Button(action: onCancel) {
                Text("Cancel")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(
                Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}

#Preview {
    Color.appBackground
        .sheet(isPresented: .constant(true)) {
            ConfirmSheet(
                icon: "checkmark.seal",
                title: "Confirm receipt?",
                message: "The funds go to the seller. This can't be undone.",
                confirmTitle: "Confirm receipt",
                sendsTransaction: true,
                onConfirm: {},
                onCancel: {}
            )
        }
        .preferredColorScheme(.dark)
}
