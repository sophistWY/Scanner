//
//  OSSUploadManager.swift
//  Scanner
//

import Foundation
import AliyunOSSiOS
import UIKit

final class OSSUploadManager {

    static let shared = OSSUploadManager()

    private var client: OSSClient?
    private var cachedConfig: STSConfig?

    private init() {}

    // MARK: - Upload Image via OSS

    func uploadImage(
        imageData: Data,
        imageInfo: STSImageInfo,
        stsConfig: STSConfig,
        pdftype: String? = nil,
        imgtype: String? = nil,
        pointstring: String? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        setupClient(with: stsConfig)

        guard let client else {
            completion(.failure(NetworkError.noData))
            return
        }

        let objectKey = imageInfo.imagepath + kImageExtension

        let put = OSSPutObjectRequest()
        put.bucketName = stsConfig.bucket
        put.objectKey = objectKey
        put.contentType = kImageContentType
        put.uploadingData = imageData

        guard let callbackURL = NetworkManager.shared.buildOSSCallbackURL(
            carduid: imageInfo.carduid,
            imagepath: imageInfo.imagepath,
            pdftype: pdftype,
            imgtype: imgtype,
            pointstring: pointstring
        ) else {
            completion(.failure(NetworkError.encryptionFailed))
            return
        }

        put.callbackParam = [
            "callbackUrl": callbackURL,
            "callbackBody": "{\"bucket\":${bucket},\"object\":${object}}",
            "callbackBodyType": "application/json"
        ]

        let task = client.putObject(put)
        task.continue({ t -> Any? in
            DispatchQueue.main.async {
                if let error = t.error {
                    Logger.shared.log("OSS upload error: \(error)", level: .error)
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
            return nil
        })
    }

    // MARK: - Full Upload & Process Flow

    /// 完整上传处理流程:
    /// 1. stsimgname → 获取 imagepath + carduid
    /// 2. stsconfig  → 获取 STS 临时凭证
    /// 3. OSS 上传   → 带 callback 触发服务端处理
    /// 4. infoquery  → 轮询直到处理完成
    func uploadAndProcess(
        image: UIImage,
        pdftype: String? = nil,
        imgtype: String? = nil,
        pointstring: String? = nil,
        progress: ((String) -> Void)? = nil,
        completion: @escaping (Result<InfoQueryResult, Error>) -> Void
    ) {
        guard let imageData = image.compressed(quality: AppConstants.ImageCompression.highQuality) else {
            completion(.failure(NetworkError.noData))
            return
        }

        progress?("获取上传路径...")

        NetworkManager.shared.fetchImageUploadPath { [weak self] result in
            switch result {
            case .success(let imageInfo):
                progress?("获取临时凭证...")

                NetworkManager.shared.fetchSTSConfig { result in
                    switch result {
                    case .success(let stsConfig):
                        progress?("上传图片...")

                        self?.uploadImage(
                            imageData: imageData,
                            imageInfo: imageInfo,
                            stsConfig: stsConfig,
                            pdftype: pdftype,
                            imgtype: imgtype,
                            pointstring: pointstring
                        ) { result in
                            switch result {
                            case .success:
                                progress?("处理中...")

                                NetworkManager.shared.pollProcessingResult(
                                    carduid: imageInfo.carduid,
                                    imagepath: imageInfo.imagepath,
                                    completion: completion
                                )

                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }

                    case .failure(let error):
                        completion(.failure(error))
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Private

    private func setupClient(with config: STSConfig) {
        let credential = OSSStsTokenCredentialProvider(
            accessKeyId: config.accesskeyid,
            secretKeyId: config.accesskeysecret,
            securityToken: config.securitytoken
        )

        let conf = OSSClientConfiguration()
        conf.maxRetryCount = 3
        conf.timeoutIntervalForRequest = 30
        conf.timeoutIntervalForResource = 86400

        client = OSSClient(
            endpoint: config.endpoint,
            credentialProvider: credential,
            clientConfiguration: conf
        )
        cachedConfig = config
    }
}
