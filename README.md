#OverTheEther

---
[![Pod](https://img.shields.io/badge/pod-v0.3.2-green.svg)](https://cocoapods.org/pods/OverTheEther)
[![Platform](https://img.shields.io/badge/Platform-iOS-lightgray.svg)](https://github.com/JojoSc/OverTheEther)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://en.wikipedia.org/wiki/MIT_License)

---

###What is this?

OverTheEther provides a simple way to programmatically send data from one iOS device to another one (or more) nearby. Be it short text messages, objects of custom classes or large image files. OTE uses CocoaAsyncSocket to send data via TCP. One device is configured as the server and others can connect to it as clients. A client can only be connected to one server but a server can be connected to as many clients as there are free ports. You just tell it which device to connect to and send whatever you want.


<br>

###Installing

##### Via CocoaPods (recommended)

Simply add `pod 'OverTheEther'` to your Podfile and run `pod install`

##### Without CocoaPods

Drag all files in the */OverTheEther/Classes* folder into your project. Then install *CocoaAsyncSocket* (e.g. via CocoaPods) and *CocoaLumberjack*. If you don't use CocoaLumberjack, simply go to the end of the *Helpers.swift* file and uncomment the block of function definitions to replace the log statements.

<br>

### Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

<br>

##How to get Started 




####Starting a Server

    let server = Server()
    server.delegate = self    
    server.startServer(name: "ImageSharing", infoDict: nil)
    
    
####Connecting to a Server

    let client = Client()
    client.delegate = self
    client.discoverServers()
    
    //Implement this delegate method
    func discoveredListOfServers(servers:[String]) {
        //connecting to the first server in the list
        client.connectToServer(name: servers[0])
    }
    
    
####Sending data to a server

    let someObject = SomeNSCodingClass()
    client.sendObject(someObject)
    
    
####Sending data to all clients

	let someObject = SomeNSCodingClass()
	server.broadCastObject(someObject)
    
####Receiving data on the server side

    //Implement this delegate method
    func didReceiveData(data: AnyObject?, fromClient client:GCDAsyncSocket) {
    
    	//Received object is of type 'String'
        if let string = data as? String {
            print(string)
        }
        
        //Received object is of some other type
        else {
            print("Received: \(data)")
        }
    }
    

####Receiving data on the client side

	//Implement this delegate method
	func didReceiveObjectFromServer(object:AnyObject?) {
        //You can handle this just like in the example above ('if let ...')
    }
    
<br>

---

####Important Notice

1. You can **only** send objects which implement the **NSCoding protocol**. Many of Apple's own classes (e.g. *NSString*, *NSData*, *UIColor*, *SKSpriteNode* and loads more) already implement NSCoding. You can also send Swift's *Int*, *String*, *[String:String]*(dictionary), etc. types, because they are bridged to Objective-C. If you don't know how to implement NSCoding in your own classes, I suggest this [tutorial](http://nshipster.com/nscoding/). 

2. When you are sending your **own** classes between two **different applications** (meaning the classes are in differently named modules), you need to prefix these classes with `@objc(ABCSomeClass)`. *ABCSomeClass* can be any name that is unique in the context of Objective-C. Failing to to so will cause NSKeyedUnarchiver to throw an exception. Example:  `
@objc(FTDSharedName) class SharedClass: NSObject, NSCoding {
    // Class Implementation
}`

3. Don't forget to set the delegate property and implement the delegate methods for both the server and the client. 


---

*Please note that this is still a work in progress. The code is not fully tested.*


Known Issues:


1. All files are saved in memory and not on disk, sending very large files (>100mb) may cause the watchdog to quit your app.
2. Currently some low level details (e.g. the GCDAsyncSocket parameter in didReceiveData()) are still exposed. I'm working on making this a little bit more high level.
