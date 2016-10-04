import Foundation
import SystemConfiguration
import WebKit

@objc(DConnectionErrorDetector) class DConnectionErrorDetector : CDVPlugin {
    
    var timeoutTimer = Timer();
    var homeUrl:String = "";
    var timeoutSeconds:Double = 30;
    var pageDidStartNotification = Notification.Name("")
    
    override func pluginInitialize() {
        pageDidStartNotification = Notification.Name("CDVPluginResetNotification")
        homeUrl = commandDelegate.settings["homeurl"] as! String;
        timeoutSeconds = Double(commandDelegate.settings["timeoutseconds"] as! String)!;
        
        NotificationCenter.default.addObserver(self, selector: #selector(DConnectionErrorDetector.pageDidLoad), name: NSNotification.Name(rawValue: "CDVPageDidLoadNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(DConnectionErrorDetector.pageDidStart), name: pageDidStartNotification, object: nil)
    }
    
    
    func pageDidLoad() {
        stopTimeoutTimer();
    }
    
    func pageDidStart() {
        if (isConnectedToNetwork()) {
            startTimeoutTimer();
        }
        else {
            print("Not connected!", terminator: "\n")
            handlePageError()
        }
    }
    
    func startTimeoutTimer() {
        print("Timeout timer started", terminator: "\n")
        timeoutTimer = Timer.scheduledTimer(timeInterval: timeoutSeconds, target: self, selector: #selector(DConnectionErrorDetector.timerFired), userInfo: nil, repeats: false)
    }
    
    func stopTimeoutTimer() {
        print("Timeout timer stopped", terminator: "\n")
        timeoutTimer.invalidate();
    }
    
    func timerFired() {
        print("Page Timeout!", terminator: "\n");
        handlePageError()
    }
    
    
    // Determines internet connectivity
    // http://stackoverflow.com/a/25623647
    func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return (isReachable && !needsConnection)
    }
    
    func handlePageError() {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "DLoadingOverlaySetVisibleNotification"), object: false)
        
        // Show alert dialog giving the user options
        let alertController = UIAlertController(title: "Connection lost", message: "Your connection has timed out.  This often occurs when internet connection is lost.  Please retry when you have reconnected.", preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Home", style: .cancel) { (action:UIAlertAction) in
            print("User chose to navigate home", terminator: "\n")
            NotificationCenter.default.post(name: self.pageDidStartNotification, object: nil)
            if (self.webView is UIWebView) {
                (self.webView as! UIWebView).loadRequest(NSURLRequest(url: NSURL(string: self.homeUrl)! as URL) as URLRequest)
            }
            else if (self.webView is WKWebView) {
                (self.webView as! WKWebView).load(NSURLRequest(url: NSURL(string: self.homeUrl)! as URL) as URLRequest)
            }
        }
        alertController.addAction(cancelAction)
        
        let OKAction = UIAlertAction(title: "Retry", style: .default) { (action:UIAlertAction) in
            print("User chose to retry request", terminator: "\n")
            NotificationCenter.default.post(name: self.pageDidStartNotification, object: nil)
            if (self.webView is UIWebView) {
                (self.webView as! UIWebView).reload()
            }
            else if (self.webView is WKWebView) {
                (self.webView as! WKWebView).reload()
            }
        }
        alertController.addAction(OKAction)
        
        self.viewController!.present(alertController, animated: true, completion:nil)
    }
}
