//
//  RootView.swift
//  escrow
//
//  Owns the app's top-level navigation. Until a wallet exists it drives the
//  onboarding (Welcome -> Recovery phrase / Import -> SIWE sign-in); once the
//  user has signed in it shows the wallet home. The services that do the work
//  are injected here so the screens stay free of them.
//

import SwiftUI

/// Destinations reachable during onboarding. The recovery-phrase route carries
/// its mnemonic so the destination is built purely from the route value.
enum OnboardingRoute: Hashable {
    case recoveryPhrase(Mnemonic)
    case importWallet
}

struct RootView: View {
    /// Rust-backed wallet (AlloySwift via UniFFI).
    private let wallet: WalletService = AlloyWalletService()
    private let auth = AuthService()

    @State private var hasWallet = false
    @State private var path: [OnboardingRoute] = []
    @State private var errorMessage: String?
    @State private var siwePrompt: SIWEPrompt?

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
                    RecoveryPhraseView(mnemonic: mnemonic, onContinue: presentSignIn)
                        .navigationBarBackButtonHidden(true)
                case .importWallet:
                    ImportWalletView(onImport: importWallet)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
        .sheet(item: $siwePrompt) { prompt in
            SigningSheet(
                message: prompt.message,
                onSign: { try await completeSignIn(message: prompt.message) },
                onCancel: { siwePrompt = nil }
            )
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

    /// Restores a wallet from a phrase, then moves on to the SIWE sign-in.
    private func importWallet(phrase: String) {
        Task {
            do {
                try await wallet.importWallet(phrase: phrase)
                presentSignIn()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Fetches a nonce, builds the SIWE message, and presents the signing sheet.
    private func presentSignIn() {
        Task {
            do {
                let message = try await auth.prepareSIWEMessage()
                siwePrompt = SIWEPrompt(message: message)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Signs + verifies the SIWE message; on success enters the app. Throwing
    /// propagates to `SigningSheet` so it can show the failure and allow a retry.
    private func completeSignIn(message: String) async throws {
        _ = try await auth.completeLogin(message: message)
        siwePrompt = nil
        hasWallet = true
    }

    private var showingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

/// Wraps the SIWE message so it can drive `.sheet(item:)`.
private struct SIWEPrompt: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    RootView()
}
