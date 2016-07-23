//
//  CommunicationProtocol.swift
//  PartyMasterSwift
//
//  Created by Johannes Schreiber on 15/12/15.
//  Copyright © 2015 Johannes Schreiber. All rights reserved.
//

import Foundation


@objc enum Reason : Int {
    case RequiresPasscode = 2
    case Other            = 3
}

enum MessageType : String {
    case REQAskIfPinIsNeeded = "REQAskIfPinIsNeeded"
    case ACKNoPinIsNotNeeded = "ACKNoPinIsNotNeeded"
    case ACKYesPinIsNeeded   = "ACKYesPinIsNeeded"
    case ACKClientIsAbleToSend = "ACKClientIsAbleToSend"

    

    //Handled in client, since the server sends the pin
    //case REQSendingPin   = "REQSendingPin"
    //case ACKPinIsCorrect = "ACKPinIsCorrect"
    //case ACKPinIsFalse   = "ACKPinIsFalse"
}


class HandShake : NSObject, NSCoding {

    var type:MessageType

    // Optional Payload
    var passcode:String?

    required init(type:MessageType) {
        self.type = type
    }

    required init(coder aDecoder:NSCoder) {
        type = MessageType(rawValue: aDecoder.decodeObjectForKey("type") as! String)!
        passcode = aDecoder.decodeObjectForKey("passcode") as? String
    }

    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(type.rawValue, forKey: "type")
        aCoder.encodeObject(passcode, forKey: "passcode")
    }
}

