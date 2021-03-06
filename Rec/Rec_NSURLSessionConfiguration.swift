//  Copyright (c) 2015 Esteban Torres. All rights reserved.

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
            // Swizzle `defaultSessionConfiguration`
            let originalDefaultSelector = Selector("defaultSessionConfiguration")
            let swizzledDefaultSelector = Selector("rec_defaultSessionConfiguration")
            
            let originalDefaultMethod = class_getClassMethod(self, originalDefaultSelector)
            let swizzledDefaultMethod = class_getClassMethod(self, swizzledDefaultSelector)
            
            method_exchangeImplementations(originalDefaultMethod, swizzledDefaultMethod);
            
            // Swizzle `ephemeralSessionConfiguration`
            let originalEphemeralSelector = Selector("ephemeralSessionConfiguration")
            let swizzledEphemeralSelector = Selector("rec_ephemeralSessionConfiguration")
            
            let originalEphemeralMethod = class_getClassMethod(self, originalEphemeralSelector)
            let swizzledEphemeralMethod = class_getClassMethod(self, swizzledEphemeralSelector)
            
            method_exchangeImplementations(originalEphemeralMethod, swizzledEphemeralMethod);
        }
    }
    
    // MARK: - Method Swizzling
    
    /**
    Swizzles `defaultSessionConfiguration` method.
    Internally grabs the same implementation and just appends `RecordingProtocol`.
    
    Also registers `RecordingProtocol` class.
    
    - returns: Fully configure `NSURLSessionConfiguration` with `RecordingProtocol` added to the `protocolClasses`.
    */
    class func rec_defaultSessionConfiguration() -> NSURLSessionConfiguration {
        RecordingProtocol.registerClass(RecordingProtocol)
        let configuration = self.rec_defaultSessionConfiguration()

        // Since `Swift 2.0` had to cast to [AnyObject] in order to correctly add
        // the protocol without crashing.
        // Radar: rdar://21314581
        if var protocols: [AnyObject] = configuration.protocolClasses {
            protocols.append(RecordingProtocol.self as AnyObject)
            configuration.protocolClasses = (protocols as! [AnyClass])
        }
        
        return configuration
    }
    
    /**
    Swizzles `ephemeralSessionConfiguration` method.
    Internally grabs the same implementation and just appends `RecordingProtocol`.
    
    Also registers `RecordingProtocol` class.
    
    - returns: Fully configure `NSURLSessionConfiguration` with `RecordingProtocol` added to the `protocolClasses`.
    */
    class func rec_ephemeralSessionConfiguration() -> NSURLSessionConfiguration {
        RecordingProtocol.registerClass(RecordingProtocol)
        let configuration = self.rec_ephemeralSessionConfiguration()

        // Since `Swift 2.0` had to cast to [AnyObject] in order to correctly add
        // the protocol without crashing.
        // Radar: rdar://21314581
        if var protocols: [AnyObject] = configuration.protocolClasses {
            protocols.append(RecordingProtocol.self as AnyObject)
            configuration.protocolClasses = (protocols as! [AnyClass])
        }
        
        return configuration
    }
}

// MARK: - Imports!

import Foundation