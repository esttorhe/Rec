//  Copyright (c) 2015 Esteban Torres. All rights reserved.

// Native Frameworks
import Foundation

// Third Party Frameworks
import Result
import Box

/**
`NSURLProtocol` subclass that records `NSURLResponse`'s `JSON`.

List of error codes:
    - `-666`: Unable to start loading the request
    - `-667`: Failed to connect to URL
    - `-668`: Unable to correctly parse as a `JSON` response
    - `-669`: Unable to get the `Document`'s directory path
    - `-670`: Unable to extract the request's last path component for file name generation.
    - `-671`: Unable to save file to path
    - `-672`: Unable to get a successful response from URL.
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
            
            recordingProtocol.operationResult = { result in
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
    public var operationResult: ((Result<String, NSError>) -> ())?
    
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
    public class func globalOperationResult(operation: (Result<String, NSError>) -> ()) {
        RecordingProtocolsManager.sharedManager.operationResult = operation
    }
    
    public override var hashValue: Int {
        get {
            if let url = request.URL { return url.hashValue }
            
            return 0
        }
    }
    
    private func processResponse(response: NSURLResponse!, connection: NSURLConnection, data: NSData!, error: NSError!) {
        let result =
        // Check if there was an error reported back
        testError(error, forRequest: connection.originalRequest) >>- { _ in
            Result(connection.currentRequest.URL, failWith: NSError(domain: RecordingProtocol.errorDomain, code: -670,
                userInfo: [NSLocalizedDescriptionKey: "Unable to extract the request's last path component for file name generation."]))
            .analysis(ifSuccess: { url -> Result<NSURL, NSError> in // Extract the request's url
                let docsResult = try { // Get the `Documents` folder path
                    return NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false, error: $0)
                }
                
                return docsResult >>- { docsURL -> Result<NSURL, NSError> in
                    if let lastPathComponent = url.lastPathComponent { // Extract the name of the `URL` request
                        return Result.success(docsURL.URLByAppendingPathComponent(lastPathComponent).URLByAppendingPathExtension("json"))
                    }
                    
                    return Result.failure(NSError(
                        domain: RecordingProtocol.errorDomain,
                        code: -670,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to extract the request's last path component for file name generation."]))
                }
            }, ifFailure: {
                return Result.failure(NSError(
                    domain: RecordingProtocol.errorDomain,
                    code: -669,
                    userInfo: [ NSLocalizedDescriptionKey: "Unable to get the «Document»'s directory path", NSUnderlyingErrorKey: $0]))
            }) >>- { fileUrl -> Result<String, NSError> in
                let finalResult = Result(NSString(data: data, encoding: NSUTF8StringEncoding), failWith: NSError(
                    domain: RecordingProtocol.errorDomain,
                    code: -668,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to correctly parse a `JSON` response for \(connection.originalRequest)"]))
                    >>- { json in // Write the parse `JSON` to disk
                        return try { json.writeToURL(fileUrl, atomically: true, encoding: NSUTF8StringEncoding, error: $0) }
                            >>- { Result.success("Filed saved to \(fileUrl.absoluteString)") }
                    }
                
                // «Cascade up» the success or add our own failure.
                return finalResult ?? Result.failure(NSError(
                        domain: RecordingProtocol.errorDomain,
                        code: -671,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Unable to save file \(fileUrl.lastPathComponent) to here \(fileUrl.absoluteString)",
                            NSUnderlyingErrorKey: finalResult.error!
                        ]))
            }
        }

        if let callback = operationResult {
            callback(result)
        }
    }
    
    /**
        Checks if the provided `error` is not `nil` and its code is different than `0` and 
        returns a `failure` with that error as the underlying one.
    
        Or returns a `success` otherwise.
    
        :param: error The `NSError!` object to be evaluated.
        :param: request The `NSURLRequest` used to construct the internal `NSError`
    
        :returns: A fully initialized `Result<String, NSError>` with either `success` or `failure` depending on the `error` provided.
    */
    private func testError(error: NSError!, forRequest request: NSURLRequest) -> Result<String, NSError> {
        if error != nil && error.code != 0 {
            return Result.failure(
                NSError(
                    domain: RecordingProtocol.errorDomain,
                    code: -672,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Unable to get a successful response for \(request).",
                        NSUnderlyingErrorKey: error
                    ]
                )
            )
        }
        
        return Result.success("No error")
    }
    
    
    
    // MARK: NSURLProtocol
    
    override public var cachedResponse: NSCachedURLResponse? { get { return nil } } // Don't support caching to force loading every request.
    
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
            RecordingProtocolsManager.sharedManager.addProtocol(self)
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {
                response, data, error -> Void in
                // Try to access the protocol's client
                if let client = self.client {
                    // Cascade the «messages» to avoid the calling up from being stuck without response
                    client.URLProtocol(self, didReceiveResponse: response, cacheStoragePolicy: .NotAllowed)
                    client.URLProtocolDidFinishLoading(self)
                }
                
                self.processResponse(response, connection: connection, data: data, error: error)
            }
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
            
            if let client = self.client {
                client.URLProtocol(self, didFailWithError: error)
            }
        }
    }
}

public func == (rec1: RecordingProtocol, rec2: RecordingProtocol) -> Bool {
    return rec1.hashValue == rec2.hashValue
}