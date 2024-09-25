import SwiftUI

// Protocol that both KinglifyStore and KinglifyAnalytics should conform to
public protocol KinglifyHandler {
    func handleIncomingURL(_ url: URL)
}


public struct KinglifyAppWrapper<Content: View>: View {
    
    var handler: KinglifyHandler // Reference to KinglifyStore
    
    let content: Content
    
    public init(content: Content,handler:KinglifyHandler) {
        self.content = content
        self.handler = handler
    }
    
    public var body: some View {
        content.onOpenURL(perform: { url in
            handler.handleIncomingURL(url)
        })
    }
}
