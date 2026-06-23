//
//  RecoveryPhraseView.swift
//  escrow
//
//  Step 2 of wallet creation: show the 12-word recovery phrase and make the
//  user acknowledge they saved it before continuing.
//

import SwiftUI
import UIKit

struct RecoveryPhraseView: View {
    let mnemonic: Mnemonic
    /// Called when the user confirms they saved the phrase.
    var onContinue: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Write down these 12 words in the exact order. This is your key to the wallet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(mnemonic.words.enumerated()), id: \.offset) { index, word in
                        wordChip(number: index + 1, word: word)
                    }
                }

                copyButton

                warningBanner
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(Color.appBackground)
        .navigationTitle("Recovery phrase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                }
            }
        }
        .tint(.brandTeal)
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("I've saved")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
            }
            .background(
                Color.brandTeal,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private func wordChip(number: Int, word: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .leading)
            Text(word)
                .font(.body)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            Color.white.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var copyButton: some View {
        Button {
            UIPasteboard.general.string = mnemonic.phrase
            withAnimation { didCopy = true }
        } label: {
            Label(didCopy ? "Copied" : "Copy",
                  systemImage: didCopy ? "checkmark" : "doc.on.doc")
                .font(.headline)
                .foregroundStyle(Color.brandTeal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background(
            Color.white.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var warningBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(.orange)
            Text("Save these words somewhere safe. This is the only way to recover your wallet. Never share them with anyone.")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
        .padding(14)
        .background(
            Color.orange.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

#Preview {
    NavigationStack {
        RecoveryPhraseView(mnemonic: Mnemonic(words: [
            "ocean", "target", "lemon", "puzzle", "garden", "velvet",
            "ridge", "comfort", "anchor", "sunny", "marble", "falcon",
        ]))
    }
    .preferredColorScheme(.dark)
}
