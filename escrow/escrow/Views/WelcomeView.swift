//
//  WelcomeView.swift
//  escrow
//
//  First-run onboarding screen: branding plus the two ways in —
//  create a fresh wallet or import an existing one.
//

import SwiftUI

struct WelcomeView: View {
    /// Called when the user chooses to create a brand-new wallet.
    var onCreate: () -> Void = {}
    /// Called when the user already has a wallet to import.
    var onImport: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        Color.brandTeal,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )

                Text("Escrow Ethereum")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("A secure wallet and escrow in one. Your funds, under your control — always on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onCreate) {
                    Text("Create a new wallet")
                        .primaryActionLabel()
                }
                .background(
                    Color.brandTeal,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

                Button(action: onImport) {
                    Text("I already have a wallet")
                        .primaryActionLabel()
                }
                .background(
                    Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }
}

/// Shared look for full-width pill buttons on this screen.
private extension Text {
    func primaryActionLabel() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
    }
}

extension Color {
    /// Brand accent — the teal used for the logo tile and primary button.
    static let brandTeal = Color(red: 0.30, green: 0.70, blue: 0.63)
    /// Near-black app background.
    static let appBackground = Color(red: 0.05, green: 0.05, blue: 0.06)
}

#Preview {
    WelcomeView()
        .preferredColorScheme(.dark)
}
