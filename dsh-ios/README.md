# dsh iOS Web 壳

DeepSeek Harness 的 iOS 客户端。App 本身是一个 WKWebView 全屏壳，连你的 dsh Web UI（`npx @deepseek-ai/dsh web` → http://127.0.0.1:3080）。

## 前置：dsh 服务在哪跑

DeepSeek Harness 是 Node 项目，官方没有 iOS 原生运行时，服务端跑在任意 Linux/macOS/Windows：

```sh
npx @deepseek-ai/dsh web       # Web UI，默认 127.0.0.1:3080
dsh plugin add <插件包>         # 装插件
dsh --profile headless "任务"   # 无头跑任务
```

## iOS 壳连服务

- 本机调试：App 默认连 `http://127.0.0.1:3080`
- 真机连局域网服务：右上角 ⚙ → 填 `http://<服务端局域网IP>:3080`
- 服务端 `--host 0.0.0.0` 或配 SSH 端口转发，才能被手机访问

## 打包 IPA

```sh
brew install xcodegen
./build-ipa.sh        # 产出 build/dsh.ipa
# 或直接推 GitHub，Actions 自动出 artifact
```

装上后 Sideloadly / AltStore / TrollStore 导入，未签名会自动重签。
