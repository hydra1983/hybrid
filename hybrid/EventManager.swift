//
//  EventManager.swift
//  hybrid
//
//  Created by alastair.coote on 15/08/2016.
//  Copyright © 2016 Alastair Coote. All rights reserved.
//

import Foundation
import WebKit
import PromiseKit

/// Only really used for tests - actual code should be in defined handlers
class EventManager: ScriptMessageManager {
    
    var events = EventEmitter<String?>()
    
    init(userController:WKUserContentController, webView:HybridWebview) {
        super.init(userController: userController, webView: webView, handlerName: "events")
    }
    
    override func handleMessage(_ message:[String:Any]) -> Promise<String>? {
        
        
        let eventName = message["name"] as! String
        let eventData = message["data"] as? String
        self.events.emit(eventName, eventData)
        
        return nil
    }
}
