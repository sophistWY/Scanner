//
//  BaseWebViewController.swift
//  Scanner
//
//  General-purpose WebView controller for displaying web content
//  (e.g. privacy policy, help pages, terms of service).
//

import UIKit
import WebKit
import SnapKit

class BaseWebViewController: BaseViewController {

    /// 推送进栈时显示返回；仅作模态根页时由基类解析为关闭。
    override var customNavigationBarLeftItem: CustomNavigationBarLeft? { nil }

    // MARK: - Properties

    private let urlString: String
    private let pageTitle: String?

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.allowsBackForwardNavigationGestures = true
        return wv
    }()

    private lazy var progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.trackTintColor = .clear
        pv.progressTintColor = .appThemePrimary
        return pv
    }()

    private var progressObservation: NSKeyValueObservation?

    // MARK: - Init

    init(urlString: String, title: String? = nil) {
        self.urlString = urlString
        self.pageTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        progressObservation?.invalidate()
    }

    // MARK: - Setup

    override func setupUI() {
        title = pageTitle ?? "加载中..."

        view.addSubview(webView)
        view.addSubview(progressView)
    }

    override func setupConstraints() {
        progressView.snp.makeConstraints { make in
            make.top.equalTo(customNavigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(2)
        }

        webView.snp.makeConstraints { make in
            make.top.equalTo(progressView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func bindViewModel() {
        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            let progress = Float(webView.estimatedProgress)
            self?.progressView.setProgress(progress, animated: true)
            if progress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3) {
                    self?.progressView.alpha = 0
                }
            } else {
                self?.progressView.alpha = 1
            }
        }

        guard let url = URL(string: urlString) else {
            showAlert(title: "错误", message: "无效的URL") { [weak self] in
                self?.defaultCustomNavigationBarPopOrDismiss()
            }
            return
        }
        webView.load(URLRequest(url: url))
    }
}

// MARK: - WKNavigationDelegate

extension BaseWebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if pageTitle == nil {
            title = webView.title
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.log("WebView failed: \(error.localizedDescription)", level: .error)
    }
}
