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
    /// Rust-backed wallet (AlloySwift via UniFFI). Use `MockWalletService()` in
    /// previews where the Rust framework / Keychain aren't available.
    private let wallet: WalletService = AlloyWalletService()
    private let auth = AuthService()

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
                        onContinue: enterApp
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
        Task {
            do {
                let mnemonic = try await wallet.createWallet()
                path.append(.recoveryPhrase(mnemonic))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Restores a wallet from a pasted/typed phrase and enters the app.
    private func importWallet(phrase: String) {
        Task {
            do {
                try await wallet.importWallet(phrase: phrase)
                hasWallet = true
                Task { await signIn() }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Enters the app immediately, then signs in to the backend in the
    /// background. SIWE login must never sit on the critical path — the wallet
    /// already exists on the device, so the user shouldn't wait for the server.
    private func enterApp() {
        hasWallet = true
        Task { await signIn() }
    }

    /// Best-effort SIWE login. `nonisolated` so the on-device signing and the
    /// network round-trip run off the main actor and never freeze the UI;
    /// failures are non-fatal (the wallet works locally regardless).
    private nonisolated func signIn() async {
        do {
            try await auth.login()
        } catch {
            print("SIWE login failed (continuing offline): \(error)")
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
