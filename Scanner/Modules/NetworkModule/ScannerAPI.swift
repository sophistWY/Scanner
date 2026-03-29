//
//  ScannerAPI.swift
//  Scanner
//

import Foundation
import Moya

enum ScannerAPI {
    /// 1. 获取图片上传路径 (encrypted)
    case stsImageName(sign: String)
    /// 2. 获取 STS 临时凭证 (encrypted)
    case stsConfig(sign: String)
    /// 4. 查询处理结果 (plain)
    case infoQuery(params: [String: Any])
    /// 5. 获取多语言翻译 (plain, different host)
    case language
    /// 6. 裁剪上传 - 直接请求 (plain)
    case cropUpload(params: [String: Any])
}

extension ScannerAPI: TargetType {

    var baseURL: URL {
        switch self {
        case .language:
            return URL(string: kLanguageHost)!
        default:
            return URL(string: kHost)!
        }
    }

    var path: String {
        switch self {
        case .stsImageName:  return kPathSTSImageName
        case .stsConfig:     return kPathSTSConfig
        case .infoQuery:     return kPathInfoQuery
        case .language:      return kPathLanguage
        case .cropUpload:    return kPathSTSUpload
        }
    }

    var method: Moya.Method {
        return .get
    }

    var task: Moya.Task {
        switch self {
        case .stsImageName(let sign):
            return .requestParameters(
                parameters: ["sign": sign],
                encoding: URLEncoding.queryString
            )

        case .stsConfig(let sign):
            return .requestParameters(
                parameters: ["sign": sign],
                encoding: URLEncoding.queryString
            )

        case .infoQuery(let params):
            return .requestParameters(
                parameters: params,
                encoding: URLEncoding.queryString
            )

        case .language:
            return .requestParameters(
                parameters: ["appid": kBundleID],
                encoding: URLEncoding.queryString
            )

        case .cropUpload(let params):
            return .requestParameters(
                parameters: params,
                encoding: URLEncoding.queryString
            )
        }
    }

    var headers: [String: String]? {
        return ["Accept": "application/json"]
    }

    var validationType: ValidationType {
        return .successCodes
    }
}
