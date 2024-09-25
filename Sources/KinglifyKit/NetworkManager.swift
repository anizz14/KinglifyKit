import Foundation

class NetworkManager {
    
    static let shared = NetworkManager() // Singleton instance
    
    private init() {}
    
    // Unified function to perform GET or POST requests
    func sendRequest(to url: URL, method: String, body: [String: Any]? = nil, completion: @escaping (Result<Any, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if method == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let body = body {
                request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
            }
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(error))
                return
            }
            
            // Try to parse the response data as JSON
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: [])
                completion(.success(jsonResponse))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
}
