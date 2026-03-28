//
//  ScannerAPI.swift
//  Scanner
//
//  Moya-style API target enum defining all backend endpoints.
//

import Foundation
import Moya

enum ScannerAPI {
    /// OCR: upload a document image for text recognition.
    case ocrRecognize(imageData: Data, fileName: String)
    /// Bank card: upload image for card number recognition.
    case bankCardRecognize(imageData: Data, fileName: String)
    /// Business license: upload image for license info extraction.
    case businessLicenseRecognize(imageData: Data, fileName: String)
}

extension ScannerAPI: TargetType {

    var baseURL: URL {
        // Replace with actual server URL in production
        return URL(string: "https://api.scanner-app.example.com/v1")!
    }

    var path: String {
        switch self {
        case .ocrRecognize:
            return "/ocr/recognize"
        case .bankCardRecognize:
            return "/bankcard/recognize"
        case .businessLicenseRecognize:
            return "/license/recognize"
        }
    }

    var method: Moya.Method {
        return .post
    }

    var task: Moya.Task {
        switch self {
        case .ocrRecognize(let imageData, let fileName),
             .bankCardRecognize(let imageData, let fileName),
             .businessLicenseRecognize(let imageData, let fileName):
            let formData = MultipartFormData(
                provider: .data(imageData),
                name: "image",
                fileName: fileName,
                mimeType: "image/jpeg"
            )
            return .uploadMultipart([formData])
        }
    }

    var headers: [String: String]? {
        return [
            "Accept": "application/json",
            // Auth token would go here in production
            // "Authorization": "Bearer \(token)"
        ]
    }

    var validationType: ValidationType {
        return .successCodes
    }
}
