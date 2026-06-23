//
//  SigningSheet.swift
//  escrow
//
//  Explicit consent step for Sign-In with Ethereum. Shows the exact message the
//  wallet is about to sign before any signing happens. Signing proves the user
//  controls the address; it never moves funds and costs no gas. The actual
//  sign + verify is delegated to the caller via `onSign`.
//

import SwiftUI

struct SigningSheet: View {
    let message: String
    let onSign: () async throws -> Void
    let onCancel: () -> Void

    @State private var isSigning = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    infoBanner
                    messageCard
                    if let errorText {
                        errorBox(errorText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .background(Color.appBackground)
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSigning)
                }
            }
            .tint(.brandTeal)
            .interactiveDismissDisabled(isSigning)
            .safeAreaInset(edge: .bottom) { signButton }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "signature")
                .font(.largeTitle)
                .foregroundStyle(Color.brandTeal)
            Text("Verify your wallet")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Sign this message to prove you own this wallet and sign in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(icon: "checkmark.shield.fill", text: "Proves you control this address")
            row(icon: "lock.fill", text: "Does not move or touch your funds")
            row(icon: "bolt.fill", text: "Free. No gas, no transaction")
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

    private func row(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandTeal)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MESSAGE")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func errorBox(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                Color.red.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }

    private var signButton: some View {
        Button {
            Task {
                isSigning = true
                errorText = nil
                do {
                    try await onSign()
                } catch {
                    errorText = error.localizedDescription
                    isSigning = false
                }
            }
        } label: {
            HStack(spacing: 10) {
                if isSigning {
                    ProgressView().tint(.white)
                }
                Text(isSigning ? "Signing…" : "Sign & continue")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
        }
        .background(
            Color.brandTeal,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: Color.brandTeal.opacity(0.4), radius: 16, y: 4)
        .opacity(isSigning ? 0.7 : 1)
        .disabled(isSigning)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

#Preview {
    SigningSheet(
        message: """
        localhost wants you to sign in with your Ethereum account:
        0x7F3a9E2b...

        Sign in to Escrow

        URI: http://localhost:3000
        Version: 1
        Chain ID: 11155111
        Nonce: kMK2VHgfR81wdofUZ
        """,
        onSign: {},
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
