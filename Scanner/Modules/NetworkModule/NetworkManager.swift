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

    enum CodingKeys: String, CodingKey {
        case imagepath, carduid, ext
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        imagepath = try c.decode(String.self, forKey: .imagepath)
        carduid = try c.decode(String.self, forKey: .carduid)
        ext = try c.decodeIfPresent(String.self, forKey: .ext) ?? kImageExtension
    }
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
    /// 部分接口返回的 `data` 不含顶层 `carduid`（仅在 `resp` 等嵌套里出现）；缺省时由调用方使用请求参数中的 carduid。
    let carduid: String?
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

    // MARK: - 4a. 轮询处理结果

    /// 单次 `infoquery` 返回后立即发起下一次；在 `kPollingMaxDuration` 内持续轮询直至完成或失败。
    func pollProcessingResult(
        carduid: String,
        imagepath: String,
        ext: String = kImageExtension,
        startTime: CFAbsoluteTime? = nil,
        iteration: Int = 0,
        completion: @escaping (Result<InfoQueryResult, Error>) -> Void
    ) {
        let t0 = startTime ?? CFAbsoluteTimeGetCurrent()

        queryProcessingResult(carduid: carduid, imagepath: imagepath, ext: ext) { [weak self] result in
            guard let self else { return }

            let elapsed = CFAbsoluteTimeGetCurrent() - t0
            let mayContinue =
                elapsed < kPollingMaxDuration
                && iteration < kPollingMaxIterations

            switch result {
            case .success(let info):
                if info.isCompleted {
                    completion(.success(info))
                    return
                }
                if info.isProcessing, mayContinue {
                    self.enqueuePollProcessingResult(
                        carduid: carduid,
                        imagepath: imagepath,
                        ext: ext,
                        startTime: t0,
                        iteration: iteration + 1,
                        completion: completion
                    )
                } else {
                    completion(.failure(NetworkError.pollingTimeout))
                }

            case .failure(let error):
                if mayContinue {
                    self.enqueuePollProcessingResult(
                        carduid: carduid,
                        imagepath: imagepath,
                        ext: ext,
                        startTime: t0,
                        iteration: iteration + 1,
                        completion: completion
                    )
                } else {
                    completion(.failure(error))
                }
            }
        }
    }

    private func enqueuePollProcessingResult(
        carduid: String,
        imagepath: String,
        ext: String,
        startTime: CFAbsoluteTime,
        iteration: Int,
        completion: @escaping (Result<InfoQueryResult, Error>) -> Void
    ) {
        DispatchQueue.global().async { [weak self] in
            self?.pollProcessingResult(
                carduid: carduid,
                imagepath: imagepath,
                ext: ext,
                startTime: startTime,
                iteration: iteration,
                completion: completion
            )
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

    // MARK: - 7. 证件类型配置

    func fetchPdfTypeList(
        completion: @escaping (Result<[PdfTypeItem], Error>) -> Void
    ) {
        request(.configGet(name: "pdftype.json"), completion: completion)
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
