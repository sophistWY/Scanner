//
//  APIConstants.swift
//  Scanner
//

import Foundation

// MARK: - Host

public let kHost = "https://pdf.eleimg.com/"
public let kTestHost = "https://testpdf.carduid.cn/"
public let kLanguageHost = "https://api.carduid.cn/"

// MARK: - API Paths

public let kPathSTSImageName = "app/stsimgname"
public let kPathSTSConfig = "app/stsconfig"
public let kPathSTSUpload = "app/stsupload"
public let kPathInfoQuery = "app/infoquery"
public let kPathLanguage = "common/lan"

// MARK: - AES Encryption

/// 32-byte key for AES-256-CFB. IV is always the first 16 bytes of this key (see API doc).
public let kAESKey = "1qaz2ws&*&*&*(()_+++_)*(OL?>:>LK"

// MARK: - Apple IAP

public let kAppleSecretKey = "6b601f9d76d74f2e8ee1f104953f6a14"

// MARK: - Bundle

public let kBundleID = "com.xiangying.scanner"

// MARK: - IAP Product IDs

public let kIAPWeeklyDiscount = "1217325053"
public let kIAPWeekly = "1217325054"
public let kIAPMonthly = "567708090"
public let kIAPYearly = "567708100"

// MARK: - External URLs

public let kPrivacyPolicyURL = "https://docs.qq.com/doc/DQkhFTmJ2TUpreGN2"
public let kUserAgreementURL = "https://docs.qq.com/doc/DQmhtTURCUVh6c3R1"
public let kSubscriptionInfoURL = "https://docs.qq.com/doc/DQnpwVWRFYmF3WXJ5"
public let kAppStoreReviewURL = "itms-apps://itunes.apple.com/app/id/6747080747?action=write-review"

// MARK: - Polling Config

public let kPollingInterval: TimeInterval = 2.0
public let kPollingMaxRetry: Int = 15

// MARK: - Keychain

public let kKeychainUserIDKey = "com.xiangying.scanner.userid"

// MARK: - Network

public let kNetworkStatusUnknown: Int = 0
public let kNetworkStatusReachable: Int = 1

// MARK: - Image Upload

public let kImageContentType = "image/jpeg"
public let kImageExtension = ".jpeg"
