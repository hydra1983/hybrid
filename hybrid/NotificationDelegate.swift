//
//  NotificationDelegate.swift
//  hybrid
//
//  Created by alastair.coote on 24/08/2016.
//  Copyright © 2016 Alastair Coote. All rights reserved.
//

import Foundation
import UserNotifications
import JavaScriptCore
import PromiseKit

class NotificationDelegate : NSObject, UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(center: UNUserNotificationCenter, willPresentNotification notification: UNNotification, withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void) {
        completionHandler(UNNotificationPresentationOptions.Alert)
    }
    
    func checkForNotificationClick(response:UNNotificationResponse) -> Promise<Void> {
        
        if response.actionIdentifier != "com.apple.UNNotificationDefaultActionIdentifier" {
            return Promise<Void>()
        }
        
        let userInfo = response.notification.request.content.userInfo
        let workerScope = userInfo["serviceWorkerScope"] as! String
        let notificationData = userInfo["originalNotificationOptions"]!
        
        return ServiceWorkerManager.getServiceWorkerWhoseScopeContainsURL(NSURL(string: workerScope)!)
        .then { sw in
            let notification = Notification(title: userInfo["originalTitle"] as! String, notificationData: notificationData)
            let event = NotificationEvent(type: "notificationclick", notification: notification)
            
            return sw!.dispatchExtendableEvent(event)
            .then {_ in 
                return Promise<Void>()
            }
        }

    }
    
    func userNotificationCenter(center: UNUserNotificationCenter, didReceiveNotificationResponse response: UNNotificationResponse, withCompletionHandler completionHandler: () -> Void) {
        
        checkForNotificationClick(response)
        .then { () -> Void in
            let pendingActions = PendingWebviewActions.getAll()
            
            pendingActions.forEach { event in
                if event.type == WebviewClientEventType.OpenWindow {
                    
                    let urlToOpen = event.options!["urlToOpen"] as! String
                    
                    AppDelegate.rootController!.pushNewHybridWebViewControllerFor(NSURL(string: urlToOpen)!)
                } else {
                    HybridWebview.processClientEvent(event)
                }
            }
            
            PendingNotificationActions.reset()
            PendingWebviewActions.clear()
            completionHandler()
        }
        
    }
    

    
}

let NotificationDelegateInstance = NotificationDelegate()
