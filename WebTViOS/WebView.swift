//
//  WebView.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 12.04.22.
//  Copyright © 2022 Raymund Vorwerk. All rights reserved.
//

import Foundation
import SwiftUI
@preconcurrency import WebKit

/// Minimal SwiftUI wrapper that displays a fixed web page.
struct SAWebView: View {
    /// Renders the embedded web view.
    var body: some View {
        Webview(url: URL(string: "https://google.com")!)
    }
}

/// Wraps `WKWebView` for use in SwiftUI.
struct Webview: UIViewRepresentable {
    let url: URL
    let navigationHelper = WebViewHelper()

    /// Creates and loads the initial web view request.
    func makeUIView(context: UIViewRepresentableContext<Webview>) -> WKWebView {
        let webview = WKWebView()
        webview.navigationDelegate = navigationHelper

        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webview.load(request)

        return webview
    }

    /// Reloads the web view when the bound URL changes.
    func updateUIView(_ webview: WKWebView, context: UIViewRepresentableContext<Webview>) {
        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webview.load(request)
    }
}

/// Navigation delegate used for simple web view logging.
class WebViewHelper: NSObject, WKNavigationDelegate {
    /// Called when the web view finishes navigation.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("webview didFinishNavigation")
    }
    
    /// Called when the web view starts provisional navigation.
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation")
    }
    
    /// Called when the web view commits content.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("webviewDidCommit")
    }
    
    /// Handles authentication challenges using default system behavior.
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("didReceiveAuthenticationChallenge")
        completionHandler(.performDefaultHandling, nil)
    }
}
