import Foundation
import StoreKit


open class KinglifyAnalitics: ObservableObject,KinglifyHandler {
    
    @Published var refId: String?
    @Published var offerId: String?

    var ip = ""
    var hash = ""
    var backendURL = backend_url
    private let refIdKey = "refId"
    private let offerIdKey = "offerId"
    private let bundleId: String
    
    // Initialization
    public init(
        serverUrl: String?=backend_url,
        detectmeUrl: String? = detectme_url,
        detectmewaittime:Float?=detectme_wait_time
    ) {
        
        let currentRefId = UserDefaults.standard.string(forKey: refIdKey)
        let currentOfferId = UserDefaults.standard.string(forKey: offerIdKey)
        self.refId = currentRefId
        self.offerId = currentOfferId
        
        print("Current RefId and Offer ID")
        print(currentRefId)
        print(currentOfferId)
        
        self.bundleId = Bundle.main.bundleIdentifier ?? ""
        self.backendURL = serverUrl ?? backend_url
        self.setupWebViewManager(urlString: detectmeUrl,waitTime: detectmewaittime)
        
       
       
      
    }
    
    private func checkIfFirstLaunch() {
           let defaults = UserDefaults.standard
           let isFirstLaunch = !defaults.bool(forKey: "hasLaunchedBefore")
           if isFirstLaunch {
               defaults.set(true, forKey: "hasLaunchedBefore")
           }
        if(isFirstLaunch){
            self.sendEvent(type:"download")
        }else{
            print("App is not launched for first time")
//               kinglifyAnalitics?.sendEvent(type:"download")
        }
        
       }
    
    private func setupWebViewManager(urlString: String? = nil,waitTime:Float? = 3.0) {
        
       var deviceInfo =  WebViewTextExtractor(urlString: urlString)
        
        let actualWaitTime = TimeInterval(waitTime ?? 3.0)
        
       
        DispatchQueue.main.asyncAfter(deadline: .now() + actualWaitTime) {
            let data = self.extractIPAndHash(from: deviceInfo.extractedText);
            
            
            
            // Access extracted IP and hash
            let ip = data.ip // Assume data.ip is a non-optional String
            let hash = data.hash // Assume data.hash is a non-optional String

            if !ip.isEmpty, !hash.isEmpty {
                print("IP: \(ip)")
                print("Hash: \(hash)")
                print("Extraction successful.")
                
                self.setIpAndHash(ip: ip, hash: hash);
                
                
                

            } else {
                print("Failed to extract IP address and hash.")
            }
        }
    }
    
    
    
   
    
    
 
    

    
    // Extract IP and hash from text using markers
    func extractIPAndHash(from text: String) -> (ip: String, hash: String) {
        
       
        func extractBetweenMarkers(_ text: String, start: String, end: String) -> String? {
            guard let startRange = text.range(of: start),
                  let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
                return nil
            }
            return String(text[startRange.upperBound..<endRange.lowerBound])
        }

