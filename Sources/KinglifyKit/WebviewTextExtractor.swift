import Foundation
import WebKit
import Combine

class WebViewTextExtractor: NSObject, ObservableObject, WKNavigationDelegate {
    
    private var webView: WKWebView?
    
    // Observable URL property with a default value
    @Published var urlString: String = "https://kinglifyads.vercel.app/detect-me" {
        didSet {
            // When URL changes, automatically load and extract the new text
            loadAndExtractText(from: urlString)
        }
    }
    
    // Observable property for extracted text
    @Published var extractedText: String = "Loading..."
    
    // Initialize with an optional URL (default to "https://example.com")
    init(urlString: String? = nil) {
        super.init()
        
        // Set the URL, either from the parameter or use the default
        self.urlString = urlString ?? "https://kinglifyads.vercel.app/detect-me"
        
        // Set up the WebView configuration
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
       
        // Initialize WKWebView but don't add it to any view hierarchy
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView?.navigationDelegate = self
        
        // Load the initial URL
        loadAndExtractText(from: self.urlString)
    }
    
    // Function to load a URL and extract text
    private func loadAndExtractText(from urlString: String) {

   
        guard let url = URL(string: urlString) else {
            self.extractedText = "Invalid URL"
            return
        }
        
        // Load the URL in the background
        var request = URLRequest(url: url)
      
        //  request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        self.webView?.load(request)
    }
    
    // WKNavigationDelegate method to detect when the page finishes loading
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView finished loading")
        
        // Inject JavaScript to extract text
        let jsScript = "document.body.innerText"
        
        webView.evaluateJavaScript(jsScript) { [weak self] result, error in
            if let error = error {
                print("JavaScript evaluation error: \(error.localizedDescription)")
                self?.extractedText = "Failed to extract text"
            } else if let text = result as? String {
                print("Extracted text: \(text)")
                // Update the @Published property with the extracted text
                self?.extractedText = text
            } else {
                self?.extractedText = "No text found"
            }
        }
    }
    
    deinit {
        webView?.navigationDelegate = nil
        webView = nil
    }
}
