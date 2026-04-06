//
//  AESCryptoHelper.swift
//  Scanner
//

import Foundation
import CryptoSwift
import UIKit

final class AESCryptoHelper {

    static let shared = AESCryptoHelper()
    private init() {}

    // MARK: - User ID (Keychain-persisted device identifier)

    var userid: String {
        if let stored = KeychainHelper.get(key: kKeychainUserIDKey) {
            return stored
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        KeychainHelper.set(key: kKeychainUserIDKey, value: id)
        return id
    }

    // MARK: - UID (random 10-digit string, regenerated per request)

    func generateUID() -> String {
        return (0..<10).map { _ in String(Int.random(in: 0...9)) }.joined()
    }

    // MARK: - Common Parameters

    func commonParams() -> [String: Any] {
        return [
            "userid": userid,
            "appid": kBundleID,
            "network": NetworkStatusMonitor.shared.statusCode,
            "version": appVersion,
            "osversion": UIDevice.current.systemVersion
        ]
    }

    func encryptedCommonParams() -> [String: Any] {
        var params = commonParams()
        params["uid"] = generateUID()
        return params
    }

    // MARK: - Sign Generation

    func generateSign(params: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: params, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.shared.log("Failed to serialize params to JSON", level: .error)
            return nil
        }
        return encrypt(jsonString)
    }

    // MARK: - AES-CFB Encrypt

    func encrypt(_ plainText: String) -> String? {
        do {
            let key = Array(kAESKey.utf8)
            let iv = Array(kAESIV.utf8)
            let aes = try AES(key: key, blockMode: CFB(iv: iv), padding: .noPadding)
            let encrypted = try aes.encrypt(Array(plainText.utf8))
            let base64 = Data(encrypted).base64EncodedString()
            return base64ToBase64URL(base64)
        } catch {
            Logger.shared.log("AES encrypt error: \(error)", level: .error)
            return nil
        }
    }

    // MARK: - AES-CFB Decrypt

    func decrypt(_ base64URLString: String) -> [String: Any]? {
        do {
            let base64 = base64URLToBase64(base64URLString)
            guard let data = Data(base64Encoded: base64) else { return nil }
            let key = Array(kAESKey.utf8)
            let iv = Array(kAESIV.utf8)
            let aes = try AES(key: key, blockMode: CFB(iv: iv), padding: .noPadding)
            let decrypted = try aes.decrypt(Array(data))
            guard let jsonString = String(bytes: decrypted, encoding: .utf8),
                  let jsonData = jsonString.data(using: .utf8),
                  let dict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }
            return dict
        } catch {
            Logger.shared.log("AES decrypt error: \(error)", level: .error)
            return nil
        }
    }

    // MARK: - Private

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func base64ToBase64URL(_ base64: String) -> String {
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    private func base64URLToBase64(_ base64URL: String) -> String {
        return base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
    }
}
