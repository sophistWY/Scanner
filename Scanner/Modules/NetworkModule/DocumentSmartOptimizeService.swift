//
//  DocumentSmartOptimizeService.swift
//  Scanner
//
//  Cloud "智能优化": STS → OSS upload → poll → download result image.
//

import UIKit

enum DocumentSmartOptimizeService {

    /// Runs upload + poll on OSS/network queues; delivers normalized `UIImage` on the main queue.
    static func optimize(
        image: UIImage,
        pdftype: String?,
        progress: ((String) -> Void)? = nil,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        OSSUploadManager.shared.uploadAndProcess(
            image: image,
            pdftype: pdftype,
            progress: progress,
            completion: { result in
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
                            let normalized = autoreleasepool {
                                remote.constrainedToMaxPixelLength(AppConstants.ScanImage.maxPixelLength)
                            }
                            DispatchQueue.main.async {
                                completion(.success(normalized))
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
        )
    }
}
