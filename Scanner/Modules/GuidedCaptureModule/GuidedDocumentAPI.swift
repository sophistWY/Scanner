//
//  GuidedDocumentAPI.swift
//  Scanner
//
//  Wraps OSS upload + poll with shared pdftype / per-step imgtype (see `GuidedDocumentKind`).
//

import UIKit

enum GuidedDocumentAPI {

    /// 服务端配置的 `pdftype`，对应上传回调里的 `pdftype`（与接口文档中的 `type` 入参一致）。
    static func processImage(
        _ image: UIImage,
        pdfType: String,
        imgtype: String? = nil,
        progress: ((String) -> Void)? = nil,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        let normalized = image.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
        OSSUploadManager.shared.uploadAndProcess(
            image: normalized,
            pdftype: pdfType,
            imgtype: imgtype,
            progress: progress,
            completion: { result in
                Self.handleProcessResult(result, completion: completion)
            }
        )
    }

    /// Process one full-frame image through the same pipeline as smart optimize (`uploadAndProcess`).
    static func processImage(
        _ image: UIImage,
        kind: GuidedDocumentKind,
        stepIndex: Int,
        progress: ((String) -> Void)? = nil,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        let normalized = image.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
        OSSUploadManager.shared.uploadAndProcess(
            image: normalized,
            pdftype: kind.stsPdfType,
            imgtype: kind.imgtype(forStepIndex: stepIndex),
            progress: progress,
            completion: { result in
                Self.handleProcessResult(result, completion: completion)
            }
        )
    }

    private static func handleProcessResult(
        _ result: Result<InfoQueryResult, Error>,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        switch result {
        case .success(let info):
            guard let urlStr = info.resultimg?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !urlStr.isEmpty,
                  let url = URL(string: urlStr) else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
                }
                return
            }
            UIImage.load(from: url) { loadResult in
                switch loadResult {
                case .success(let remote):
                    let out = autoreleasepool {
                        remote.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
                    }
                    DispatchQueue.main.async {
                        completion(.success(out))
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        case .failure(let error):
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
