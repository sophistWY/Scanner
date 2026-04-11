//
//  PermissionHelper.swift
//  Scanner
//
//  未授权：先展示与设计稿一致的说明弹窗（不允许 / 允许），用户点「允许」后再调系统权限。
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
            showRationaleAlert(from: vc, type: .camera, onAllow: {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async { completion(granted) }
                }
            }, onDeny: {
                completion(false)
            })
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
            showRationaleAlert(from: vc, type: .photoLibrary, onAllow: {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    DispatchQueue.main.async {
                        completion(newStatus == .authorized || newStatus == .limited)
                    }
                }
            }, onDeny: {
                completion(false)
            })
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
            showRationaleAlert(from: vc, type: .saveToPhotoLibrary, onAllow: {
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    DispatchQueue.main.async {
                        completion(newStatus == .authorized || newStatus == .limited)
                    }
                }
            }, onDeny: {
                completion(false)
            })
        case .denied, .restricted:
            showDeniedAlert(from: vc, type: .saveToPhotoLibrary, message: "请在设置中允许访问相册以保存导出内容")
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - Private — 自定义弹窗

    private func showRationaleAlert(
        from vc: UIViewController,
        type: PermissionAlertType,
        onAllow: @escaping () -> Void,
        onDeny: @escaping () -> Void
    ) {
        DispatchQueue.main.async {
            AppModalDialog.present(
                from: vc,
                title: type.rationaleTitle,
                message: type.rationaleMessage,
                secondaryTitle: "不允许",
                primaryTitle: "允许",
                onSecondary: onDeny,
                onPrimary: onAllow
            )
        }
    }

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
