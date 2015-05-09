
// Native Frameworks
import UIKit

// Pod
import Rec

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: configuration)
        let url = NSURL(string: "http://getat-stage.railwaymen.org/api/v1/discover/tags?access_token=aef6c0853c5e168a16342964ee415b46ba6d373b6a4f5fdb957fe3bfd7943da1")!
        var request = NSMutableURLRequest(URL: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        if let protocols = configuration.protocolClasses {
            if let recProtocol: AnyObject = (protocols.filter {
                prot in
                return prot.isKindOfClass(RecordingProtocol)
            }.first) {
                (recProtocol as! RecordingProtocol).operationResult = {
                    result in
                    switch result {
                    case .Success(let message):
                        println("Score: \(message)")
                    case .Failure(let error):
                        println("Buuu: \(error)")
                    }
                }
            }
        }

        let task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            println("• Response: \(response)")
            println("• Error: \(error)")
        }
        
        task.resume()
    }
}

