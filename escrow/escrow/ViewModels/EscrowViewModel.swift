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

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let list = service.listEscrows()
            async let balance = service.balanceWei()
            async let pending = service.pendingWithdrawalWei()
            (escrows, balanceWei, pendingWithdrawalWei) = try await (list, balance, pending)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func escrow(id: UInt64) async -> Escrow? {
        do {
            return try await service.escrow(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Handles `escrow://join/<id>`; anything else is ignored.
    func open(_ url: URL) async {
        guard url.scheme == "escrow", url.host == "join",
              let id = UInt64(url.lastPathComponent)
        else { return }
        invite = await escrow(id: id)
    }

    /// Returns the new escrow's id, or nil if it failed (errorMessage is set).
    func createEscrow(amountEth: String) async -> UInt64? {
        guard let wei = Wei.from(eth: amountEth) else {
            errorMessage = EscrowError.invalidAmount.localizedDescription
            return nil
        }
        return await send { try await service.createEscrow(amountWei: wei) }
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
