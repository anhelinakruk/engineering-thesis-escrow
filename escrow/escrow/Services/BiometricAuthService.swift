//
//  BiometricAuthService.swift
//  escrow
//
//  Unlocks the wallet with Face ID / Touch ID, falling back to the device
//  passcode. Used to gate a restored session on app launch so a stored wallet
//  isn't accessible to whoever just picks up the phone.
//

import Foundation
import LocalAuthentication

final class BiometricAuthService {
    static let shared = BiometricAuthService()
    private init() {}

    enum BiometricType { case faceID, touchID, none }

    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    var typeLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "your passcode"
        }
    }

    var symbolName: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.fill"
        }
    }

    var canAuthenticate: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    @discardableResult
    func authenticate(reason: String = "Unlock your wallet") async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        )
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: true)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
