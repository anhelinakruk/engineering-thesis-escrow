//
//  WalletViewModel.swift
//  escrow
//
//  MVVM view-model for onboarding, SIWE sign-in, session restore and the lock
//  screen. The views observe its @Published state and call its methods; all the
//  work happens here or in the injected services (which stay swappable behind
//  their protocols).
//

import Foundation
import Combine

@MainActor
final class WalletViewModel: ObservableObject {
    @Published var isRestoring = true
    @Published var hasWallet = false
    @Published var isUnlocked = false
    @Published var errorMessage: String?
    @Published var pendingSIWEMessage: String?

    private let wallet: WalletService
    private let auth: AuthService
    private let keychain: KeychainStore
    private let biometrics: BiometricAuthService

    init(
        wallet: WalletService = AlloyWalletService(),
        auth: AuthService = AuthService(),
        keychain: KeychainStore = KeychainStore(service: WalletKeychainKeys.service),
        biometrics: BiometricAuthService = .shared
    ) {
        self.wallet = wallet
        self.auth = auth
        self.keychain = keychain
        self.biometrics = biometrics
    }

    var biometricSymbol: String { biometrics.symbolName }
    var biometricLabel: String { biometrics.typeLabel }

    func restoreSession() {
        let hasStored = keychain.read(WalletKeychainKeys.mnemonic) != nil
            && keychain.read(WalletKeychainKeys.address) != nil
            && keychain.read(WalletKeychainKeys.token) != nil
        hasWallet = hasStored
        isUnlocked = !(hasStored && biometrics.canAuthenticate)
        isRestoring = false
    }

    func unlock() async {
        do {
            if try await biometrics.authenticate(reason: "Unlock your wallet") {
                isUnlocked = true
            }
        } catch {
            // TODO
        }
    }

    func logout() {
        keychain.delete(WalletKeychainKeys.mnemonic)
        keychain.delete(WalletKeychainKeys.address)
        keychain.delete(WalletKeychainKeys.token)
        pendingSIWEMessage = nil
        isUnlocked = false
        hasWallet = false
    }

    func createWallet() async -> Mnemonic? {
        do {
            return try await wallet.createWallet()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func importWallet(phrase: String) async {
        do {
            try await wallet.importWallet(phrase: phrase)
            await prepareSignIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareSignIn() async {
        do {
            pendingSIWEMessage = try await auth.prepareSIWEMessage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeSignIn() async throws {
        guard let message = pendingSIWEMessage else { return }
        _ = try await auth.completeLogin(message: message)
        pendingSIWEMessage = nil
        isUnlocked = true
        hasWallet = true
    }

    func cancelSignIn() {
        pendingSIWEMessage = nil
    }
}
