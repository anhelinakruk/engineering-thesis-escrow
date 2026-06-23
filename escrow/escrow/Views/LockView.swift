//
//  LockView.swift
//  escrow
//
//  Shown over the wallet when a stored session is restored on launch. Prompts
//  Face ID / Touch ID automatically; the button re-tries if the user cancels.
//

import SwiftUI

struct LockView: View {
    let symbolName: String
    let typeLabel: String
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: symbolName)
                .font(.system(size: 56))
                .foregroundStyle(Color.brandTeal)
            Text("Wallet locked")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("Unlock with \(typeLabel) to access your wallet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button(action: onUnlock) {
                Label("Unlock", systemImage: symbolName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
            }
            .background(
                Color.brandTeal,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .task { onUnlock() }
    }
}

#Preview {
    LockView(symbolName: "faceid", typeLabel: "Face ID", onUnlock: {})
        .preferredColorScheme(.dark)
}
