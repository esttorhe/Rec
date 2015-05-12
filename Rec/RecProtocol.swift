
// Native Frameworks
import Foundation

// Third Party Frameworks
import Result
import Box

/** 
`NSURLProtocol` subclass that records `NSURLResponse`'s `JSON`.
*/
public class RecordingProtocol: NSURLProtocol, NSURLConnectionDelegate, NSURLConnectionDataDelegate, Hashable {
    // MARK: RecordingProtocolsManager
    
    /**
        Internal singleton class that will hold all instances and responses of `RecordingProtocol`
    */
    private class RecordingProtocolsManager {
        /**
            Shared Instance
        */
        static let sharedManager = RecordingProtocolsManager()
        
        /**
            Array of `RecordingProtocol` for reporting back the results of each.
        */
        private var requests = [Int:RecordingProtocol]()
        
        /**
            «Dummy» variable used for «locking» when adding new requests.
        */
        private let lock = "LOCK"
        
        /**
            «Callback» function to report back the result of each request.
        */
        var operationResult: ((Result<String, NSError>) -> ())?
        
        init() {}
        
        /**
            Adds a new instance of `RecordingProtocol` to the list of saved requests
            to report back the result of each.
        */
        func addProtocol(recordingProtocol: RecordingProtocol) {
            objc_sync_enter(lock)
            requests[recordingProtocol.hashValue] = recordingProtocol
            
            recordingProtocol.operationResult = {
                result in
                if let opResult = self.operationResult {
                    opResult(result)
                    objc_sync_enter(self.lock)
                    self.requests.removeValueForKey(recordingProtocol.hashValue)
                    objc_sync_exit(self.lock)
                }
            }
            
            objc_sync_exit(lock)
        }
    }
    
    
    
    // MARK: - RecordingProtocol
    
    private let data: NSMutableData
    private var connection: NSURLConnection?
    
    /**
        Custom `HTTP Header` field used to avoid infinite cycle when «hijacking» the `NSURLRequest`
    */
    private static let ignoreRequestHTTPHeaderKey = "IGNORE"
    
    /**
        µFramework's error domain for all instances of `NSError` generated internally.
    */
    private static let errorDomain = "es.estebantorr.Rec"
    
    /**
        «Callback» function reporting back wether or not the recording operation was a success.
    */
    public var operationResult: ((Result<String, NSError>) -> ())?
    
    override init(request: NSURLRequest, cachedResponse: NSCachedURLResponse?, client: NSURLProtocolClient?) {
        let mRequest: NSMutableURLRequest = request.mutableCopy() as! NSMutableURLRequest
        mRequest.setValue(RecordingProtocol.ignoreRequestHTTPHeaderKey, forHTTPHeaderField: RecordingProtocol.ignoreRequestHTTPHeaderKey)
        data = NSMutableData()
        operationResult = nil
        
        super.init(request: mRequest, cachedResponse: cachedResponse, client: client)
    }
    
    /**
    «Global callback» for all requests operations.

    Should be called like this:
    
        RecordingProtocol.globalOperationResult {
            result in
                switch result {
                case .Success(let message):
                    println("🎉 Successfully saved fixtures: \(message)")
                case .Failure(let error):
                    println("Something went wrong: \(error)")
                }
        }
    */
    public class func globalOperationResult(operation: (Result<String, NSError>) -> ()) {
        RecordingProtocolsManager.sharedManager.operationResult = operation
    }
    
    public override var hashValue: Int {
        get {
            if let conn = connection {
                if let url = conn.originalRequest.URL {
                    return url.hashValue
                }
            }
            
            return 0
        }
    }
    
   
    
    // MARK: NSURLProtocol
    
    public override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        if let stop = request.valueForHTTPHeaderField(RecordingProtocol.ignoreRequestHTTPHeaderKey) {
            return false // We are already «eavesdropping» this request
        }
        
        if let url = request.URL {
            if let scheme = url.scheme {
                if let acceptContent = request.valueForHTTPHeaderField("Accept") {
                    // Only supporting http|https schemes
                    // and `JSON` responses
                    return scheme.hasPrefix("http") && acceptContent == "application/json"
                }
            }
        }
        
        return false
    }
    
    override public class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    override public func startLoading() {
        if let connection = NSURLConnection(request: request, delegate: self) {
            self.connection = connection
            RecordingProtocolsManager.sharedManager.addProtocol(self)
            connection.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
            connection.start()
        } else {
            if let callback = operationResult {
                let error = NSError(domain: RecordingProtocol.errorDomain, code: -666, userInfo: [NSLocalizedDescriptionKey: "Unable to start loading request: \(request.URL)"])
                callback(Result.failure(error))
            }
        }
    }
    
    
    
    // MARK: NSURLConnectionDelegate
    
    public func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        if let callback = operationResult {
            let internalError = NSError(
                domain: RecordingProtocol.errorDomain,
                code: -667,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to connect to \(connection.originalRequest)",
                    NSUnderlyingErrorKey: error
                ])
            callback(Result.failure(internalError))
        }
    }
    
    
    
    // MARK: NSURLConnectionDataDelegate
    
    public func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        self.data.appendData(data)
    }
    
    public func connectionDidFinishLoading(connection: NSURLConnection) {
        if let json = NSString(data: self.data, encoding: NSUTF8StringEncoding) { // We try to decode the `JSON` response
            if let url = connection.currentRequest.URL {
                let error = NSErrorPointer()
                if let docsURL = NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false, error: error) {
                    if let lastPathComponent = url.lastPathComponent {
                        let fileURL = docsURL.URLByAppendingPathComponent(lastPathComponent).URLByAppendingPathExtension("json")
                        var result: Result<String, NSError>
                        if data.writeToURL(fileURL, atomically: true) {
                            result = Result.success("Filed saved to \(fileURL.absoluteString)")
                        } else {
                            let internalError = NSError(
                                domain: RecordingProtocol.errorDomain,
                                code: -671,
                                userInfo: [NSLocalizedDescriptionKey: "Unable to save file \(fileURL.lastPathComponent) to here \(fileURL.absoluteString)"]
                            )
                            result = Result.failure(internalError)
                        }
                        
                        if let callback = operationResult {
                            callback(result)
                        }
                    } else {
                        if let callback = operationResult {
                            let internalError = NSError(
                                domain: RecordingProtocol.errorDomain,
                                code: -670,
                                userInfo: [NSLocalizedDescriptionKey: "Unable to extract the request's last path component for the file generation."])
                            callback(Result.failure(internalError))
                        }
                    }
                } else {
                    if let callback = operationResult {
                        var userInfo:[String: AnyObject] = [NSLocalizedDescriptionKey: "Unable to get the «Document»'s directory path"]
                        if let memError = error.memory {
                            userInfo.updateValue(memError, forKey: NSUnderlyingErrorKey)
                        }
                        
                        let internalError = NSError(
                            domain: RecordingProtocol.errorDomain,
                            code: -669,
                            userInfo: userInfo)
                        callback(Result.failure(internalError))
                    }
                }
            }
        } else { // We were not able to parse the JSON response
            if let callback = operationResult {
                let internalError = NSError(
                    domain: RecordingProtocol.errorDomain,
                    code: -668,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to correctly parse a `JSON` response for \(connection.originalRequest)"])
                callback(Result.failure(internalError))
            }
        }
    }
}

public func == (rec1: RecordingProtocol, rec2: RecordingProtocol) -> Bool {
    return rec1.hashValue == rec2.hashValue
}