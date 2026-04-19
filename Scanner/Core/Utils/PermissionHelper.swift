//
//  PermissionHelper.swift
//  Scanner
//
//  首次请求：直接调系统权限 API，由系统弹窗。
//  已拒绝：引导去设置（取消 / 去设置），与 BaseViewController.showPermissionAlert 一致。
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
            showDeniedAlert(from: vc, type: .camera, message: "请在设置中允许访问相机以使用扫描功能")
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
            showDeniedAlert(from: vc, type: .photoLibrary, message: "请在设置中允许访问相册以导入图片")
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
            showDeniedAlert(from: vc, type: .saveToPhotoLibrary, message: "请在设置中允许访问相册以保存导出内容")
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Private — 已拒绝时引导去设置

    private func showDeniedAlert(from vc: UIViewController, type: PermissionAlertType, message: String) {
        DispatchQueue.main.async {
            if let base = vc as? BaseViewController {
                base.showPermissionAlert(type, message: message)
            } else {
                AppModalDialog.present(
                    from: vc,
                    title: type.deniedTitle,
                    message: message,
                    secondaryTitle: "取消",
                    primaryTitle: "去设置",
                    onSecondary: {},
                    onPrimary: {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                )
            }
        }
    }
}
