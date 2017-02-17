//
//  ServiceWorkerManager.swift
//  hybrid
//
//  Created by alastair.coote on 08/02/2017.
//  Copyright © 2017 Alastair Coote. All rights reserved.
//

import Foundation
import HybridServiceWorker
import HybridShared
import PromiseKit


/// This class manages the lifecycle of app service worker instances, primarily installing, updating
/// and changing the status of connected workers accordingly (e.g. setting an older worker to redundant
/// once a new version has been installed)
public class ServiceWorkerManager {
    
    var activeServiceWorkers = Set<ServiceWorkerInstanceBridge>()
    let store = ServiceWorkerStore()
    
    let lifecycleEvents = EventEmitter<ServiceWorkerInstanceBridge>()
    
    public init() {

    }
    
    
    /// Destroys all currently active service workers and removes them from the
    /// currentlyActiveServiceWorkers set.
    public func clearActiveServiceWorkers() {
        
        self.activeServiceWorkers.forEach { active in
            active.instance.destroy()
        }
        
        self.activeServiceWorkers.removeAll()
    }
    
    public func getAllWorkers(forScope: URL, includingChildScopes: Bool) -> Promise<[ServiceWorkerInstance]> {
        
        return Promise(value: ())
        .then {
            
            let matchingWorkers = try self.store.getAllWorkerRecords(forScope: forScope, includingChildScopes: includingChildScopes)
            
            // We don't re-create redunant workers. They might be present if they became redundant during the lifecycle
            // of a ServiceWorkerRegistration, but never on load.
            let matchingNonRedundantWorkers = matchingWorkers.filter { $0.installState != ServiceWorkerInstallState.redundant }
            
            let workerCreatePromises = matchingNonRedundantWorkers.map { self.getOrCreateWorker(forId: $0.id) }
            
            return when(fulfilled: workerCreatePromises)
            .then { results in
                return Promise(value: results.map { $0.instance })
            }
            
        }
        
        
    }
    
    func getOrCreateWorker(forId: Int) -> Promise<ServiceWorkerInstanceBridge> {
        
        return Promise(value: ())
        .then {
            
            let existingWorker = self.activeServiceWorkers.filter { $0.id == forId }.first
            
            if existingWorker != nil {
                return Promise(value: existingWorker!)
            }
            
            let contents = try self.store.getWorkerContent(byId: forId)
            let record = try self.store.getAllWorkerRecords(forIds: [forId]).first!
            
            return ServiceWorkerInstanceBridge.create(record: record, contents: contents, manager: self)
            .then { activeWorker in
                self.activeServiceWorkers.insert(activeWorker)
                return Promise(value: activeWorker)
            }
        }
        
    }
    
    
    /// Because there are security implications for allowing service workers, we manually control
    /// which domains are allowed to install service workers via this app and which are not.
    public func workerURLIsAllowed(url:URL) -> Bool {
        return SharedResources.allowedServiceWorkerDomains.contains("*") == false &&
            SharedResources.allowedServiceWorkerDomains.contains(url.host!) == false
    }
    
    
    /// An attempt to mirror ServiceWorkerRegistration.update(), as outlined here:
    /// https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/update
    ///
    /// - Parameters:
    ///   - url: URL of the worker to download
    ///   - scope: The scope we're updating - need to supply, unlike in the Web API
    /// - Returns: A promise that resolves to nil if update was successful (this includes
    ///            an update that was not needed). Throws if we can't check.
    public func update(url: URL, scope: URL) -> Promise<Void> {
        return Promise(value: ())
        .then { () -> Promise<FetchResponse> in
                
            if self.workerURLIsAllowed(url: url) == false {
                log.error("Attempt to register a worker on a forbidden URL:" + url.absoluteString)
                throw ErrorMessage("Domain is not in the list of approved worker domains")
            }
            
            log.info("Attempting to update worker at URL: " + url.absoluteString)
            
            let existingWorkers = try self.store.getAllWorkerRecords(forURL: url, withScope: scope)
            
            // TODO: if we already have an activating worker, wait?
            
            // If a worker already exists for this URL and scope, we want to grab the ETag
            // and Last-Modified headers for that worker. That way, if the remote content
            // hasn't changed we'll just get a 304.
            
            var lastModified:String? = nil
            var eTag:String? = nil
            
            // There should only be one active worker. But just in case, we'll get the most
            // recent one.
            
            let mostRecentActiveWorker = existingWorkers
                .filter { $0.installState == ServiceWorkerInstallState.activated }
                .sorted { $1.id > $0.id }
                .first
            
            if mostRecentActiveWorker != nil {
                log.info("Existing worker found, attaching headers from previous response")
            } else {
                log.info("No existing worker, requesting without additional headers")
            }
            
            lastModified = mostRecentActiveWorker?.headers.get("last-modified")
            eTag = mostRecentActiveWorker?.headers.get("etag")
            
            let requestHeaders = FetchHeaders()
            
            if let lastModifiedExists = lastModified {
                requestHeaders.set("If-Modified-Since", value: lastModifiedExists)
            }
            
            if let eTagExists = eTag {
                requestHeaders.set("If-None-Match", value: eTagExists)
            }
            
            let request = FetchRequest(url: url.absoluteString, options: ["headers": requestHeaders])
            
            return GlobalFetch.fetch(request: request)
        }
        .then { response in
            
            if response.status == 304 {
                log.info("Request for worker returned a 304 not-modified status. Returning.")
                return Promise(value: ())
            }
            
            if response.ok == false {
                log.info("Request for worker returned a non-OK response: " + String(response.status))
                // If we're not OK and it isn't a 304, it's not a response we're expecting.
                throw ErrorMessage("Attempt to update worker resulted in status code " + String(response.status))
            }
            
            log.info("Request for worker returned an OK response, installing new worker...")
            return self.installServiceWorker(url: url, scope: scope, response: response)
        }

    }
    
