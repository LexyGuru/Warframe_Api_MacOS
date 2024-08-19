//
//  ContentView.swift
//  WarframeInfoHub
//
//  Created by Miklós Lekszikov on 19.08.24.
//

import SwiftUI
import WebKit
import Combine

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: WebView
    var webView: WKWebView?
    
    init(_ parent: WebView) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Page loaded successfully: \(webView.url?.absoluteString ?? "")")
        webView.evaluateJavaScript("""
            console.log("JavaScript executed from Swift");
            if (typeof initSearch === 'function') {
                console.log("Calling initSearch");
                initSearch();
            } else {
                console.log("initSearch is not defined");
            }
        """) { result, error in
            if let error = error {
                print("JavaScript error: \(error.localizedDescription)")
            } else if let result = result {
                print("JavaScript result: \(result)")
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "swiftBridge", let url = message.body as? String {
            NSWorkspace.shared.open(URL(string: url)!)
        }
    }
}

struct WebView: NSViewRepresentable {
    @Binding var htmlContent: String
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "swiftBridge")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: URL(string: "https://raw.githubusercontent.com/LexyGuru/Warframe_Api_Main/main/"))
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
}

class GitHubContentLoader: ObservableObject {
    @Published var htmlContent: String = ""
    
    private let githubRawURL = "https://raw.githubusercontent.com/LexyGuru/Warframe_Api_Main/main/"
    
    func loadPage(_ pageName: String) {
        let group = DispatchGroup()
        
        var htmlContent = ""
        var jsContent = ""
        var cssContent = ""
        
        group.enter()
        downloadFile("gui/\(pageName).html") { result in
            htmlContent = result ?? "Error loading HTML"
            group.leave()
        }
        
        group.enter()
        downloadFile("gui/Script/\(pageName).js") { result in
            jsContent = result ?? ""
            group.leave()
        }
        
        group.enter()
        downloadFile("gui/Styles/\(pageName)_styles.css") { result in
            cssContent = result ?? ""
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.createFullHTML(htmlContent: htmlContent, jsContent: jsContent, cssContent: cssContent, pageName: pageName)
        }
    }
    
    func loadHomePage() {
        downloadFile("README.md") { result in
            if let markdownContent = result {
                // Note: In Swift, we'd need to use a Markdown parsing library here.
                // For simplicity, we'll just wrap the content in basic HTML.
                let htmlContent = "<h1>README</h1><pre>\(markdownContent)</pre>"
                self.createFullHTML(htmlContent: htmlContent, jsContent: "", cssContent: "", pageName: "home")
            } else {
                print("Error loading README")
            }
        }
    }
    
    private func downloadFile(_ path: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(githubRawURL)\(path)") else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let content = String(data: data, encoding: .utf8) {
                completion(content)
            } else {
                print("Error loading file \(path): \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }.resume()
    }
    
    private func createFullHTML(htmlContent: String, jsContent: String, cssContent: String, pageName: String) {
        let fullHTML = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Warframe Info Hub</title>
            <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    line-height: 1.6;
                    padding: 20px;
                    max-width: 800px;
                    margin: 0 auto;
                    background-color: #ffffff;
                    color: #333333;
                }
                h1, h2, h3, h4, h5, h6 {
                    color: #2c3e50;
                    border-bottom: 1px solid #eee;
                    padding-bottom: 10px;
                }
                pre {
                    background-color: #f8f8f8;
                    border: 1px solid #ddd;
                    border-radius: 3px;
                    padding: 10px;
                    overflow-x: auto;
                }
                \(cssContent)
            </style>
            <script>
                function initSearch() {
                    console.log("Search initialized");
                }
                function openURL(url) {
                    window.webkit.messageHandlers.swiftBridge.postMessage(url);
                }
                \(jsContent)
            </script>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
        
        self.htmlContent = fullHTML
    }
}

struct ContentView: View {
    @StateObject private var contentLoader = GitHubContentLoader()
    @State private var selectedMenuItem: String?
    
    var body: some View {
        NavigationView {
            List {
                Button("Kezdőlap") { loadPage("home") }
                Button("Keresés") { loadPage("search") }
                DisclosureGroup("Ciklusok") {
                    Button("Ciklusok") { loadPage("cycles") }
                    Button("Sortie") { loadPage("sortie") }
                    Button("Arcon Hunt") { loadPage("archon") }
                    Button("Arbitration") { loadPage("arbitration") }
                    Button("Nightwave") { loadPage("nightwave") }
                    Button("Void Fissures") { loadPage("fissures") }
                    Button("Baro Ki'Teer") { loadPage("baro") }
                }
                Button("Események") { loadPage("events") }
                Button("Git Update Info") { loadPage("info_git") }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)
            
            WebView(htmlContent: $contentLoader.htmlContent)
        }
        .navigationTitle("Warframe Info Hub")
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            contentLoader.loadHomePage()
        }
    }
    
    private func loadPage(_ pageName: String) {
        selectedMenuItem = pageName
        if pageName == "home" {
            contentLoader.loadHomePage()
        } else {
            contentLoader.loadPage(pageName)
        }
    }
}

@main
struct WarframeInfoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
