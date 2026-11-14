import SwiftUI
import WebKit

enum ConnState {
    case connecting, connected, failed(String)
}

struct ContentView: View {
    // 固定 token 的本机 dsh 服务（Minis 常驻）
    static let defaultUrl = "http://127.0.0.1:3080/?token=dsh-fixed-token-v1-dsh-fixed-token-v1-dsh"

    @AppStorage("dshUrl") private var urlString = ContentView.defaultUrl
    @State private var conn: ConnState = .connecting
    @State private var reloadToken = 0

    var body: some View {
        ZStack {
            WebView(urlString: urlString, reloadToken: reloadToken, conn: $conn)
                .ignoresSafeArea()
            overlay
        }
        .onAppear {
            if urlString.isEmpty { urlString = ContentView.defaultUrl }
        }
    }

    @ViewBuilder
    private var overlay: some View {
        switch conn {
        case .connecting:
            VStack(spacing: 16) {
                Text("dsh").font(.system(size: 56, weight: .black, design: .monospaced))
                ProgressView().scaleEffect(1.3)
                Text("正在连接本机 dsh 服务…")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        case .failed(let err):
            VStack(spacing: 18) {
                Text("dsh").font(.system(size: 56, weight: .black, design: .monospaced))
                Image(systemName: "wifi.exclamationmark").font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("连不上本机 dsh 服务").font(.headline)
                Text(err).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
                Text("请确认 Minis 里的 dsh web 已在运行\n(127.0.0.1:3080)")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Button { conn = .connecting; reloadToken += 1 } label: {
                    Label("重试", systemImage: "arrow.clockwise")
                }.buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        case .connected:
            EmptyView()
        }
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String
    let reloadToken: Int
    @Binding var conn: ConnState

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.websiteDataStore = .default()
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true
        let web = WKWebView(frame: .zero, configuration: cfg)
        web.allowsBackForwardNavigationGestures = true
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard let url = URL(string: urlString) else {
            conn = .failed("地址格式错误"); return
        }
        if web.url?.absoluteString != urlString {
            web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(conn: $conn) }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var conn: Binding<ConnState>
        init(conn: Binding<ConnState>) { self.conn = conn }

        func webView(_ web: WKWebView, didFinish navigation: WKNavigation!) {
            conn.wrappedValue = .connected
        }
        func webView(_ web: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            conn.wrappedValue = .failed(Self.desc(error))
        }
        func webView(_ web: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            conn.wrappedValue = .failed(Self.desc(error))
        }
        func webView(_ web: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { web.load(navigationAction.request) }
            return nil
        }
        static func desc(_ e: Error) -> String {
            switch (e as NSError).code {
            case NSURLErrorCannotConnectToHost: return "服务没响应。确认 dsh web 已启动。"
            case NSURLErrorTimedOut: return "连接超时。"
            case NSURLErrorCannotFindHost: return "找不到主机。"
            case NSURLErrorNetworkConnectionLost: return "网络中断。"
            default: return (e as NSError).localizedDescription
            }
        }
    }
}
