import Foundation
import SystemConfiguration
import WebKit

@objc(DConnectionErrorDetector) class DConnectionErrorDetector : CDVPlugin {
    
    var timeoutTimer = NSTimer();
    
    override func pluginInitialize() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "pageDidLoad:", name: "CDVPageDidLoadNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "pageDidStart:", name: "CDVPluginResetNotification", object: nil)
    }
    
    
    func pageDidLoad(notification : NSNotification) {
        stopTimeoutTimer();
    }
    
    func pageDidStart(notification : NSNotification) {
        if (isConnectedToNetwork()) {
            startTimeoutTimer();
        }
        else {
            print("Not connected!")
            handlePageError()
        }
    }
    
    func startTimeoutTimer() {
        print("Timeout timer started")
        timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(TIMEOUT_SECONDS, target: self, selector: "timerFired", userInfo: nil, repeats: false)
    }
    
    func stopTimeoutTimer() {
        print("Timeout timer stopped")
        timeoutTimer.invalidate();
    }
    
    func timerFired() {
        print("Page Timeout!");
        handlePageError()
    }
    
    
    // Determines internet connectivity
    // http://stackoverflow.com/a/30743763/1192877
    func isConnectedToNetwork() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        let defaultRouteReachability = withUnsafePointer(&zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
    
    func handlePageError() {
        NSNotificationCenter.defaultCenter().postNotificationName("DLoadingOverlaySetVisibleNotification", object: false)
        
        // Show alert dialog giving the user options
        let alertController = UIAlertController(title: "Connection lost", message: "Your connection has timed out.  This often occurs when internet connection is lost.  Please retry when you have reconnected.", preferredStyle: .Alert)
        
        let cancelAction = UIAlertAction(title: "Home", style: .Cancel) { (action:UIAlertAction!) in
            print("User chose to navigate home")
            if (self.webView is UIWebView) {
                (self.webView as! UIWebView).loadRequest(NSURLRequest(URL: NSURL(string: BASE_URL)!))
            }
            else if (self.webView is WKWebView) {
                (self.webView as! WKWebView).loadRequest(NSURLRequest(URL: NSURL(string: BASE_URL)!))
            }
        }
        alertController.addAction(cancelAction)
        
        let OKAction = UIAlertAction(title: "Retry", style: .Default) { (action:UIAlertAction!) in
            print("User chose to retry request")
            if (self.webView is UIWebView) {
                (self.webView as! UIWebView).reload()
            }
            else if (self.webView is WKWebView) {
                (self.webView as! WKWebView).reload()
            }
        }
        alertController.addAction(OKAction)
        
        self.viewController!.presentViewController(alertController, animated: true, completion:nil)
    }
}
