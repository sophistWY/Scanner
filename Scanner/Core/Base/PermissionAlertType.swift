//
//  PermissionAlertType.swift
//  Scanner
//
//  Copy for rationale (before system dialog) and denied (引导去设置).
//

import Foundation

enum PermissionAlertType {
    case camera
    case photoLibrary
    case saveToPhotoLibrary

    // MARK: - Rationale (自定义弹窗 → 再调系统权限)

    var rationaleTitle: String {
        switch self {
        case .camera:
            return "想使用你的相机"
        case .photoLibrary:
            return "想访问你的相册"
        case .saveToPhotoLibrary:
            return "想保存到相册"
        }
    }

    var rationaleMessage: String {
        switch self {
        case .camera:
            return "扫描文档需要使用相机，是否允许此应用访问？"
        case .photoLibrary:
            return "上传照片需访问你的相册，是否允许此应用访问？"
        case .saveToPhotoLibrary:
            return "导出内容保存到相册需要访问权限，是否允许？"
        }
    }

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
