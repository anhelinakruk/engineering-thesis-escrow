//
//  RootView.swift
//  escrow
//
//  Top-level view. Observes `WalletViewModel` and renders the right screen for
//  the current state (restore splash -> lock -> home, or onboarding). It holds
//  only navigation (`path`); all state and logic live in the view-model.
//

import SwiftUI

/// Destinations reachable during onboarding. The recovery-phrase route carries
/// its mnemonic so the destination is built purely from the route value.
enum OnboardingRoute: Hashable {
    case recoveryPhrase(Mnemonic)
    case importWallet
}

struct RootView: View {
    @StateObject private var vm = WalletViewModel()
    @State private var path: [OnboardingRoute] = []

    var body: some View {
        Group {
            if vm.isRestoring {
                restoreSplash
            } else if vm.hasWallet && !vm.isUnlocked {
                LockView(
                    symbolName: vm.biometricSymbol,
                    typeLabel: vm.biometricLabel,
                    onUnlock: { Task { await vm.unlock() } }
                )
            } else if vm.hasWallet {
                NavigationStack {
                    HomeView(onLogout: {
                        vm.logout()
                        path = []
                    })
                }
            } else {
                onboarding
            }
        }
        .tint(.brandTeal)
        .preferredColorScheme(.dark)
        .task { vm.restoreSession() }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private var restoreSplash: some View {
        ProgressView()
            .tint(.brandTeal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground)
    }

    private var onboarding: some View {
        NavigationStack(path: $path) {
            WelcomeView(
                onCreate: {
                    Task {
                        if let mnemonic = await vm.createWallet() {
                            path.append(.recoveryPhrase(mnemonic))
                        }
                    }
                },
                onImport: { path.append(.importWallet) }
            )
            .navigationDestination(for: OnboardingRoute.self) { route in
                switch route {
                case .recoveryPhrase(let mnemonic):
                    RecoveryPhraseView(
                        mnemonic: mnemonic,
                        onContinue: { Task { await vm.prepareSignIn() } }
                    )
                    .navigationBarBackButtonHidden(true)
                case .importWallet:
                    ImportWalletView(onImport: vm.importWallet)
                        .navigationBarBackButtonHidden(true)
                }
            }
        }
        .sheet(isPresented: signingPresented) {
            if let message = vm.pendingSIWEMessage {
                SigningSheet(
                    message: message,
                    onSign: { try await vm.completeSignIn() },
                    onCancel: { vm.cancelSignIn() }
                )
            }
        }
    }

    private var signingPresented: Binding<Bool> {
        Binding(
            get: { vm.pendingSIWEMessage != nil },
            set: { if !$0 { vm.cancelSignIn() } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }
}

#Preview {
    RootView()
}
