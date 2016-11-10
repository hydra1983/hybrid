//
//  ServiceWorkerInstance.swift
//  hybrid
//
//  Created by alastair.coote on 08/07/2016.
//  Copyright © 2016 Alastair Coote. All rights reserved.
//

import Foundation
import JavaScriptCore
import PromiseKit
import ObjectMapper
import FMDB

class JSContextError : ErrorType {
    let message:String
    let stack:String?
    
    init(message:String){
        self.message = message
        self.stack = nil
        
    }
    
    init(jsValue:JSValue) {
        if jsValue.isObject == true {
            let dict = jsValue.toObject() as! [String: String]
            if let message = dict["message"] {
                self.message = message
                self.stack = dict["stack"]
            } else {
                var msg = ""
                for (key, val) in dict {
                    msg = msg + key + " : " + val
                }
                self.message = msg
                self.stack = nil
            }
        } else {
            self.message = jsValue.toString()
            self.stack = nil
        }
       
        
        
    }

}



struct PromiseReturn {
    let fulfill:(JSValue) -> Void
    let reject:(ErrorType) -> Void
}

class ServiceWorkerOutOfScopeError : ErrorType {
    
}

@objc protocol ServiceWorkerInstanceExports : JSExport {
    var scriptURL:String {get}
}

@objc public class ServiceWorkerInstance : NSObject, ServiceWorkerInstanceExports {
    
    var jsContext:JSContext!
    var cache:ServiceWorkerCacheHandler!
    var contextErrorValue:JSValue?
    let url:NSURL!
    let scope:NSURL!
    let timeoutManager = ServiceWorkerTimeoutManager()
    var registration: ServiceWorkerRegistration?
    let webSQL: WebSQLDatabaseCreator!
    var clientManager:WebviewClientManager?
    
    var installState:ServiceWorkerInstallState!
    let instanceId:Int
    
    var scriptURL:String {
        get {
            return self.url.absoluteString!
        }
    }
    
    var state:String {
        get {
            if self.installState == ServiceWorkerInstallState.Activated {
                return "activated"
            }
            if self.installState == ServiceWorkerInstallState.Activating {
                return "activating"
            }
            if self.installState == ServiceWorkerInstallState.Installed {
                return "installed"
            }
            if self.installState == ServiceWorkerInstallState.Installing {
                return "installing"
            }
            if self.installState == ServiceWorkerInstallState.Redundant {
                return "redundant"
            }
            return ""
         }
    }
    
    
    var pendingPromises = Dictionary<Int, PromiseReturn>()
    
    init(url:NSURL, scope: NSURL?, instanceId:Int, installState: ServiceWorkerInstallState) {
        
        self.url = url
        if (scope != nil) {
            self.scope = scope
        } else {
            self.scope = url.URLByDeletingLastPathComponent
        }
        
        self.installState = installState
        self.instanceId = instanceId
        
        let urlComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)!
        urlComponents.path = nil
        self.jsContext = JSContext()
        self.webSQL = WebSQLDatabaseCreator(context: self.jsContext, origin: urlComponents.URLString)
        
        
        
        super.init()
        
        
        
        
        self.jsContext.exceptionHandler = self.exceptionHandler
        self.jsContext.name = url.absoluteString
        self.cache = ServiceWorkerCacheHandler(jsContext: self.jsContext, serviceWorkerURL: url)
        GlobalFetch.addToJSContext(self.jsContext)
        
        self.registration = ServiceWorkerRegistration(worker: self)
        self.clientManager = WebviewClientManager(serviceWorker: self)
        
        self.hookFunctions()
        
        if ServiceWorkerManager.currentlyActiveServiceWorkers[instanceId] != nil {
            NSLog("THIS SHOULD NOT OCCUR")
        }
        
