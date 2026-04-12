//
//  UserManager.swift
//  Scanner
//
//  VIP / subscription state persisted locally and synced with StoreKit.
//

import Foundation
import StoreKit

extension Notification.Name {
    static let userVIPStatusDidChange = Notification.Name("scanner.user.vipStatusDidChange")
}

@MainActor
final class UserManager {

    static let shared = UserManager()

    /// Kept compatible with existing `VIPViewController` storage.
    private let vipExpireDateKey = "vip_expire_date"

    private(set) var vipExpirationDate: Date?

    var isVIP: Bool {
        guard let date = vipExpirationDate else { return false }
        return date > Date()
    }

    private init() {
        vipExpirationDate = UserDefaults.standard.object(forKey: vipExpireDateKey) as? Date
    }

    func refreshVIPStatus() async {
        do {
            try await ApplePayManager.shared.refreshEntitlementsFromStore()
        } catch {
            Logger.shared.log("VIP refresh failed: \(error)", level: .error)
        }
    }

    /// Called after a verified subscription transaction (purchase or update stream).
    func applyVerifiedTransaction(_ transaction: Transaction) async {
        guard transaction.productType == .autoRenewable else { return }
        if transaction.revocationDate != nil {
            await refreshVIPStatus()
            return
        }
        if let newExp = transaction.expirationDate {
            let merged = max(vipExpirationDate ?? .distantPast, newExp)
            persistExpiration(merged)
        } else {
            // Rare: subscription without `expirationDate` on the transaction; re-scan entitlements.
            await refreshVIPStatus()
        }
    }

    /// After purchase or restore, entitlements can lag briefly; re-read StoreKit if still non-VIP.
    func syncVIPAfterStoreOperation() async {
        if isVIP { return }
        await refreshVIPStatus()
        guard !isVIP else { return }
        try? await Task.sleep(nanoseconds: 600_000_000)
        await refreshVIPStatus()
    }

    /// Sets VIP expiry from StoreKit entitlement scan (restore / sync). `nil` clears VIP.
    func applySubscriptionExpiration(_ expiration: Date?) async {
        persistExpiration(expiration)
    }

    private func persistExpiration(_ date: Date?) {
        vipExpirationDate = date
        if let date {
            UserDefaults.standard.set(date, forKey: vipExpireDateKey)
        } else {
            UserDefaults.standard.removeObject(forKey: vipExpireDateKey)
        }
        NotificationCenter.default.post(name: .userVIPStatusDidChange, object: nil)
    }
}
