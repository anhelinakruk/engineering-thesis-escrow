//
//  RootView.swift
//  escrow
//
//  Owns the app's top-level navigation. Until a wallet exists it drives the
//  onboarding (Welcome -> Recovery phrase / Import); once a wallet is set up it
//  shows the wallet home. The service that does the work is injected here so the
//  screens stay free of it.
//

import SwiftUI

/// Destinations reachable during onboarding. The recovery-phrase route carries
/// its mnemonic so the destination is built purely from the route value — no
/// reliance on separate state that may not be ready when navigation evaluates.
enum OnboardingRoute: Hashable {
    case recoveryPhrase(Mnemonic)
    case importWallet
}

struct RootView: View {
    /// Swap this for the Rust-backed implementation once UniFFI is wired.
    private let wallet: WalletService = MockWalletService()

    @State private var hasWallet = false
    @State private var path: [OnboardingRoute] = []
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if hasWallet {
                NavigationStack {
                    HomeView()
                }
            } else {
                onboarding
            }
        }
        .tint(.brandTeal)
        .preferredColorScheme(.dark)
        .alert("Something went wrong", isPresented: showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var onboarding: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onCreate: createWallet,
                onImport: { path.append(.importWallet) }
            )
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .recoveryPhrase(let mnemonic):
                    RecoveryPhraseView(
                        mnemonic: mnemonic,
                        onContinue: { hasWallet = true }
                    )
                    .navigationBarBackButtonHidden(true)
                case .importWallet:
                    ImportWalletView(onImport: importWallet)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
    }

    /// Generates a wallet and advances to the recovery-phrase screen.
    private func createWallet() {
        do {
            let mnemonic = try wallet.createWallet()
            path.append(.recoveryPhrase(mnemonic))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Restores a wallet from a pasted/typed phrase and enters the app.
    private func importWallet(phrase: String) {
        do {
            try wallet.importWallet(phrase: phrase)
            hasWallet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Drives the error alert off `errorMessage` without a second flag.
    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

#Preview {
    RootView()
}
