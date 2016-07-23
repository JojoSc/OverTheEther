//
//  WifiClientDelegate.swift
//  OverTheEther
//
//  Created by Johannes Schreiber on 17/02/16.
//  Copyright © 2016 Johannes Schreiber. All rights reserved.
//

import Foundation
import CocoaLumberjack

public protocol WifiClientDelegate : class {

    func discoveredListOfServers(servers:[String])

    func connectionToServerEstablished()
    
    /// percent ranges from 0.0 to 1.0. Might be nan
    func transferFromServerDidProgress(percent:Double)

    func transferToServerDidProgress(percent:Double)

    func didReceiveObjectFromServer(object:AnyObject?)

    func lostConnectionToServer(name:String)

    func connectionToServerFailed(reason:Reason)

    func pingReturned(val:Bool)
}

/// Spare the user from implementing all delegate methods, but notify him if he doesn't
public extension WifiClientDelegate {
    func discoveredListOfServers(servers:[String]) { DDLogVerbose("\(#function)") }
    func didReceiveObjectFromServer(object:AnyObject?) { DDLogVerbose("\(#function)") }
    func lostConnectionToServer(name:String) { DDLogVerbose("\(#function)") }
    func connectionToServerEstablished() { DDLogVerbose("\(#function)") }
    func connectionToServerFailed(reason:Reason) { DDLogVerbose("\(#function)") }
    func transferFromServerDidProgress(percent:Double) { DDLogVerbose("\(#function)") }
    func transferToServerDidProgress(percent:Double) { DDLogVerbose("\(#function)") }
    func pingReturned(val:Bool) { DDLogVerbose("\(#function)") }
}