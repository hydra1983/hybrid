//
//  AppDelegate.swift
//  hybrid
//
//  Created by Alastair Coote on 4/30/16.
//  Copyright © 2016 Alastair Coote. All rights reserved.
//

import UIKit
import PromiseKit
import EmitterKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    static var window: UIWindow?
    static var rootController:HybridNavigationController?
    
    func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
        UNUserNotificationCenter.currentNotificationCenter().delegate = NotificationDelegateInstance
        return true
    }
    
    static var runningInTests:Bool {
        get {
            return NSClassFromString("XCTest") != nil
        }
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        SharedSettings.storage.setValue("NO", forKey: "RECEIVE_EVENT_REACHED")
        log.setup(.Debug, showLogIdentifier: false, showFunctionName: false, showThreadName: true, showLogLevel: true, showFileNames: false, showLineNumbers: false, showDate: false, writeToFile: nil, fileLogLevel: nil)
        
        do {
            try Db.createMainDatabase()
            try DbMigrate.migrate()
            
            try WebServer.initialize()
            
            PushManager.listenForDeviceToken()
            
            application.registerForRemoteNotifications()
                       
            // Copy over js-dist. Future improvements might be to allow this to be updated over the wire
            // Needs to be copied so notification extension can access it.
            
            let jsDistTargetURL = Fs.sharedStoreURL.URLByAppendingPathComponent("js-dist")!

            
            
            if NSFileManager.defaultManager().fileExistsAtPath(jsDistTargetURL.path!) == true {
                // need to tidy all this up. Shouldn't overwrite on every open
                try NSFileManager.defaultManager().removeItemAtURL(jsDistTargetURL)
            }
            
            
            let jsDistURL = NSURL(fileURLWithPath: NSBundle.mainBundle().bundlePath)
                .URLByAppendingPathComponent("js-dist")!
            
            try NSFileManager.defaultManager().copyItemAtURL(jsDistURL, toURL: jsDistTargetURL)

            
            AppDelegate.window = UIWindow(frame: UIScreen.mainScreen().bounds);
            
            
            
            let rootController = HybridNavigationController.create()
            
            if AppDelegate.runningInTests == false {
                // todo: remove
                ServiceWorkerManager.clearActiveServiceWorkers()
                try Db.mainDatabase.inDatabase({ (db) in
                    db.executeUpdate("DELETE FROM service_workers", withArgumentsInArray: nil)
                })

//                 rootController.pushNewHybridWebViewControllerFor(NSURL(string:"https://www.gdnmobilelab.com/app-demo")!)
                
                rootController.pushNewHybridWebViewControllerFor(NSURL(string:"https://alastairtest.ngrok.io/app-demo")!)
            }
            
            
            AppDelegate.rootController = rootController
        
            AppDelegate.window!.rootViewController = rootController
            
            AppDelegate.window!.makeKeyAndVisible();

            return true
            
            
        } catch {
            print(error);
            return false;
        }
        
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        NSLog("HIT DID RECEIVE THING")
        completionHandler(UIBackgroundFetchResult.NewData)
    }
    


    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        ApplicationEvents.emit("didRegisterForRemoteNotificationsWithDeviceToken", deviceToken)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        ApplicationEvents.emit("didFailToRegisterForRemoteNotificationsWithError", error)
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        NSLog("Enter Background")
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        NSLog("Enter foreground")
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
//        WebServer.current!.stop()
        NSLog("Did Terminate")
    }
    
    
}

