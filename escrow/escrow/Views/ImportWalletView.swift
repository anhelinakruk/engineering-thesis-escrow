//
//  ImportWalletView.swift
//  escrow
//
//  Onboarding path for "I already have a wallet": paste or type the 12-word
//  recovery phrase to restore the wallet. On import the flow continues to the
//  SIWE sign-in, same as creating a new wallet.
//

import SwiftUI
import UIKit

struct ImportWalletView: View {
    /// Restores the wallet from the entered phrase. Async so the view can show a
    /// spinner while the Rust layer derives the key and the SIWE message loads.
    var onImport: (String) async -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var phrase = ""
    @State private var isImporting = false
    @FocusState private var editorFocused: Bool

    /// Number of whitespace-separated words currently entered.
    private var wordCount: Int {
        phrase.split(whereSeparator: \.isWhitespace).count
    }

    /// BIP-39 phrases are 12 or 24 words.
    private var isValidCount: Bool {
        wordCount == 12 || wordCount == 24
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Type or paste the 12 words of your recovery phrase, separated by spaces.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("RECOVERY PHRASE")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        if let pasted = UIPasteboard.general.string {
                            phrase = pasted
                        }
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.brandTeal)
                    }
                }
                .padding(.top, 8)

                phraseEditor

                if wordCount > 0 && !isValidCount {
                    Text("Recovery phrases are 12 or 24 words — you have \(wordCount).")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

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
                .disabled(isImporting)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { editorFocused = false }
            }
        }
        .tint(.brandTeal)
        .safeAreaInset(edge: .bottom) { importButton }
    }

    private var phraseEditor: some View {
        TextEditor(text: $phrase)
            .font(.body)
            .foregroundStyle(.white)
            .scrollContentBackground(.hidden)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($editorFocused)
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

    private var importButton: some View {
        Button {
            editorFocused = false
            Task {
                isImporting = true
                await onImport(phrase)
                isImporting = false
            }
        } label: {
            HStack(spacing: 10) {
                if isImporting {
                    ProgressView().tint(.white)
                }
                Text(isImporting ? "Importing…" : "Import wallet")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
        }
        .background(
            Color.brandTeal,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .opacity(isValidCount && !isImporting ? 1 : 0.5)
        .disabled(!isValidCount || isImporting)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
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
