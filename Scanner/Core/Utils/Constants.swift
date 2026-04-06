//
//  Constants.swift
//  Scanner
//

import UIKit
import Network

enum AppConstants {

    static let appName = "Scanner"

    // A4 paper size at 72 DPI (standard PDF point size)
    enum PageSize {
        static let a4Width: CGFloat = 595.2
        static let a4Height: CGFloat = 841.8
        static let a4Rect = CGRect(x: 0, y: 0, width: a4Width, height: a4Height)
    }

    enum Directory {
        static let scans = "Scans"
        static let pdfs = "PDFs"
        static let temp = "Temp"
    }

    enum ImageCompression {
        static let defaultQuality: CGFloat = 0.8
        static let highQuality: CGFloat = 0.95
        static let lowQuality: CGFloat = 0.5
    }

    enum Camera {
        static let maxRectangleObservations = 1
        static let minimumConfidence: Float = 0.8
        static let minimumAspectRatio: Float = 0.3
        static let maximumAspectRatio: Float = 1.0
    }

    enum UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
        static let cellHeight: CGFloat = 80
    }

    /// Memory-friendly bounds for captured / imported scan images (pixel space, not points).
    enum ScanImage {
        static let maxPixelLength: CGFloat = 2048
        static let thumbnailMaxPixelLength: CGFloat = 256
        static let originalJPEGQuality: CGFloat = 0.88
    }
}

final class NetworkStatusMonitor {

    static let shared = NetworkStatusMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.scanner.network.monitor")
    private var hasStarted = false

    private(set) var isReachable: Bool = true

    /// Matches backend contract: 0 unknown/offline, 1 reachable.
    var statusCode: Int {
        isReachable ? kNetworkStatusReachable : kNetworkStatusUnknown
    }

    private init() {}

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.isReachable = (path.status == .satisfied)
            Logger.shared.log(
                "Network reachable: \(self.isReachable)",
                level: .debug
            )
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