        ServiceWorkerManager.currentlyActiveServiceWorkers[instanceId] = self
    }
    
    static func getActiveWorkerByURL(url:NSURL) -> Promise<ServiceWorkerInstance?> {
        
        var instance:ServiceWorkerInstance? = nil
        var contents:String? = nil
        
        return Promise<Void>()
        .then {
            try Db.mainDatabase.inDatabase({ (db) in
                
                let serviceWorkerContents = try db.executeQuery("SELECT instance_id, scope, contents FROM service_workers WHERE url = ? AND install_state = ?", values: [url.absoluteString!, ServiceWorkerInstallState.Activated.rawValue])
                
                if serviceWorkerContents.next() == false {
                    return serviceWorkerContents.close()
                }
                
                let scope = NSURL(string: serviceWorkerContents.stringForColumn("scope"))!
                let instanceId = Int(serviceWorkerContents.intForColumn("instance_id"))
                
                instance = ServiceWorkerInstance(
                    url: url,
                    scope: scope,
                    instanceId: instanceId,
                    installState: ServiceWorkerInstallState.Activated
                )
                
                log.debug("Created new instance of service worker with ID " + String(instanceId) + " and install state: " + String(instance!.installState))
                contents = serviceWorkerContents.stringForColumn("contents")
                serviceWorkerContents.close()
            })
            
            if instance == nil {
                return Promise<ServiceWorkerInstance?>(nil)
            }
            
            return instance!.loadServiceWorker(contents!)
                .then { _ in
                    return instance
            }

        }

    }
    
   
    static func getById(id:Int) -> Promise<ServiceWorkerInstance?> {
        
        log.debug("Request for service worker with ID " + String(id))
        return Promise<Void>()
        .then { () -> Promise<ServiceWorkerInstance?> in
            
            let existingWorker = ServiceWorkerManager.currentlyActiveServiceWorkers[id]
            
            if existingWorker != nil {
                log.debug("Returning existing service worker for ID " + String(id))
                return Promise<ServiceWorkerInstance?>(existingWorker)
            }
            
            
            var instance:ServiceWorkerInstance? = nil
            var contents:String? = nil
            
            try Db.mainDatabase.inDatabase({ (db) in
                
                let serviceWorkerContents = try db.executeQuery("SELECT url, scope, contents, install_state FROM service_workers WHERE instance_id = ?", values: [id])
                
                if serviceWorkerContents.next() == false {
                    return serviceWorkerContents.close()
                }
                
                let url = NSURL(string: serviceWorkerContents.stringForColumn("url"))!
                let scope = NSURL(string: serviceWorkerContents.stringForColumn("scope"))!
                let installState = ServiceWorkerInstallState(rawValue: Int(serviceWorkerContents.intForColumn("install_state")))!
                
                instance = ServiceWorkerInstance(
                    url: url,
                    scope: scope,
                    instanceId: id,
                    installState: installState
                )
                
                log.debug("Created new instance of service worker with ID " + String(id) + " and install state: " + String(instance!.installState))
                contents = serviceWorkerContents.stringForColumn("contents")
                serviceWorkerContents.close()
            })
            
            if instance == nil {
                return Promise<ServiceWorkerInstance?>(nil)
            }
            
            return instance!.loadServiceWorker(contents!)
            .then { _ in
                return instance
            }
            
        }
        
    }
    
    func receiveMessage(message:String, ports: [MessagePort]) {
        self.jsContext.objectForKeyedSubscript("hybrid")
            .objectForKeyedSubscript("dispatchMessageEvent")
            .callWithArguments([message, ports])
    }
    
    func scopeContainsURL(url:NSURL) -> Bool {
        return url.absoluteString!.hasPrefix(self.scope.absoluteString!)
    }
    
    
    func hookFunctions() {
        
        let promiseCallbackAsConvention: @convention(block) (JSValue, JSValue, JSValue) -> Void = self.nativePromiseCallback
        self.jsContext.setObject(unsafeBitCast(promiseCallbackAsConvention, AnyObject.self), forKeyedSubscript: "__promiseCallback")

        self.timeoutManager.hookFunctions(self.jsContext)
        
        self.jsContext.setObject(MessagePort.self, forKeyedSubscript: "MessagePort")
        
        self.jsContext.setObject(self.registration, forKeyedSubscript: "__serviceWorkerRegistration")
        self.jsContext.setObject(PushManager.self, forKeyedSubscript: "PushManager")
        self.jsContext.setObject(Console.self, forKeyedSubscript: "NativeConsole")
        self.jsContext.setObject(self.clientManager, forKeyedSubscript: "clients")
        self.jsContext.setObject(MessageChannel.self, forKeyedSubscript: "MessageChannel")
        self.jsContext.setObject(WebviewClient.self, forKeyedSubscript: "Client")
        self.jsContext.setObject(MessageEvent.self, forKeyedSubscript: "MessageEvent")
        self.jsContext.setObject(MessagePort.self, forKeyedSubscript: "MessagePort")
        self.jsContext.setObject(OffscreenCanvas.self, forKeyedSubscript: "OffscreenCanvas")
        self.jsContext.setObject(TwoDContext.self, forKeyedSubscript: "CanvasRenderingContext2D")
        self.jsContext.setObject(ImageBitmap.self, forKeyedSubscript: "ImageBitmap")
    }
    

    private func jsPromiseCallback(pendingIndex: Int, fulfillValue:AnyObject?, rejectValue: AnyObject?) {
        let funcToRun = self.jsContext
            .objectForKeyedSubscript("hybrid")
            .objectForKeyedSubscript("promiseCallback")
        if rejectValue != nil {
            funcToRun.callWithArguments([pendingIndex, NSNull(), rejectValue!])
        } else {
            
            // TODO: investigate this. callWithArguments doesn't seem to like ? variables,
            // but I'm not sure why.
            
            var fulfillValueToReturn:AnyObject = NSNull()
            if fulfillValue != nil {
                fulfillValueToReturn = fulfillValue!
            }
            
            funcToRun.callWithArguments([pendingIndex, fulfillValueToReturn, NSNull()])
        }
        
    }
    
    private func nativePromiseCallback(pendingIndex: JSValue, error: JSValue, response: JSValue) {
        let pendingIndexAsInt = Int(pendingIndex.toInt32())
        if (error.isNull == false) {
            pendingPromises[pendingIndexAsInt]?.reject(JSContextError(jsValue: error))
        } else {
            pendingPromises[pendingIndexAsInt]?.fulfill(response)
        }
        pendingPromises.removeValueForKey(pendingIndexAsInt)
    }
    
    private func getVacantPromiseIndex() -> Int {
        // We can't use an array because we need the indexes to stay consistent even
        // when an entry has been removed. So instead we check every index until we
        // find an empty one, then use that.
        
        var pendingIndex = 0
        while pendingPromises[pendingIndex] != nil {
            pendingIndex += 1
        }
        return pendingIndex
    }
    
    func executeJSPromise(js:String) -> Promise<JSValue> {
        
        // We can't use an array because we need the indexes to stay consistent even
        // when an entry has been removed. So instead we check every index until we
        // find an empty one, then use that.
        
        let pendingIndex = self.getVacantPromiseIndex()
       
        return Promise<JSValue> { fulfill, reject in
            pendingPromises[pendingIndex] = PromiseReturn(fulfill: fulfill, reject: reject)
            self.runScript("hybrid.promiseBridgeBackToNative(" + String(pendingIndex) + "," + js + ");",closeDatabasesAfter: false)
            .error { err in
                reject(err)
            }
        } .always {
            // We don't want to auto-close DB connections after runScript because the promise
            // will continue to execute after that. So instead, we tidy up our webSQL connections
            // once the promise has fulfilled (or errored out)
            //self.webSQL.closeAll()
        }
    }
    
    func executeJS(js:String) -> JSValue {
        return self.jsContext.evaluateScript(js)
    }
    
    func dispatchExtendableEvent(name: String, data: AnyObject?) -> Promise<JSValue?> {
        
        
        let funcToRun = self.jsContext.objectForKeyedSubscript("hybrid")
            .objectForKeyedSubscript("dispatchExtendableEvent")
        
            
        let dispatch = data == nil ? funcToRun.callWithArguments([name]) : funcToRun.callWithArguments([name, data!])

        
        return PromiseBridge<JSValue>(jsPromise: dispatch)

    }
    
    func dispatchFetchEvent(fetch: FetchRequest) -> Promise<FetchResponse?> {
        
        let dispatch = self.jsContext.objectForKeyedSubscript("hybrid")
            .objectForKeyedSubscript("dispatchFetchEvent")
            .callWithArguments([fetch])
        
        return PromiseBridge<FetchResponse>(jsPromise: dispatch)
    }
    
    func dispatchPushEvent(data: String) -> Promise<Void> {
        let dispatch = self.jsContext.objectForKeyedSubscript("hybrid")
            .objectForKeyedSubscript("dispatchPushEvent")
            .callWithArguments([data])
        
        return PromiseBridge<NSObject>(jsPromise: dispatch)
        .then { returnValue in
            
            // It isn't actually possible to return anything from this, but
            // we still want to return a promise so that we can wait to know
            // the promise has completed if we want to.
            
            return Promise<Void>()
            
        }
    }
    
    func loadServiceWorker(workerJS:String) -> Promise<Void> {
        return self.loadContextScript()
        .then {_ in
            return self.runScript(workerJS)
        }
        .then { _ in
            return self.processPendingPushEvents()
        }
    }
    
    func processPendingPushEvents() -> Promise<Void> {
        
        // Unfortunately, we can't necessarily process push events as they arrive because
        // the app may not be active. So, whenever we create a service worker, we immediately
        // process any pending push events that happen to be waiting.
        
        let pendingPushes = PushEventStore.getByWorkerScope(self.scope.absoluteString!)
        
        let processPromises = pendingPushes.map { push in
            return self.dispatchPushEvent(push.payload)
                .then {
                    PushEventStore.remove(push)
            }
            
        }
        
        return when(processPromises)

    }
    
    private func loadContextScript() -> Promise<JSValue> {
        
        return Promise<String> {fulfill, reject in
            
            let workerContextPath = Fs.sharedStoreURL
                .URLByAppendingPathComponent("js-dist", isDirectory: true)!
                .URLByAppendingPathComponent("worker-context")!
                .URLByAppendingPathExtension("js")!
                .path!
           
            let contextJS = try NSString(contentsOfFile: workerContextPath, encoding: NSUTF8StringEncoding) as String
            fulfill(contextJS)
        }.then { js in
            return self.runScript("var self = {}; var global = self; hybrid = {}; var window = global; var navigator = {}; navigator.userAgent = 'Hybrid service worker';" + js)
        }.then { js in
            
            return self.applyGlobalVariables()
        }
    }
    
    func applyGlobalVariables() -> Promise<JSValue> {
        // JSContext doesn't have a 'global' variable so instead we make our own,
        // then go through and manually declare global variables.
        
        let keys = self.jsContext.evaluateScript("Object.keys(global);").toArray() as! [String]
        var globalsScript = ""
        for key in keys {
            globalsScript += "var " + key + " = global['" + key + "']; false;";
        }
        log.info("Global variables: " + keys.joinWithSeparator(", "))
        
        return self.runScript(globalsScript)

    }

    
    func runScript(js: String, closeDatabasesAfter: Bool = true) -> Promise<JSValue> {
        self.contextErrorValue = nil
        return Promise<JSValue> { fulfill, reject in
            let result = self.jsContext.evaluateScript(js)
            if (self.contextErrorValue != nil) {
                let errorText = self.contextErrorValue!.toString()
                reject(JSContextError(message:errorText))
            } else {
                fulfill(result)
            }
        }.always {
            if (closeDatabasesAfter == true) {
                // There is no standard hook on closing WebSQL connections, so we handle
                // it manually. We assume we'll close unless told otherwise (as we do with
                // promises)
               // self.webSQL.closeAll()
            }
        }
    }
    
    
    func exceptionHandler(context:JSContext!, exception:JSValue!) {
        self.contextErrorValue = exception
        
        log.error("JSCONTEXT error: " + exception.toString() + exception.objectForKeyedSubscript("stack").toString())
        
    }
    
//    func getURLInsideServiceWorkerScope(url: NSURL) throws -> NSURL {
//        
//        //let startRange = self.scope.absoluteString.ra
//        let range = url.absoluteString!.rangeOfString(self.scope.absoluteString!)
//        
//        if range == nil || range!.startIndex != self.scope.absoluteString!.startIndex {
//            throw ServiceWorkerOutOfScopeError()
//        }
//        
//        let escapedServiceWorkerURL = self.url.absoluteString!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.alphanumericCharacterSet())!
//        
//        
//        let returnComponents = NSURLComponents(string: "http://localhost")!
//        returnComponents.port = WebServer.current!.port
//        
//        let pathComponents:[String] = [
//            "__service_worker",
//            escapedServiceWorkerURL,
//            url.host!,
//            url.path!.substringFromIndex(url.path!.startIndex.advancedBy(1))
//        ]
//        
//        
//        returnComponents.path = "/" + pathComponents.joinWithSeparator("/")
//        NSLog(pathComponents.joinWithSeparator("/"))
//        return returnComponents.URL!
//
//        
//        //stringByAddingPercentEncodingWithAllowedCharacters
//    }
}
