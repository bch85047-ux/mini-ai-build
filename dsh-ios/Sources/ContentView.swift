import SwiftUI
import WebKit

struct ContentView: View {
    @State private var urlString = UserDefaults.standard.string(forKey: "dshUrl") ?? "http://127.0.0.1:3080"
    @State private var reloadToken = 0

    var body: some View {
        VStack(spacing: 0) {
            WebView(urlString: urlString, reloadToken: reloadToken)
                .ignoresSafeArea(edges: .bottom)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { reloadToken += 1 } label: { Image(systemName: "arrow.clockwise") }
                Menu {
                    Button("默认 http://127.0.0.1:3080") { setUrl("http://127.0.0.1:3080") }
                    Button("局域网 http://192.168.1.100:3080") { setUrl("http://192.168.1.100:3080") }
                    Button("自定义…") { promptUrl() }
                } label: { Image(systemName: "gearshape") }
            }
        }
    }

    private func setUrl(_ u: String) {
        urlString = u
        UserDefaults.standard.set(u, forKey: "dshUrl")
        reloadToken += 1
    }
    private func promptUrl() {
        let alert = UIAlertController(title: "dsh 服务地址", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = urlString; $0.keyboardType = .URL }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "连接", style: .default) { _ in
            if let t = alert.textFields?.first?.text, !t.isEmpty { setUrl(t) }
        })
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = scene.windows.first?.rootViewController {
            vc.present(alert, animated: true)
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String
    let reloadToken: Int

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.websiteDataStore = .default()
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        // 让 Web UI 能调用 fetch / WebSocket / 剪贴板等
        web.configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else { return }
        if web.url?.absoluteString != urlString {
            web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ web: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            showError(error)
        }
        func webView(_ web: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            showError(error)
        }
        func webView(_ web: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                web.load(navigationAction.request)
            }
            return nil
        }
        private func showError(_ e: Error) {
            print("dsh web load error:", e.localizedDescription)
        }
    }
}
