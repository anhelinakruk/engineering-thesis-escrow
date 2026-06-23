//
//  LogoutSheet.swift
//  escrow
//
//  On-brand confirmation before logging out. Replaces the system
//  confirmationDialog so it matches the app's dark / rounded styling.
//

import SwiftUI

struct LogoutSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private let danger = Color(red: 0.95, green: 0.45, blue: 0.45)

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(danger)
                .frame(width: 64, height: 64)
                .background(danger.opacity(0.12), in: Circle())
                .padding(.top, 12)

            Text("Log out of this wallet?")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Make sure you've saved your recovery phrase — it's the only way to restore this wallet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(action: onConfirm) {
                Text("Log out")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(danger, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}

#Preview {
    Color.appBackground
        .sheet(isPresented: .constant(true)) {
            LogoutSheet(onConfirm: {}, onCancel: {})
        }
        .preferredColorScheme(.dark)
}
