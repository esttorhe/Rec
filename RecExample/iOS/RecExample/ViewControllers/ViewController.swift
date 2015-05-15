
// Native Frameworks
import UIKit

// Dynamic Frameworks
import Rec

class ViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: configuration)
        let url = NSURL(string: "http://jsonplaceholder.typicode.com/posts")!
        var request = NSMutableURLRequest(URL: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // This is added to know the location of each request's file
        RecordingProtocol.globalOperationResult {
            result in
            let gMessage: String
            
            switch result {
                case .Success(let message):
                    gMessage = "• 🎉 Success: \(message)"
                    println("\(gMessage)")
                case .Failure(let error):
                    gMessage = "• 😨 Error: \(error)"
                    println("\(gMessage)")
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.textView.text = gMessage
            })
        }
        
        let task = session.dataTaskWithRequest(request) {
            (data, response, error) -> Void in
            // Here we have an example of how the «hijacked» request returned everything as expected
            let message: String
            
            if error != nil && error.code != 0 {
                println("• 😨 Error: \(error)")
                message = error.localizedDescription
            } else {
                println("• 🎉 Response: \(response)")
                message = "\(response)"
            }
            
            let alert = UIAlertView(
                title: "📢 Response 📢",
                message: message,
                delegate: nil,
                cancelButtonTitle: nil,
                otherButtonTitles: "OK")
            
            dispatch_async(dispatch_get_main_queue(), {
                alert.show()
            })
        }
        
        task.resume()
    }
}

