//  Copyright (c) 2015 Esteban Torres. All rights reserved.

// Native Frameworks
import Foundation

public enum Either<Value> {
    case Success(Value)
    case Error(ErrorType)
}

/// `RecordingProtocol` errors.
public enum RecordingError: ErrorType {
    /// Unable to start loading the request
    case UnableToStartLoadingRequest
    /// Failed to connect with NSURLRequest
    case FailedToConnectToWithRequest(NSURLRequest)
    /// Unable to correctly parse as a `JSON` response
    case UnableToCorrectlyParseAsJSON(NSURLRequest)
    /// Unable to get the `Document`'s directory path
    case UnableToGetDocumentsDirectoryPath
    /// Unable to extract the request's last path component for file name generation.
    case UnableToExtractRequestsLastPath(NSURLRequest)
    /// Unable to save file to path
    case UnableToSaveFileToPath(String)
    /// Unable to get a successful response from URL.
    case UnableToGetSuccessfullResponseFromRequest(NSURLRequest)
}

/**
`NSURLProtocol` subclass that records `NSURLResponse`'s `JSON`.
*/
public class RecordingProtocol: NSURLProtocol, NSURLConnectionDelegate, NSURLConnectionDataDelegate {
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
        var operationResult: (Either<String> -> ())?
        
        init() {}
        
        /**
            Adds a new instance of `RecordingProtocol` to the list of saved requests
            to report back the result of each.
        */
        func addProtocol(recordingProtocol: RecordingProtocol) {
            objc_sync_enter(lock)
            requests[recordingProtocol.hashValue] = recordingProtocol
            
            recordingProtocol.operationResult = { result -> () in
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
    public var operationResult: (Either<String> -> ())?
    
    override init(request: NSURLRequest, cachedResponse: NSCachedURLResponse?, client: NSURLProtocolClient?) {
        let mRequest: NSMutableURLRequest = request.mutableCopy() as! NSMutableURLRequest
        mRequest.setValue(RecordingProtocol.ignoreRequestHTTPHeaderKey, forHTTPHeaderField: RecordingProtocol.ignoreRequestHTTPHeaderKey)
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
    public class func globalOperationResult(operation: Either<String> -> ()) {
        RecordingProtocolsManager.sharedManager.operationResult = operation
    }
    
    public override var hashValue: Int {
        get {
            if let url = request.URL { return url.hashValue }
            
            return 0
        }
    }
    
    private func processResponse(response: NSURLResponse!, connection: NSURLConnection, data: NSData!, error: NSError!) throws {
        // Check if there was an error reported back
        if error.code != 0 {
            throw RecordingError.UnableToGetSuccessfullResponseFromRequest(connection.originalRequest)
        }
        
        // Extract the url from the current request (if possible).
        guard let url = connection.currentRequest.URL else {
            throw RecordingError.UnableToExtractRequestsLastPath(connection.currentRequest)
        }
        
        // Get the `Documents` folder path
        let docsURL: NSURL
        do {
            docsURL = try NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        } catch {
            throw RecordingError.UnableToGetDocumentsDirectoryPath
        }
        
        // Extract the name of the `URL` request
        guard let lastPathComponent = url.lastPathComponent else {
            throw RecordingError.UnableToExtractRequestsLastPath(connection.currentRequest)
        }
        
        // Build the full file url.
        let fileURL = docsURL.URLByAppendingPathComponent(lastPathComponent).URLByAppendingPathExtension("json")
        
        // Convert the returned data to `JSON`.
        guard let json = NSString(data: data, encoding: NSUTF8StringEncoding) else {
            throw RecordingError.UnableToCorrectlyParseAsJSON(connection.originalRequest)
        }
        
        // Write the `JSON` to disk.
        do {
            try json.writeToURL(fileURL, atomically: true, encoding: NSUTF8StringEncoding)
        } catch {
            throw RecordingError.UnableToSaveFileToPath(fileURL.absoluteString)
        }
    }
    
    
    // MARK: NSURLProtocol
    
    override public var cachedResponse: NSCachedURLResponse? { get { return nil } } // Don't support caching to force loading every request.
    
    public override class func canInitWithRequest(request: NSURLRequest) -> Bool {
        guard let _ = request.valueForHTTPHeaderField(RecordingProtocol.ignoreRequestHTTPHeaderKey) else {
            return false // We are already «eavesdropping» this request
        }
        
        if let url = request.URL {
            if let acceptContent = request.valueForHTTPHeaderField("Accept") {
                // Only supporting http|https schemes
                // and `JSON` responses
                return url.scheme.hasPrefix("http") && acceptContent == "application/json"
            }
        }
        
        return false
    }
    
    override public class func canonicalRequestForRequest(request: NSURLRequest) -> NSURLRequest {
        return request
    }
    
    override public func startLoading() {
        if let connection = NSURLConnection(request: request, delegate: self) {
            RecordingProtocolsManager.sharedManager.addProtocol(self)

            NSURLConnection.sendAsynchronousRequest(request, queue: .mainQueue(), completionHandler: { (response, data, error) -> Void in
                // Try to access the protocol's client
                if let client = self.client, response = response {
                    // Cascade the «messages» to avoid the calling up from being stuck without response
                    client.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
                    client.URLProtocolDidFinishLoading(self)
                }
                
                do { try self.processResponse(response, connection: connection, data: data, error: error) }
                catch is RecordingError {
                    print("`RecordingProtocol` returned a recognized `RecordingError`.")
                } catch {
                    print("Unexpected error while processing the request.")
                }
            })
        } else {
            operationResult?(Either.Error(RecordingError.UnableToStartLoadingRequest))
        }
    }
    
    
    
    // MARK: NSURLConnectionDelegate
    
    public func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        operationResult?(Either.Error(RecordingError.FailedToConnectToWithRequest(connection.originalRequest)))
        if let client = self.client {
            client.URLProtocol(self, didFailWithError: error)
        }
    }
}

public func == (rec1: RecordingProtocol, rec2: RecordingProtocol) -> Bool {
    return rec1.hashValue == rec2.hashValue
}