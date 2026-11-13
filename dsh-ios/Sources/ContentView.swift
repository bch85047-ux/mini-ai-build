import SwiftUI
import WebKit

// MARK: - 主界面：首开引导配置 → 连上后显示 Web UI
struct ContentView: View {
    @AppStorage("dshUrl") private var urlString = ""
    @State private var savedUrl = ""
    @State private var inputUrl = ""
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            if savedUrl.isEmpty {
                setupView
            } else {
                webView
            }
        }
    }

    // MARK: 首开引导：填 dsh 服务地址
    private var setupView: some View {
        VStack(spacing: 24) {
            Spacer()
            // dsh 鲸标（SF Symbol 近似，白色鲸鱼剪影）
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 80))
                .foregroundStyle(.white, .secondary)
                .padding()
            Text("DeepSeek Harness")
                .font(.title).bold()
            Text("连接你的 dsh Web UI 服务")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("服务地址").font(.headline)
                TextField("http://192.168.1.100:3080", text: $inputUrl)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit(connect)
                Button("连接", action: connect)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(inputUrl.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)

            // 快捷预设
            VStack(alignment: .leading, spacing: 8) {
                Text("或选预设").font(.caption).foregroundStyle(.secondary)
                HStack {
                    quickBtn("本机调试", "http://127.0.0.1:3080")
                    quickBtn("局域网", "http://192.168.1.100:3080")
                }
            }
            Spacer()
        }
        .onAppear { inputUrl = urlString }
    }

    private func quickBtn(_ label: String, _ url: String) -> some View {
        Button(label) {
            inputUrl = url
            connect()
        }
        .buttonStyle(.bordered)
    }

    private func connect() {
        var u = inputUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        if !u.hasPrefix("http://") && !u.hasPrefix("https://") {
            u = "http://" + u
        }
        urlString = u
        savedUrl = u
        inputUrl = u
        reloadToken += 1
    }

    // MARK: 连接后：Web UI 全屏
    private var webView: some View {
        VStack(spacing: 0) {
            WebView(urlString: savedUrl, reloadToken: reloadToken)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { reloadToken += 1 } label: { Image(systemName: "arrow.clockwise") }
                Button {
                    urlString = ""
                    savedUrl = ""
                    inputUrl = ""
                } label: { Image(systemName: "gearshape") }
            }
        }
        .onAppear {
            if savedUrl.isEmpty { savedUrl = urlString }
        }
    }
}

// MARK: - WKWebView 包装
struct WebView: UIViewRepresentable {
    let urlString: String
    let reloadToken: Int

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
        guard let url = URL(string: urlString) else { return }
        if web.url?.absoluteString != urlString {
            web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(_ web: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("dsh web error:", error.localizedDescription)
        }
        func webView(_ web: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("dsh web provisional error:", error.localizedDescription)
        }
        func webView(_ web: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { web.load(navigationAction.request) }
            return nil
        }
    }
}
