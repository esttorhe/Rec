
// Native Frameworks
import Foundation

// Dynamic Frameworks
import Quick
import Nimble

// Tested Framework
import Rec

class RecSpec: QuickSpec {
    override func spec() {
        describe("Injects `Rec` as a protocol") {
            it("creates a new `NSURLSession` that contains `Rec` as a protocol") {
                let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
                if let protocolClasses = session.configuration.protocolClasses {
                    expect(protocolClasses.filter { (element) in
                        return element === Rec.RecordingProtocol
                    }.count).to(equal(1))
                }
            }
        }
    }
}