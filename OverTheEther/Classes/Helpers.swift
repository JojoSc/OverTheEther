//
//  WifiServerDelegate.swift
//  OverTheEther
//
//  Created by Johannes Schreiber on 17/02/16.
//  Copyright © 2016 Johannes Schreiber. All rights reserved.
//

import Foundation
import SystemConfiguration

/*
Swift doesn't yet have an array.removeObject() method, so here is one. Removes the first occurence only.
(from http://stackoverflow.com/questions/24938948/array-extension-to-remove-object-by-value )
*/
extension RangeReplaceableCollectionType where Generator.Element : Equatable {
    mutating func removeObject(object : Generator.Element) {
        if let index = self.indexOf(object) {
            self.removeAtIndex(index)
        }
    }
}

/*
http://stackoverflow.com/questions/26086488/detecting-if-the-wifi-is-enabled-in-swift
by Sam
*/
public func isInternetConnected() -> Bool {

    let rechability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "www.apple.com")

    var flags : SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()

    if SCNetworkReachabilityGetFlags(rechability!, &flags) == false {
        return false
    }

    let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
    let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0

    return (isReachable && !needsConnection)
}

public func isWifiConnected() -> Bool {
    let r = Reach()
    return r.connectionStatus().description == ReachabilityStatus.Online(ReachabilityType.WiFi).description
}

/*
func DDLogError(string:String) {print("E: "+string)}
func DDLogWarn(string:String) {print("W: "+string)}
func DDLogDebug(string:String) {print("D: "+string)}
func DDLogInfo(string:String) {print("I: "+string)}
func DDLogVerbose(string:String) {print("V: "+string)}
*/