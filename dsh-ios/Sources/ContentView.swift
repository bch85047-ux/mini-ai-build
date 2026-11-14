import SwiftUI
import WebKit

// MARK: - 连接状态
enum ConnState {
    case connecting, connected, failed(String)
}

struct ContentView: View {
    @AppStorage("dshUrl") private var urlString = ""
    @State private var savedUrl = ""
    @State private var inputUrl = ""
    @State private var conn: ConnState = .connecting
    @State private var reloadToken = 0

    var body: some View {
        NavigationStack {
            if savedUrl.isEmpty {
                setupView
            } else {
                serverView
            }
        }
    }

    // MARK: 首开引导
    private var setupView: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("dsh")
                .font(.system(size: 64, weight: .black, design: .monospaced))
                .foregroundStyle(.primary)
            Text("DeepSeek Harness 客户端")
                .font(.subheadline).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("dsh 服务地址").font(.headline)
                TextField("http://192.168.1.100:3080", text: $inputUrl)
                    .keyboardType(.URL).autocapitalization(.none).disableAutocorrection(true)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onSubmit(connect)
                Button("连 接", action: connect)
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                    .disabled(inputUrl.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 28)

            VStack(alignment: .leading, spacing: 8) {
                Text("没有服务端？在你的电脑 / 服务器上跑：")
                    .font(.caption).foregroundStyle(.secondary)
                Text("npx @deepseek-ai/dsh web")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .onAppear { inputUrl = urlString }
    }

    private func quickBtn(_ label: String, _ url: String) -> some View {
        Button(label) { inputUrl = url; connect() }.buttonStyle(.bordered)
    }

    private func connect() {
        var u = inputUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        if !u.hasPrefix("http://") && !u.hasPrefix("https://") { u = "http://" + u }
        urlString = u; savedUrl = u; inputUrl = u
        conn = .connecting
        reloadToken += 1
    }

    // MARK: 连接后：Web UI + 状态覆盖层
    private var serverView: some View {
        ZStack {
            WebView(urlString: savedUrl, reloadToken: reloadToken,
                    conn: $conn)
            switch conn {
            case .connecting:
                VStack(spacing: 14) {
                    ProgressView().scaleEffect(1.4)
                    Text("正在连接 \(savedUrl)…")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            case .failed(let err):
                VStack(spacing: 16) {
                    Image(systemName: "wifi.exclamationmark").font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("连不上 dsh 服务").font(.headline)
                    Text(savedUrl).font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(err).font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                    VStack(spacing: 10) {
                        Button { conn = .connecting; reloadToken += 1 } label: {
                            Label("重试连接", systemImage: "arrow.clockwise")
                        }.buttonStyle(.borderedProminent)
                        Button("换个地址") {
                            urlString = ""; savedUrl = ""; conn = .connecting
                        }.buttonStyle(.bordered)
                        Button {
                            UIPasteboard.general.string = "npx @deepseek-ai/dsh web"
                        } label: {
                            Label("复制启动命令", systemImage: "doc.on.doc")
                        }.buttonStyle(.bordered).font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            case .connected:
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if case .connected = conn {
                    Button { conn = .connecting; reloadToken += 1 } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                Button {
                    urlString = ""; savedUrl = ""; inputUrl = ""; conn = .connecting
                } label: { Image(systemName: "gearshape") }
            }
        }
        .onAppear { if savedUrl.isEmpty { savedUrl = urlString } }
    }
}

// MARK: - WKWebView
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
            conn = .failed("地址格式不对：\(urlString)"); return
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
            let n = (e as NSError).code
            switch n {
            case NSURLErrorCannotConnectToHost: return "服务器没响应。确认 dsh web 已启动，且手机和它在同一网络。"
            case NSURLErrorTimedOut: return "连接超时。检查地址、端口（默认 3080）和网络。"
            case NSURLErrorCannotFindHost: return "找不到主机。检查 IP/域名对不对。"
            case NSURLErrorNetworkConnectionLost: return "网络中断。"
            default: return (e as NSError).localizedDescription
            }
        }
    }
}
