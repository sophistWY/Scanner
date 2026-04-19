//
//  PermissionAlertType.swift
//  Scanner
//
//  权限已被拒绝时：引导去设置的文案（与 BaseViewController.showPermissionAlert 等一致）。
//

import Foundation

enum PermissionAlertType {
    case camera
    case photoLibrary
    case saveToPhotoLibrary

    // MARK: - Denied / 设置

    var deniedTitle: String {
        switch self {
        case .camera:
            return "无法使用相机"
        case .photoLibrary:
            return "无法访问相册"
        case .saveToPhotoLibrary:
            return "无法保存到相册"
        }
    }

    var deniedMessage: String {
        switch self {
        case .camera:
            return "请在「设置」中允许访问相机，以使用扫描功能。"
        case .photoLibrary:
            return "请在「设置」中允许访问相册，以导入图片。"
        case .saveToPhotoLibrary:
            return "请在「设置」中允许写入相册，以保存导出内容。"
        }
    }
}
