import SwiftUI
import WebKit

struct ContentView: View {
    let appUrl = URL(string: "https://clean-stream-app.vercel.app")!

    var body: some View {
        WebViewContainer(url: appUrl)
            .edgesIgnoringSafeArea(.all)
            .ignoresSafeArea(.all)
            .background(Color(red: 7/255, green: 10/255, blue: 18/255))
    }
}

struct WebViewContainer: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // 1. Inyección de script temprano dentro de todos los sub-frames (forMainFrameOnly: false)
        let antiAdScriptSource = """
        (function() {
            if (window.__cinezen_shield_active) return;
            window.__cinezen_shield_active = true;

            // Inutilizar window.open para burlar detección de sandbox y anular popups
            try {
                const dummyWin = {
                    closed: false,
                    close: function(){},
                    focus: function(){},
                    blur: function(){},
                    postMessage: function(){},
                    location: { href: 'about:blank' }
                };
                const safeOpen = function(url) {
                    console.log('[CineZen Shield] Blocked popup window.open ->', url);
                    return dummyWin;
                };
                Object.defineProperty(window, 'open', {
                    value: safeOpen,
                    writable: false,
                    configurable: false
                });
            } catch(e) {
                try { window.open = function() { return dummyWin; }; } catch(err) {}
            }

            try {
                window.alert = function(m) { console.log('[CineZen Shield] Alert:', m); };
                window.confirm = function() { return false; };
                window.prompt = function() { return null; };
            } catch(e) {}

            // Eliminar capas invisibles de clickjacking al vuelo
            const observer = new MutationObserver(function() {
                const elems = document.querySelectorAll('div, a, iframe');
                elems.forEach(function(el) {
                    try {
                        const s = window.getComputedStyle(el);
                        if (s.position === 'fixed' || s.position === 'absolute') {
                            const z = parseInt(s.zIndex, 10);
                            const op = parseFloat(s.opacity);
                            if (z >= 9999 && op <= 0.05 && el.offsetWidth > 150 && el.offsetHeight > 150) {
                                el.remove();
                            }
                        }
                    } catch(err) {}
                });
            });

            if (document.body) {
                observer.observe(document.body, { childList: true, subtree: true });
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    if (document.body) observer.observe(document.body, { childList: true, subtree: true });
                });
            }
        })();
        """

        let userScript = WKUserScript(
            source: antiAdScriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)

        // 2. Reglas nativas de WebKit (WKContentRuleList) para bloqueo a nivel de red y CSS
        let contentRulesJson = """
        [
            {
                "trigger": {
                    "url-filter": ".*(adsterra|popads|popcash|monetag|adsco\\\\.re|onclick|acscdn|propellerads|juicyads|exoclick|hilltopads|trafficjunky|highperformanceformat|effectivecpmgate).*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*"
                },
                "action": {
                    "type": "css-display-none",
                    "selector": "div[style*='z-index: 2147483647'], div[style*='opacity: 0'], a[target='_blank'][style*='position: fixed']"
                }
            }
        ]
        """

        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "CineZenAdBlocker",
            encodedContentRuleList: contentRulesJson
        ) { ruleList, error in
            if let ruleList = ruleList {
                config.userContentController.add(ruleList)
            }
        }

        if #available(iOS 15.4, *) {
            config.preferences.isElementFullscreenEnabled = true
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.backgroundColor = UIColor(red: 7/255, green: 10/255, blue: 18/255, alpha: 1)
        webView.isOpaque = false
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        // Regla 1: WKUIDelegate -> createWebViewWithConfiguration devuelve nil
        // Ningún popup o nueva pestaña puede nacer jamás
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            print("[CineZen iOS] Popup bloqueado automáticamente")
            return nil
        }

        // Regla 2: WKNavigationDelegate -> decidePolicyForNavigationAction
        // Cancela redirecciones maliciosas que intenten sacar la pestaña principal de nuestro dominio
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Permitir navegación libre en subframes (iframes de reproductores como vidlink)
            if navigationAction.targetFrame?.isMainFrame == false {
                decisionHandler(.allow)
                return
            }

            // Para la ventana principal (mainFrame), permitir únicamente nuestro dominio o red local
            let host = url.host?.lowercased() ?? ""
            if host.contains("clean-stream-app.vercel.app") ||
               host.contains("localhost") ||
               host.contains("127.0.0.1") ||
               host.contains("192.168.") {
                decisionHandler(.allow)
            } else {
                print("[CineZen iOS] Bloqueado secuestro de pestaña principal hacia: \\(url.absoluteString)")
                decisionHandler(.cancel)
            }
        }
    }
}
