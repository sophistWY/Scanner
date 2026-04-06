//
//  PermissionHelper.swift
//  Scanner
//

import UIKit
import AVFoundation
import Photos

final class PermissionHelper {

    static let shared = PermissionHelper()
    private init() {}

    // MARK: - Camera

    func requestCameraPermission(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied, .restricted:
            showSettingsAlert(from: vc, type: .camera, message: "请在设置中允许访问相机以使用扫描功能")
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Photo Library

    func requestPhotoLibraryPermission(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        case .denied, .restricted:
            showSettingsAlert(from: vc, type: .photoLibrary, message: "请在设置中允许访问相册以导入图片")
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    /// Request add-only permission for saving images/videos to user's photo library.
    func requestPhotoLibraryAddPermission(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        case .denied, .restricted:
            showSettingsAlert(from: vc, type: .saveToPhotoLibrary, message: "请在设置中允许访问相册以保存导出内容")
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Private

    private func showSettingsAlert(from vc: UIViewController, type: PermissionAlertType, message: String) {
        DispatchQueue.main.async {
            if let base = vc as? BaseViewController {
                base.showPermissionAlert(type, message: message)
            } else {
                let alert = UIAlertController(title: type.title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                })
                vc.present(alert, animated: true)
            }
        }
    }
}
