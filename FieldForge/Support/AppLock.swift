import LocalAuthentication
import SwiftUI

/// On-device lock. The preference lives in this app’s user defaults and never leaves the phone.
@MainActor
@Observable
final class AppLock {
    private enum Key {
        static let enabled = "fieldforge.lock.enabled"
    }

    /// Brief trips to another app stay unlocked. A real background past this asks again.
    private let grace: TimeInterval = 60
    private var backgroundedAt: Date?
    private var authenticating = false
    private var unlockInFlight = false

    var isEnabled: Bool
    var isLocked: Bool
    var failureMessage: String?

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Key.enabled)
        isEnabled = enabled
        isLocked = enabled
    }

    /// Turns the lock on only after a successful Face ID, Touch ID, or passcode check.
    func setEnabled(_ enabled: Bool) async -> String? {
        if enabled == false {
            UserDefaults.standard.set(false, forKey: Key.enabled)
            isEnabled = false
            isLocked = false
            failureMessage = nil
            backgroundedAt = nil
            return nil
        }
        var policyError: NSError?
        guard LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            isEnabled = false
            isLocked = false
            return Self.message(for: policyError) ?? "Turn on a passcode for this iPhone, then try App Lock again."
        }
        let result = await authenticate(reason: "Lock FieldForge when you leave it.")
        guard result.success else {
            isEnabled = false
            isLocked = false
            return result.message ?? "App Lock stayed off."
        }
        UserDefaults.standard.set(true, forKey: Key.enabled)
        isEnabled = true
        isLocked = false
        failureMessage = nil
        backgroundedAt = nil
        return nil
    }

    func unlock() async {
        guard unlockInFlight == false else { return }
        unlockInFlight = true
        defer { unlockInFlight = false }
        let result = await authenticate(reason: "Unlock FieldForge.")
        if result.success {
            isLocked = false
            failureMessage = nil
            backgroundedAt = nil
        } else if result.passcodeMissing {
            UserDefaults.standard.set(false, forKey: Key.enabled)
            isEnabled = false
            isLocked = false
            failureMessage = nil
            backgroundedAt = nil
        } else {
            isLocked = true
            failureMessage = result.message ?? "Tap Unlock to use Face ID, Touch ID, or the passcode."
        }
    }

    func sceneChanged(_ phase: ScenePhase) {
        guard isEnabled else {
            isLocked = false
            return
        }
        switch phase {
        case .background:
            if authenticating == false {
                backgroundedAt = .now
            }
        case .active:
            guard authenticating == false, let backgroundedAt else { return }
            if Date.now.timeIntervalSince(backgroundedAt) >= grace {
                isLocked = true
            }
            self.backgroundedAt = nil
        default:
            break
        }
    }

    private struct AuthResult {
        var success: Bool
        var message: String?
        var passcodeMissing: Bool
    }

    private func authenticate(reason: String) async -> AuthResult {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        authenticating = true
        defer { authenticating = false }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                let code = (error as? LAError)?.code
                let result = AuthResult(
                    success: success,
                    message: success ? nil : Self.message(for: code, fallback: error != nil),
                    passcodeMissing: code == .passcodeNotSet
                )
                continuation.resume(returning: result)
            }
        }
    }

    private static func message(for error: Error?) -> String? {
        message(for: (error as? LAError)?.code, fallback: error != nil)
    }

    private static func message(for code: LAError.Code?, fallback: Bool) -> String? {
        switch code {
        case .userCancel, .appCancel, .systemCancel, .userFallback:
            return nil
        case .passcodeNotSet:
            return "Turn on a passcode for this iPhone, then try App Lock again."
        case .biometryNotEnrolled, .biometryNotAvailable:
            return "Use the device passcode to unlock FieldForge."
        case .biometryLockout:
            return "Face ID is locked. Use the passcode to unlock FieldForge."
        default:
            return fallback ? "FieldForge stayed locked." : nil
        }
    }
}
