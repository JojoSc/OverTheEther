//
//  ViewController.swift
//  OverTheEther
//
//  Created by JojoSc on 07/23/2016.
//  Copyright (c) 2016 JojoSc. All rights reserved.
//

import UIKit
import OverTheEther
import CocoaAsyncSocket


class ViewController: UIViewController {

    let server = WifiServer()
    let client = WifiClient()


    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the delegates so we receive notifications
        server.delegate = self
        client.delegate = self

        // Look for nearby devices that declared themselves as servers
        client.discoverServers()

        // If after 3 seconds...
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(3 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {

            // ...the client has not yet connected to a server...
            let clientCanSend = self.client.isConnected() && self.client.isAllowedToSend
            if !clientCanSend {

                // ... we start our own server...
                self.server.startServer(name: "OTEServer", infoDict: nil)

                // ...and stop the client from searching (because the device would connect to itself)
                self.client.stopDiscoveringServers()
            }
        }

    }
}




extension ViewController : WifiClientDelegate {

    func discoveredListOfServers(servers: [String]) {
        print("Found these servers nearby: \(servers)")

        // Connect to the first server in the list. At this point we can't yet send any data.
        client.connectToServer(servers[0])
    }


    func connectionToServerEstablished() {

        // Send a short text message
        let data = "Hello World"
        client.sendObject(data)
    }


    func didReceiveObjectFromServer(object: AnyObject?) {

        // Print the object the server sent
        if let message = object as? String {
            print("The server sent this string: '\(message)'")
        } else {
            print("The server sent this object: \(object)")
        }
    }
}




extension ViewController : WifiServerDelegate {

    func clientConnected(client: GCDAsyncSocket) {
        print("The client \(client) just connected")

        // Send something to the client
        let answer = "Have a nice day"
        server.sendObject(answer, toClient: client)
    }


    func didReceiveData(data: AnyObject?, fromClient client: GCDAsyncSocket) {

        // Print the object the client sent
        if let message = data as? String {
            print("The client sent this string: '\(message)'")
        } else {
            print("The client sent this object: \(data)")
        }
    }
}