    func installServiceWorker(url: URL, scope: URL, response: FetchResponse) -> Promise<Void> {
        return response.text()
        .then { contents in
            
            let newWorkerId = try self.store.insertWorkerIntoDatabase(url, scope: scope, contents: contents, headers: response.headers)
            
            return self.getOrCreateWorker(forId: newWorkerId)
            .then { worker in
                
                log.info("Running install event for worker...")
                let installEvent = ExtendableEvent(type: "install")
                
                return worker.instance.dispatchExtendableEvent(installEvent)
                .then {
                    let allWorkersForURL = try self.store.getAllWorkerRecords(forURL: url, withScope: scope)
                    
                    // Shouldn't really happen, but there's a chance there is already a worker in the installed
                    // state. If so, we need to clear it out.
                    
                    var updateInstructions = allWorkersForURL
                        .filter { $0.installState == ServiceWorkerInstallState.installed }
                        .map { UpdateStatusInstruction(id: $0.id, newState: ServiceWorkerInstallState.redundant) }
                    
                    log.info("Worker installed successfully, setting " + String(updateInstructions.count) + " workers to redundant and this to installed")
                    
                    // Then set our new worker to installed state.
                    updateInstructions.append(UpdateStatusInstruction(id: newWorkerId, newState: ServiceWorkerInstallState.installed))
                    
                    // Actually run the updates
                    try self.updateWorkerStatuses(updateInstructions)
                    
                    if worker.instance.skipWaitingStatus == true {
                        log.info("Worker called skipWaiting(), activating immediately")
                        return self.activateServiceWorker(worker: worker.instance, id: newWorkerId)
                    } else {
                        log.info("Worker did not call skipWaiting(), leaving at installed status")
                    }
                    
                    return Promise(value:())
                    
                }
                
            }
            .catch { err in
                log.error("Encountered error when installing worker: " + String(describing: err))
                
                // If installation failed, set the worker to redundant
                do {
                    try self.updateWorkerStatuses([UpdateStatusInstruction(id: newWorkerId, newState: ServiceWorkerInstallState.redundant)])
                } catch {
                    // Not much we can do at this point
                    log.error("Also encountered error when trying to update worker to redundant: " + String(describing: error))
                }
                
            }
            
        }
    }
    
    
    func activateServiceWorker(worker: ServiceWorkerInstance, id: Int) -> Promise<Void> {
        
        return Promise(value:())
        .then {
            // Set to activating status before we do anything else
            try self.updateWorkerStatuses([UpdateStatusInstruction(id: id, newState: ServiceWorkerInstallState.activating)])
            
            // Then fire our activate event
            let activateEvent = ExtendableEvent(type: "activate")
            
            return worker.dispatchExtendableEvent(activateEvent)
        }
        .then {
            let allWorkers = try self.store.getAllWorkerRecords(forURL: worker.url, withScope: worker.scope)
            
            // If we've successfully activated, we now want to set the active worker for this URL
            // to redundant, as well as set this one to active.
            
            var updateInstructions = allWorkers
                .filter { $0.installState == ServiceWorkerInstallState.activated }
                .map { UpdateStatusInstruction(id: $0.id, newState: ServiceWorkerInstallState.redundant) }
            
            updateInstructions.append(UpdateStatusInstruction(id: id, newState: ServiceWorkerInstallState.activated))
            
            try self.updateWorkerStatuses(updateInstructions)
            
            return Promise(value: ())
        }
        .catch { err -> Void in
            log.error("Encountered error when activating worker: " + String(describing: err))
            
            // If activation failed, set the worker to redundant
            do {
                try self.updateWorkerStatuses([UpdateStatusInstruction(id: id, newState: ServiceWorkerInstallState.redundant)])
            } catch {
                // Not much we can do at this point
                log.error("Also encountered error when trying to update worker to redundant: " + String(describing: error))
            }
            
            
        }
        
    }
    
    func updateWorkerState(id: Int, newStatus: ServiceWorkerInstallState) throws {
     
        try Db.mainDatabase.inTransaction { db in
            
            try db.executeUpdate("UPDATE service_workers SET install_state = ? WHERE id = ?", values: [newStatus.rawValue, id])
        
        }
        
        
    }
    
    
    /// We do these in bulk so that we can wrap them all in a transaction - if one fails, they all will.
    func updateWorkerStatuses(_ statuses: [UpdateStatusInstruction]) throws {
        
        try Db.mainDatabase.inTransaction { db in
            
            try statuses.forEach { statusUpdate in
                try db.executeUpdate("UPDATE service_workers SET install_state = ? WHERE id = ?", values: [statusUpdate.newState.rawValue, statusUpdate.id])
            }
            
        }
        
        // Go through all of our active workers, set statuses accordingly
        
        statuses.forEach { update in
            
            // If this instance is currently active then we need to make sure that
            // any registration using it is updated accordingly
            
            let activeInstance = self.activeServiceWorkers.filter { $0.id == update.id }.first
            
            if activeInstance == nil {
                return
            }
            
            self.lifecycleEvents.emit("statechange", activeInstance!)

        }
        
    }
    
}