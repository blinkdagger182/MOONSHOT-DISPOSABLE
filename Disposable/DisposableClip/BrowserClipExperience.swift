import SwiftUI
import WebKit

struct BrowserClipExperience: View {
    let eventId: String?

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var reloadToken = UUID()

    private var browserURL: URL? {
        var components = URLComponents(string: "https://guest.tetamu.app/html/template.html")
        if let eventId, !eventId.isEmpty {
            components?.queryItems = [URLQueryItem(name: "eventId", value: eventId)]
        }
        return components?.url
    }

    var body: some View {
        ZStack {
            Color(hex: "#05070d")
                .ignoresSafeArea()

            if let browserURL {
                AppClipWebView(
                    url: browserURL,
                    reloadToken: reloadToken,
                    isLoading: $isLoading,
                    loadError: $loadError
                )
                .ignoresSafeArea()
            } else {
                unavailableView(
                    title: "Event not found",
                    message: "Open this App Clip from a valid Tetamu event link or QR code."
                )
            }

            if isLoading && loadError == nil {
                loadingView
            }

            if let loadError {
                unavailableView(title: "Could not load event", message: loadError)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color(hex: "#d7c3a2"))
                .scaleEffect(1.2)

            Text("Loading Tetamu camera")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color(hex: "#f5efe7"))
        }
        .padding(22)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
    }

    private func unavailableView(title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color(hex: "#f5efe7"))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(hex: "#b6ad9f"))
                .multilineTextAlignment(.center)

            Button("Try Again") {
                loadError = nil
                isLoading = true
                reloadToken = UUID()
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(Color(hex: "#1f1a14"))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "#d7c3a2"), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(22)
        .frame(maxWidth: 360)
        .background(Color(hex: "#111623").opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(20)
    }
}

private struct AppClipWebView: UIViewRepresentable {
    let url: URL
    let reloadToken: UUID
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(hex: "#05070d")
        webView.scrollView.backgroundColor = UIColor(hex: "#05070d")
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.load(url, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.currentURL != url || context.coordinator.reloadToken != reloadToken {
            context.coordinator.reloadToken = reloadToken
            context.coordinator.load(url, in: webView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        @Binding private var isLoading: Bool
        @Binding private var loadError: String?

        var currentURL: URL?
        var reloadToken: UUID?

        init(isLoading: Binding<Bool>, loadError: Binding<String?>) {
            _isLoading = isLoading
            _loadError = loadError
        }

        func load(_ url: URL, in webView: WKWebView) {
            currentURL = url
            isLoading = true
            loadError = nil

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 20
            webView.load(request)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            loadError = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handle(error)
        }

        private func handle(_ error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            isLoading = false
            loadError = error.localizedDescription
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let host = navigationAction.request.url?.host else {
                decisionHandler(.allow)
                return
            }

            if host == "guest.tetamu.app" || host.hasSuffix(".guest.tetamu.app") {
                decisionHandler(.allow)
                return
            }

            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }
    }
}

private extension Color {
    init(hex: String) {
        var cleanHexCode = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHexCode = cleanHexCode.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: cleanHexCode).scanHexInt64(&rgb) else {
            self = .clear
            return
        }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var cleanHexCode = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHexCode = cleanHexCode.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: cleanHexCode).scanHexInt64(&rgb) else {
            self.init(white: 0, alpha: 1)
            return
        }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1
        )
    }
}
