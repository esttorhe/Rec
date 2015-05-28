
// Native Frameworks
import Foundation

// Dynamic Frameworks
import Quick
import Nimble

// Tested Framework
import Rec

class RecSpec: QuickSpec {
    override func spec() {
        describe("Rec") {
            describe("injects itself") {
                context("when a new `NSURLSession` is created with `defaultsessionConfiguration`") {
                    it("should contain `Rec` as a registered protocol") {
                        let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
                        if let protocolClasses = session.configuration.protocolClasses {
                            expect(protocolClasses.filter { (element) in
                                return element === Rec.RecordingProtocol
                                }.count).to(equal(1))
                        }
                    }
                }
                
                context("when a new `NSURLSession` is created with `ephemeralSessionConfiguration`") {
                    it("should contain `Rec` as a registered protocol") {
                        let session = NSURLSession(configuration: NSURLSessionConfiguration.ephemeralSessionConfiguration())
                        if let protocolClasses = session.configuration.protocolClasses {
                            expect(protocolClasses.filter { (element) in
                                return element === Rec.RecordingProtocol
                                }.count).to(equal(1))
                        }
                    }
                }
            }
            
            describe("should answer to init requests") {
                context("when asked if it can handle `JSON` responses") {
                    it("should answer positively") {
                        let request = NSMutableURLRequest(URL: NSURL(string: "http://jsonplaceholder.typicode.com/posts")!)
                        request.addValue("application/json", forHTTPHeaderField: "Accept")
                        expect(RecordingProtocol.canInitWithRequest(request)).to(beTruthy())
                    }
                }
                
                context("when asked if it can handle anything but `JSON` responses") {
                    it("should answer negatively") {
                        let request = NSMutableURLRequest(URL: NSURL(string: "http://jsonplaceholder.typicode.com/posts")!)
                        if let headerFields = request.allHTTPHeaderFields {
                            if let acceptKey = (headerFields.keys.filter { $0 == "Accept" }.array.first) {
                                request.allHTTPHeaderFields?.removeValueForKey(acceptKey)
                                request.addValue("application/xml", forHTTPHeaderField: "Accept")
                            }
                        }
                        
                        expect(RecordingProtocol.canInitWithRequest(request)).to(beFalsy())
                    }
                }
                
                context("when no `Accept` HTTP Header is provided") {
                    it("should answer negatively") {
                        let request = NSMutableURLRequest(URL: NSURL(string: "http://jsonplaceholder.typicode.com/posts")!)
                        expect(RecordingProtocol.canInitWithRequest(request)).to(beFalsy())
                    }
                }
            }
        }
    }
}