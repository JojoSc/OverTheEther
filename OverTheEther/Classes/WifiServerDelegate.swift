//
//  WifiServerDelegate.swift
//  OverTheEther
//
//  Created by Johannes Schreiber on 17/02/16.
//  Copyright © 2016 Johannes Schreiber. All rights reserved.
//

import CocoaAsyncSocket
import CocoaLumberjack

public protocol WifiServerDelegate : class{

    func didReceiveData(data:AnyObject?, fromClient client:GCDAsyncSocket)

    /// Percent has a value between 0.0 and 1.0
    func transferDidProgress(percent:Double)

    func clientConnected(client:GCDAsyncSocket)

    func clientDisconnected(client:GCDAsyncSocket)
}

/// Spare the user from implementing all delegate methods, but notify him if he doesn't
public extension WifiServerDelegate {
    func didReceiveData(data:AnyObject?, fromClient client:GCDAsyncSocket) { DDLogVerbose("\(#function)") }
    func transferDidProgress(percent:Double) { DDLogVerbose("\(#function)") }
    func clientConnected(client:GCDAsyncSocket) { DDLogVerbose("\(#function)") }
    func clientDisconnected(client:GCDAsyncSocket) { DDLogVerbose("\(#function)") }
}
