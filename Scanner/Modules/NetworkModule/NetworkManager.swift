//
//  NetworkManager.swift
//  Scanner
//
//  Wraps MoyaProvider with unified response parsing, error handling, and logging.
//

import Foundation
import Moya
import UIKit

// MARK: - Response Model

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?

    var isSuccess: Bool { code == 0 || code == 200 }
}

/// Generic empty response for endpoints that return no data.
struct EmptyData: Decodable {}

// MARK: - OCR Result Models

struct OCRResult: Decodable {
    let text: String
}

struct BankCardResult: Decodable {
    let cardNumber: String
    let bankName: String?
    let cardType: String?
}

struct BusinessLicenseResult: Decodable {
    let companyName: String?
    let registrationNumber: String?
    let legalRepresentative: String?
    let address: String?
}

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case serverError(code: Int, message: String)
    case decodingError
    case noData
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .serverError(_, let message): return message
        case .decodingError:               return "数据解析失败"
        case .noData:                      return "服务器未返回数据"
        case .networkUnavailable:          return "网络连接不可用"
        }
    }
}

// MARK: - NetworkManager

final class NetworkManager {

    static let shared = NetworkManager()

    private let provider: MoyaProvider<ScannerAPI>

    private init() {
        #if DEBUG
        let plugins: [PluginType] = [
            NetworkLoggerPlugin(configuration: .init(logOptions: .verbose))
        ]
        #else
        let plugins: [PluginType] = []
        #endif

        provider = MoyaProvider<ScannerAPI>(plugins: plugins)
    }

    // MARK: - Public API

    /// Upload image for OCR text recognition.
    func recognizeText(
        image: UIImage,
        completion: @escaping (Result<OCRResult, Error>) -> Void
    ) {
        guard let imageData = image.compressed(quality: AppConstants.ImageCompression.highQuality) else {
            completion(.failure(NetworkError.noData))
            return
        }
        let fileName = String.uniqueFileName(prefix: "ocr")
        request(.ocrRecognize(imageData: imageData, fileName: fileName), completion: completion)
    }

    /// Upload image for bank card recognition.
    func recognizeBankCard(
        image: UIImage,
        completion: @escaping (Result<BankCardResult, Error>) -> Void
    ) {
        guard let imageData = image.compressed(quality: AppConstants.ImageCompression.highQuality) else {
            completion(.failure(NetworkError.noData))
            return
        }
        let fileName = String.uniqueFileName(prefix: "bankcard")
        request(.bankCardRecognize(imageData: imageData, fileName: fileName), completion: completion)
    }

    /// Upload image for business license recognition.
    func recognizeBusinessLicense(
        image: UIImage,
        completion: @escaping (Result<BusinessLicenseResult, Error>) -> Void
    ) {
        guard let imageData = image.compressed(quality: AppConstants.ImageCompression.highQuality) else {
            completion(.failure(NetworkError.noData))
            return
        }
        let fileName = String.uniqueFileName(prefix: "license")
        request(.businessLicenseRecognize(imageData: imageData, fileName: fileName), completion: completion)
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        _ target: ScannerAPI,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        provider.request(target) { result in
            switch result {
            case .success(let response):
                do {
                    let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: response.data)
                    if apiResponse.isSuccess, let data = apiResponse.data {
                        completion(.success(data))
                    } else {
                        completion(.failure(NetworkError.serverError(
                            code: apiResponse.code,
                            message: apiResponse.message
                        )))
                    }
                } catch {
                    Logger.shared.log("Decoding error: \(error)", level: .error)
                    completion(.failure(NetworkError.decodingError))
                }

            case .failure(let moyaError):
                Logger.shared.log("Network error: \(moyaError.localizedDescription)", level: .error)
                completion(.failure(moyaError))
            }
        }
    }
}
