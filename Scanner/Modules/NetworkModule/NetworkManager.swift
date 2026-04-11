//
//  NetworkManager.swift
//  Scanner
//

import Foundation
import Moya
import UIKit

// MARK: - API Response

struct APIResponse<T: Decodable>: Decodable {
    let code: String
    let data: T?
    let info: String?

    var isSuccess: Bool { code == "1" }

    enum CodingKeys: String, CodingKey {
        case code, data, info
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let s = try? container.decode(String.self, forKey: .code) {
            code = s
        } else if let i = try? container.decode(Int.self, forKey: .code) {
            code = String(i)
        } else {
            code = "0"
        }
        data = try container.decodeIfPresent(T.self, forKey: .data)
        info = try container.decodeIfPresent(String.self, forKey: .info)
    }
}

// MARK: - Response Models

struct STSImageInfo: Decodable {
    let imagepath: String
    let carduid: String
    let ext: String
}

struct STSConfig: Decodable {
    let accesskeyid: String
    let accesskeysecret: String
    let bucket: String
    let bucketendpoint: String
    let endpoint: String
    let expiration: String
    let regionid: String
    let securitytoken: String
    let stsendpoint: String
}

struct InfoQueryResult: Decodable {
    let datastatus: String
    let carduid: String
    let imageurl: String?
    let resultimg: String?
    let imageurl1: String?

    var isProcessing: Bool { datastatus == "2" }
    var isCompleted: Bool { datastatus == "1" }
}

struct LanguageItem: Decodable {
    let key: String
    let originaltext: String
    let translatedtext: String
}

typealias LanguageData = [String: [String: LanguageItem]]

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case serverError(code: String, message: String)
    case decodingError
    case noData
    case encryptionFailed
    case pollingTimeout
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .serverError(_, let msg): return msg.isEmpty ? "服务器错误" : msg
        case .decodingError:           return "数据解析失败"
        case .noData:                  return "服务器未返回数据"
        case .encryptionFailed:        return "参数加密失败"
        case .pollingTimeout:          return "处理超时，请重试"
        case .networkUnavailable:      return "网络连接不可用"
        }
    }
}

// MARK: - NetworkManager

final class NetworkManager {

    static let shared = NetworkManager()

    private let provider: MoyaProvider<ScannerAPI>
    private let crypto = AESCryptoHelper.shared

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

    // MARK: - 1. 获取图片上传路径

    func fetchImageUploadPath(
        completion: @escaping (Result<STSImageInfo, Error>) -> Void
    ) {
        let params = crypto.encryptedCommonParams()
        guard let sign = crypto.generateSign(params: params) else {
            completion(.failure(NetworkError.encryptionFailed))
            return
        }
        request(.stsImageName(sign: sign), completion: completion)
    }

    // MARK: - 2. 获取 STS 临时凭证

    func fetchSTSConfig(
        completion: @escaping (Result<STSConfig, Error>) -> Void
    ) {
        let params: [String: Any] = [
            "userid": crypto.userid,
            "appid": kBundleID,
            "uid": crypto.generateUID()
        ]
        guard let sign = crypto.generateSign(params: params) else {
            completion(.failure(NetworkError.encryptionFailed))
            return
        }
        request(.stsConfig(sign: sign), completion: completion)
    }

    // MARK: - 3. 构建 OSS 回调 URL

    func buildOSSCallbackURL(
        carduid: String,
        imagepath: String,
        ext: String = kImageExtension,
        pdftype: String? = nil,
        imgtype: String? = nil,
        pointstring: String? = nil
    ) -> String? {
        var params = crypto.encryptedCommonParams()
        params["carduid"] = carduid
        params["imagepath"] = imagepath
        params["ext"] = ext
        if let pdftype { params["pdftype"] = pdftype }
        if let imgtype { params["imgtype"] = imgtype }
        if let pointstring { params["pointstring"] = pointstring }

        guard let sign = crypto.generateSign(params: params) else { return nil }
        var components = URLComponents(string: "\(kHost)\(kPathSTSUpload)")
        components?.queryItems = [URLQueryItem(name: "sign", value: sign)]
        return components?.url?.absoluteString
    }

    // MARK: - 4. 查询处理结果

    func queryProcessingResult(
        carduid: String,
        imagepath: String,
        ext: String = kImageExtension,
        completion: @escaping (Result<InfoQueryResult, Error>) -> Void
    ) {
        var params = crypto.commonParams()
        params["carduid"] = carduid
        params["imagepath"] = imagepath
        params["ext"] = ext

        request(.infoQuery(params: params), completion: completion)
    }

    // MARK: - 4a. 轮询处理结果 (interval 2s, max 15 retries)

    func pollProcessingResult(
        carduid: String,
        imagepath: String,
        ext: String = kImageExtension,
        retryCount: Int = 0,
        completion: @escaping (Result<InfoQueryResult, Error>) -> Void
    ) {
        queryProcessingResult(carduid: carduid, imagepath: imagepath, ext: ext) { [weak self] result in
            switch result {
            case .success(let info):
                if info.isCompleted {
                    completion(.success(info))
                } else if info.isProcessing, retryCount < kPollingMaxRetry {
                    DispatchQueue.global().asyncAfter(deadline: .now() + kPollingInterval) {
                        self?.pollProcessingResult(
                            carduid: carduid,
                            imagepath: imagepath,
                            ext: ext,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                } else {
                    completion(.failure(NetworkError.pollingTimeout))
                }

            case .failure(let error):
                if retryCount < kPollingMaxRetry {
                    DispatchQueue.global().asyncAfter(deadline: .now() + kPollingInterval) {
                        self?.pollProcessingResult(
                            carduid: carduid,
                            imagepath: imagepath,
                            ext: ext,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - 5. 获取多语言翻译

    func fetchLanguages(
        completion: @escaping (Result<LanguageData, Error>) -> Void
    ) {
        request(.language, completion: completion)
    }

    // MARK: - 6. 裁剪上传（直接请求）

    func cropUpload(
        extraParams: [String: Any] = [:],
        completion: @escaping (Result<STSImageInfo, Error>) -> Void
    ) {
        var params: [String: Any] = [
            "userid": crypto.userid,
            "appid": kBundleID
        ]
        for (k, v) in extraParams { params[k] = v }
        request(.cropUpload(params: params), completion: completion)
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        _ target: ScannerAPI,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        if !NetworkStatusMonitor.shared.isReachable {
            completion(.failure(NetworkError.networkUnavailable))
            return
        }

        provider.request(target) { result in
            switch result {
            case .success(let response):
                do {
                    let apiResp = try JSONDecoder().decode(
                        APIResponse<T>.self,
                        from: response.data
                    )
                    if apiResp.isSuccess, let data = apiResp.data {
                        completion(.success(data))
                    } else {
                        completion(.failure(NetworkError.serverError(
                            code: apiResp.code,
                            message: apiResp.info ?? ""
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
