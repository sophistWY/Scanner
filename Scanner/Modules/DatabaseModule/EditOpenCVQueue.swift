//
//  EditOpenCVQueue.swift
//  Scanner
//
//  Global serial queue for OpenCV filter work to avoid multi-page parallel CPU overload.
//

import Foundation

enum EditOpenCVQueue {
    static let shared = DispatchQueue(label: "com.scanner.edit.opencv", qos: .userInitiated)
}
