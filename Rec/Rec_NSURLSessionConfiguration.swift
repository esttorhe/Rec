
/**
    Class extension that allows `Rec` to automatically intercepts all calls without
    the need for the user to manually replace the `NSSession` calls.
*/
extension NSURLSessionConfiguration {
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        // make sure this isn't a subclass
        if self !== NSURLSessionConfiguration.self {
            return
        }
        
        dispatch_once(&Static.token) {
            let originalSelector = Selector("defaultSessionConfiguration")
            let swizzledSelector = Selector("rec_defaultSessionConfiguration")
            
            let originalMethod = class_getClassMethod(self, originalSelector)
            let swizzledMethod = class_getClassMethod(self, swizzledSelector)
            
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }
    
    // MARK: - Method Swizzling
    
    /**
    Swizzles `defaultSessionConfiguration` method.
    Internally grabs the same implementation and just appends `RecordingProtocol`.
    
    Also registers `RecordingProtocol` class.
    
    :returns: Fully configure `NSURLSessionConfiguration` with `RecordingProtocol` added to the `protocolClasses`.
    */
    class func rec_defaultSessionConfiguration() -> NSURLSessionConfiguration {
        RecordingProtocol.registerClass(RecordingProtocol)
        
        let configuration = self.rec_defaultSessionConfiguration()
        configuration.protocolClasses?.insert(RecordingProtocol.self as AnyObject, atIndex: 0)
        
        return configuration
    }
}