        let ip = extractBetweenMarkers(text, start: "@@@@@", end: "@@@@@") ?? ""
        let hash = extractBetweenMarkers(text, start: "#####", end: "#####") ?? ""
        return (ip, hash)
    }
    
    // Set IP and hash, then send hash to server
    func setIpAndHash(ip: String, hash: String) {
        self.ip = ip
        self.hash = hash
        
        print("IP: \(ip), Hash: \(hash)")
        sendHashToServer(hash: hash)
    }
    
    // Send hash to the server
    private func sendHashToServer(hash: String) {
        guard let url = URL(string: "\(backendURL)/storehash/\(hash)") else {
            print("Invalid backend URL")
            return
        }

        NetworkManager.shared.sendRequest(to: url, method: "GET") { result in
            switch result {
            case .success(let jsonResponse):
                
              
                guard let jsonResponse = jsonResponse as? [String: Any],
                      let data = jsonResponse["data"] as? [String: Any] else {
                    print("Failed to cast JSON response")
                    return
                }
                print("HASH RESPONSE")
                print(jsonResponse)
                
                // Safely extract refId and offerId
                if let refId = data["refId"] as? String {
                    self.refId = refId
                    self.saveRefId(refId)
                }
                
                if let offerId = data["offerId"] as? String {
                    self.offerId = offerId
                    self.saveOfferId(offerId)
                }
                
                
     
                
                self.checkIfFirstLaunch()
                
            case .failure(let error):
                print("Error sending hash to server: \(error.localizedDescription)")
                self.checkIfFirstLaunch()
            }
        }
    }
    
    // Save refId and offerId to UserDefaults
    func saveRefId(_ refId: String) {
        UserDefaults.standard.set(refId, forKey: refIdKey)
        print("RefId saved: \(refId)")
    }
    
    func saveOfferId(_ offerId: String) {
        UserDefaults.standard.set(offerId, forKey: offerIdKey)
        print("OfferId saved: \(offerId)")
    }
    
    // Retrieve stored refId and offerId
    func retrieveRefId() -> String {
        return UserDefaults.standard.string(forKey: refIdKey) ?? "unknown"
    }
    
    func retrieveOfferId() -> String {
        return UserDefaults.standard.string(forKey: offerIdKey) ?? "unknown"
    }
    
    public func handleIncomingURL(_ url: URL) {
        
        
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("Invalid URL components")
            return
        }
        
        let pathComponents = urlComponents.path.split(separator: "/").filter { !$0.isEmpty }
        let offerId = pathComponents.first.map(String.init)
        let refId = pathComponents.dropFirst().first.map(String.init)
        
        let offerIdString = offerId ?? ""
        let refIdString = refId ?? ""
        
       
            // Safely store refId and offerId if they are not empty
        if !refIdString.isEmpty {
                self.refId = refIdString
                self.saveRefId(refIdString)
        }

        if !offerIdString.isEmpty {
                self.offerId = offerIdString
                self.saveOfferId(offerIdString)
        }
    }
    
    // Send transaction details to the server
    public func sendTransaction(transaction: Transaction) async {
        guard let url = URL(string: "\(backendURL)/transaction") else {
            print("Invalid backend URL")
            return
        }

        guard let data = transaction.jsonRepresentation as? Data else {
            print("Failed to access JSON representation as Data.")
            return
        }

        let base64String = data.base64EncodedString()
        print("Base64 Encoded String: \(base64String)")

        guard let jsonData = Data(base64Encoded: base64String),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let body = try? JSONSerialization.jsonObject(with: jsonString.data(using: .utf8)!) as? [String: Any] else {
            print("Failed to decode Base64 or convert to JSON.")
            return
        }

        // Create the modified body with additional data
        var modifiedBody = body
        addTransactionIdentifiers(to: &modifiedBody)

        do {
            try await NetworkManager.shared.sendRequest(to: url, method: "POST", body: modifiedBody) { result in
                print(result)
            }
            print("Transaction sent successfully")
        } catch {
            print("Failed to send transaction: \(error)")
        }
    }

    // Add identifiers to the transaction body
    private func addTransactionIdentifiers(to body: inout [String: Any]) {
        body["refId"] = refId
        body["offerId"] = offerId
    }

    
    // Send receipt to the server for validation
    public func sendReceiptToServer(receiptData: String) async {
       
       
        
        let urlString = "\(backendURL)/validateReceipt"
        guard let url = URL(string: urlString) else {
            print("Invalid backend URL")
            return
        }

        let body: [String: Any] = [
            "receiptData": receiptData,
            "refId": refId,
            "offerId": offerId,
            "bundleId": bundleId
        ]

        do {
            try await NetworkManager.shared.sendRequest(to: url, method: "POST", body: body) { result in
                switch result {
                case .success(let jsonResponse):
                    if let jsonResponse = jsonResponse as? [String: Any] {
                        print("Receipt validation response: \(jsonResponse)")
                    } else {
                        print("Failed to parse JSON response")
                    }
                case .failure(let error):
                    print("Error sending receipt to server: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error sending receipt: \(error.localizedDescription)")
        }
    }
    
    
    public func sendLog(_ message:String){
        guard let url = URL(string: "\(backendURL)/app-log") else {
            print("Invalid backend URL")
            return
        }
        
        print("SENDING LOGS..................")
        
        // Fallback to "unknown" if the device ID is not available
           let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        
            print(deviceId,"fffffff")
           
           let body: [String: Any] = [
               "event": message,
               "deviceId": deviceId
           ]
        NetworkManager.shared.sendRequest(to: url, method: "POST", body: body) { result in
            switch result {
            case .success(let jsonResponse):
                if let jsonResponse = jsonResponse as? [String: Any] {
                    print("JSON Response: \(jsonResponse)")
                } else {
                    print("Failed to cast JSON response to [String: Any]")
                }
            case .failure(let error):
                print("Error sending event to server: \(error.localizedDescription)")
            }
        }
        
        
    }
    
    // Send event details to the server
    public func sendEvent(type: String) {
        guard let url = URL(string: "\(backendURL)/event") else {
            print("Invalid backend URL")
            return
        }
        
        print("SENDING EVENT..........")

        let body: [String: Any] = [
            "type": type,
            "offerId": offerId ?? "unknown",
            "refId": refId ?? "unknown",
            "ip": ip,
            "deviceName": DeviceInfo.getDeviceName(),
            "os": DeviceInfo.getOSVersion(),
            "bundleId": bundleId
        ]

        NetworkManager.shared.sendRequest(to: url, method: "POST", body: body) { result in
            switch result {
            case .success(let jsonResponse):
                if let jsonResponse = jsonResponse as? [String: Any] {
                    print("JSON Response: \(jsonResponse)")
                } else {
                    print("Failed to cast JSON response to [String: Any]")
                }
            case .failure(let error):
                print("Error sending event to server: \(error.localizedDescription)")
            }
        }
    }
}
