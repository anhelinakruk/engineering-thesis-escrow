//
//  ImportWalletView.swift
//  escrow
//
//  Onboarding path for "I already have a wallet": paste or type the 12-word
//  recovery phrase to restore the wallet.
//

import SwiftUI

struct ImportWalletView: View {
    /// Called with the entered phrase when the user taps Import.
    var onImport: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var phrase = ""

    /// Number of whitespace-separated words currently entered.
    private var wordCount: Int {
        phrase.split(whereSeparator: \.isWhitespace).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Type or paste the 12 words of your recovery phrase, separated by spaces.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("RECOVERY PHRASE")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                phraseEditor

                footnote
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .background(Color.appBackground)
        .navigationTitle("Import wallet")
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
            Button {
                onImport(phrase)
            } label: {
                Text("Import wallet")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
            }
            .background(
                Color.brandTeal,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .opacity(wordCount == 0 ? 0.5 : 1)
            .disabled(wordCount == 0)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
    }

    private var phraseEditor: some View {
        TextEditor(text: $phrase)
            .font(.body)
            .foregroundStyle(.white)
            .scrollContentBackground(.hidden)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .frame(minHeight: 160)
            .padding(12)
            .background(
                Color.white.opacity(0.03),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.brandTeal, lineWidth: 1)
            )
    }

    private var footnote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Your phrase is stored only on this device. It never leaves your phone and is never sent to any server.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ImportWalletView()
    }
    .preferredColorScheme(.dark)
}
