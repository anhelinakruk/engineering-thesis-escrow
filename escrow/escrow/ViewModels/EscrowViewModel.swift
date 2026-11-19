//
//  EscrowViewModel.swift
//  escrow
//
//  MVVM view-model for everything after sign-in: wallet balance, the escrow
//  list, and every escrow action. Each write is followed by a refresh, so the
//  screens always show what the contract says, not a local guess.
//

import Foundation
import Combine

@MainActor
final class EscrowViewModel: ObservableObject {
    @Published var escrows: [Escrow] = []
    @Published var balanceWei = "0"
    @Published var pendingWithdrawalWei = "0"
    @Published var isLoading = false
    /// True while a transaction is being sent; screens disable their buttons.
    @Published var isSending = false
    @Published var errorMessage: String?
    /// Escrow opened from an `escrow://join/<id>` link, shown as the join sheet.
    @Published var invite: Escrow?

    private let service: EscrowService

    init(service: EscrowService = AlloyEscrowService()) {
        self.service = service
    }

    var myAddress: EthAddress { service.myAddress }

    var active: [Escrow] {
        escrows.filter { [.created, .funded, .shipped, .disputed].contains($0.state) }
    }

    var history: [Escrow] {
        escrows.filter { [.completed, .refunded].contains($0.state) }
    }

    /// `silent` is for background polling: a dropped connection shouldn't pop
    /// an alert every few seconds; the next manual refresh reports it.
    func refresh(silent: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let list = service.listEscrows()
            async let balance = service.balanceWei()
            async let pending = service.pendingWithdrawalWei()
            let fresh = try await (list, balance, pending)
            // A cancelled refresh may have lost its backend call (descriptions)
            // while the chain read finished; don't publish that half result.
            guard !Task.isCancelled else { return }
            (escrows, balanceWei, pendingWithdrawalWei) = fresh
        } catch {
            if !silent { errorMessage = error.localizedDescription }
        }
    }

    /// Keeps the signed-in screens (Home and Detail) in sync with the chain,
    /// so the other party's actions show up without a manual refresh. Ends
    /// when the owning task is cancelled (lock, logout).
    // ponytail: polling; switch to contract event subscriptions if 15 s lag matters.
    func keepRefreshing(every seconds: Double = 15) async {
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(seconds))
            await refresh(silent: true)
        }
    }

    func escrow(id: UInt64, inviteKey: String? = nil) async -> Escrow? {
        do {
            return try await service.escrow(id: id, inviteKey: inviteKey)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Handles `escrow://join/<id>?k=<invite key>`; anything else is ignored.
    func open(_ url: URL) async {
        guard url.scheme == "escrow", url.host == "join",
              let id = UInt64(url.lastPathComponent)
        else { return }
        let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "k" }?.value
        invite = await escrow(id: id, inviteKey: key)
    }

    /// Returns the new escrow's id, or nil if it failed (errorMessage is set).
    /// A failed description save doesn't undo the escrow: the funds are
    /// already locked, so the user gets the id plus a warning.
    func createEscrow(amountEth: String, description: String) async -> UInt64? {
        guard let wei = Wei.from(eth: amountEth) else {
            errorMessage = EscrowError.invalidAmount.localizedDescription
            return nil
        }
        let terms = description.trimmingCharacters(in: .whitespacesAndNewlines)
        var descriptionError: Error?
        let id = await send {
            let id = try await service.createEscrow(amountWei: wei)
            if !terms.isEmpty {
                do {
                    try await service.saveDescription(terms, escrowId: id)
                } catch {
                    descriptionError = error
                }
            }
            return id
        }
        if let descriptionError {
            errorMessage = "Escrow created, but its description couldn't be saved: \(descriptionError.localizedDescription)"
        }
        return id
    }

    /// Returns true on success.
    @discardableResult
    func perform(_ action: EscrowAction, id: UInt64) async -> Bool {
        await send { try await service.perform(action, id: id) } != nil
    }

    @discardableResult
    func withdraw() async -> Bool {
        await send { try await service.withdraw() } != nil
    }

    @discardableResult
    func transfer(to address: String, amountEth: String) async -> Bool {
        guard let wei = Wei.from(eth: amountEth) else {
            errorMessage = EscrowError.invalidAmount.localizedDescription
            return false
        }
        let to = address.trimmingCharacters(in: .whitespacesAndNewlines)
        return await send { try await service.transfer(to: to, amountWei: wei) } != nil
    }

    private func send<T>(_ work: () async throws -> T) async -> T? {
        isSending = true
        defer { isSending = false }
        do {
            let result = try await work()
            await refresh()
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
