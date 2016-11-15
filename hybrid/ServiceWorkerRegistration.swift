//
//  ServiceWorkerRegistration.swift
//  hybrid
//
//  Created by alastair.coote on 23/08/2016.
//  Copyright © 2016 Alastair Coote. All rights reserved.
//

import Foundation
import UserNotifications
import JavaScriptCore
import PromiseKit

@objc protocol ServiceWorkerRegistrationExports : JSExport {
    var pushManager:PushManager {get}
    var scope:String {get}
    var active:ServiceWorkerInstance? {get}
    func showNotification(title:String, options: [String:AnyObject])
    func updateCallback(success:JSValue, failure:JSValue)
}

@objc class ServiceWorkerRegistration: NSObject, ServiceWorkerRegistrationExports {
    var pushManager:PushManager
    var worker:ServiceWorkerInstance
    
    
    // We use this in our notification extension - in the web APIs push and notifications
    // are totally separate, but they aren't in iOS. So, if we happen to be running inside
    // the extension and intercepting a notification, rather than run the normal local
    // notification show functions, we call this content handler.
    
    static var notificationExtensionContentHandler: ((UNNotificationContent) -> Void)? = nil
    
    static let WORKER_ID = "workerID"
    
    var scope:String {
        get {
            return self.worker.scope.absoluteString!
        }
    }
    
    var active:ServiceWorkerInstance? {
        get {
            // Could expand logic here - current worker could (maybe?) be installing, but another worker
            // still be active
            return self.worker.installState == ServiceWorkerInstallState.Activated ? self.worker : nil
        }
    }
    
    init(worker:ServiceWorkerInstance) {
        self.pushManager = PushManager()
        self.worker = worker
    }
    
    
    func showNotification(title:String, options: [String:AnyObject]) {
        
        let payload = [
            "title": title,
            "options": options
        ]
        
        PayloadToNotificationContent.Convert(payload, serviceWorkerScope: self.scope)
        .then { content -> Void in
            
            // We use a UUID because remote notifications can't change their identifier. This means
            // we have to manually manage replacing notifications with the same tag. Bah.
            
            let request = UNNotificationRequest(identifier: NSUUID().UUIDString, content: content, trigger: nil)
            
            UNUserNotificationCenter.currentNotificationCenter().addNotificationRequest(request) { (err) in
                NSLog(String(err))
            }
        }
        .recover  { err -> Void in
            log.error("Failed to post notification: " + String(err))
        }
       
    }
    
    func updateCallback(success:JSValue, failure: JSValue) {
        ServiceWorkerManager.update(self.worker.url, scope: nil, forceCheck: true)
        .then { serviceWorkerId -> Void in
            success.callWithArguments([])
        }
        .error { err in
            failure.callWithArguments([JSValue(newErrorFromMessage: String(err), inContext: failure.context)])
        }
    }
}
