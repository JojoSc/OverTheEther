//
//  Client.swift
//

import CocoaLumberjack
import CocoaAsyncSocket


/** A Client can discover servers in the same Wifi network and connect to them. 
    A Client can only be connected to one server at a time. Currently only one
    object can be sent at the same time.
*/
public class WifiClient: NSObject {

    // Random values were chosen
    static let _k_pingPacket = "7CE9959E-5143-42AA-954E-9DFD1BC7EE4C"
    static let _k_headerTag = 60126;
    static let _k_dataTag = 55834;

    public weak var delegate:WifiClientDelegate?

    private var netServiceBrowser = NSNetServiceBrowser()
    private var serverService:NSNetService?
    private var serverAddresses = [NSData]()
    private var asyncSocket:GCDAsyncSocket?

    private var incomingDataLength  = 0
    private var incomingByteCounter = 0
    private var assembledData       = NSMutableData()

    private var outgoingDataLength  = 0
    private var outgoingDataCounter = 0
    
    private var serversFound = [NSNetService]()

    private var pingWasAcknowledgedByServer = false
    private var pingTimedOut                = true

    /// Returns false if the server is passcode protected
    var isAllowedToSend:Bool {
        get {
            return (requiredPasscode == nil || serverPasscode == requiredPasscode)
        }
    }

    // Basically, the client can't send anything before the handshake is finished
    private var requiredPasscode:String? = "BB54B02C-8A9A-4055-8F01-82D73BAA6B18"
    private var _serverPasscode:String?
    var serverPasscode:String? {
        get {
            return _serverPasscode
        }
        set {
            _serverPasscode = newValue
            if isAllowedToSend {
                tellServerImConnected()
                delegate?.connectionToServerEstablished()
            }
        }
    }


    override init() {
        super.init()
        netServiceBrowser.delegate = self
        netServiceBrowser.includesPeerToPeer = true
    }



    
    // MARK: - Public methods

    /** Send an object to the currently connected server
    */
    public func sendObject(object:NSCoding) {

        if isAllowedToSend || object is HandShake {
            DDLogVerbose("Sending an object...")
            let data = NSKeyedArchiver.archivedDataWithRootObject(object)
            sendData(data)
        } else {
            DDLogWarn("Not allowed to send file")
        }
    }


    /** Find all nearby servers in the same network. The delegate will be notified
        with all servers that were discovered.
     */
    public func discoverServers() {
        DDLogInfo("Discover servers...")
        serversFound.removeAll()
        netServiceBrowser.stop()
        netServiceBrowser.searchForServicesOfType("_filetransfer._tcp", inDomain: "")
    }


    /** Stop discovering, so no more nearby servers will be found. 
        The delegate won't receive any new notifications.
     */
    public func stopDiscoveringServers() {
        netServiceBrowser.stop()
    }


    /** Connect to a server in the same network by name. If there is more than one
        a random one will be chosen. If you are already connected, you need to disconnect first.
    */
    public func connectToServer(name:String) {

        DDLogInfo("Connecting to server '\(name)'...")
        let correct = serversFound.filter({server in (server.name == name)})
        if (correct.count > 0) {
            serverService = correct[0]
            serverService!.delegate = self
            serverService!.resolveWithTimeout(5.0)
        }
        else {
            DDLogError("Couldn't find server with specified name")
        }
    }


    /** Disconnect from the current server
    */
    public func disconnect() {
        asyncSocket?.disconnect()
        asyncSocket?.delegate = nil
        asyncSocket = nil
        serverService?.delegate = nil
        serverService = nil
    }


    /** Ping a the currently connected server, to see if it is still alive. The delegate will
        be notified, as soon as the server responds
    - parameter timeout: Number of seconds before the server is considered unresponsive
     */
    public func pingConnectedServer(timeout:Double) {
        pingTimedOut = false
        sendObject(WifiClient._k_pingPacket)
        _ = NSTimer.scheduledTimerWithTimeInterval(timeout, target: self, selector: #selector(WifiClient.pingTimedOut), userInfo: nil, repeats: false)
    }


    /** Get additional info about the service (if the server decided to provide it)
    - returns: The TXT record of the underlying NSNetService or nil (if the service is nil)
    */
    public func getServiceInfo() -> [String:NSData]? {
        guard let service = serverService
            else { DDLogError("ServerService is nil") ; return nil }

        if let x = service.TXTRecordData() {
            return NSNetService.dictionaryFromTXTRecordData(x)
        } else {
            return nil
        }
    }

    /** Returns true if the Client has an active connection to a server. This doesn't necessarily mean, that the client can send data to the server (passcode...).
     */
    public func isConnected() -> Bool {
        if let socket = asyncSocket {
            return socket.isConnected
        }
        return true // FIXME: is that really the case?
    }




    // MARK: - Private methods

    private func sendData(data:NSData) {
        let limit = 100_000 // Number of bytes after which Internet is preferred to BT
        let shouldSendLocally = isWifiConnected() || data.length < limit

        // Send via BT or Wifi
        if shouldSendLocally {
            guard let socket = asyncSocket
                else { DDLogError("AsyncSocket is NIL!") ; return }

            outgoingDataLength = data.length
            let length = "\(data.length)".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
            let mutable = NSMutableData(data: length!)
            mutable.appendData(GCDAsyncSocket.CRLFData())
            let header = NSData(bytes: mutable.bytes, length: mutable.length)

            socket.writeData(header, withTimeout: -1, tag: WifiClient._k_headerTag)
            socket.writeData(data, withTimeout: -1, tag: WifiClient._k_dataTag)
        }

        // Send via Internet
        else if isInternetConnected() {
            DDLogInfo("Sending Via Internet")

            let pc = ParseClient()

            let p:Double -> Void = { (p:Double) in self.delegate?.transferToServerDidProgress(p) }

            let c = { (error:NSError?, uuid:String) -> Void in
                if let e = error {
                    DDLogError("Upload failed: \(e)")
                } else {
                    self.delegate?.transferToServerDidProgress(1.0)

                    let idOpt = NSUUID(UUIDString: uuid)
                    if let id = idOpt {
                        self.sendObject(id)
                    } else {
                        DDLogError("ID String is not a valid UUID")
                    }
                }
            }

            pc.uploadFile(data, progress: p, completion: c)
        }

        else {
            //TODO: Notify user
            DDLogError("No way to send data")
        }
    }

    private func receivedFile() {
        let file = NSKeyedUnarchiver.unarchiveObjectWithData(assembledData)

        let notifyDelegate = didReceiveObjectFromServer(file)
        if notifyDelegate {
            delegate?.didReceiveObjectFromServer(file)
        }

        incomingByteCounter = 0
        incomingDataLength = 0
        assembledData = NSMutableData()
    }

    /** Returns true if the delegate should be notified (normal object), false otherwise
        (handshakes, ping, etc) */
    private func didReceiveObjectFromServer(object:AnyObject?) -> Bool {
        if let c = object as? String {
            if c == WifiClient._k_pingPacket && pingTimedOut == false {
                pingWasAcknowledgedByServer = true
                delegate?.pingReturned(true)
                DDLogInfo("Ping was acknowledged by server")
                return false
            } else {
                pingWasAcknowledgedByServer = false
                return true
            }
        } else if let shake = object as? HandShake {
            doHandshake(answer: shake)
            return false
        } else if let id = object as? NSUUID {

            let pc = ParseClient()

            let p:Double->Void = { (progress) in self.delegate?.transferFromServerDidProgress(progress) }

            let c = { (error:NSError?, data:NSData) in
                if let e = error {
                    DDLogError("Error Downloading: \(e)")
                } else {
                    let obj = NSKeyedUnarchiver.unarchiveObjectWithData(data)
                    self.delegate?.didReceiveObjectFromServer(obj)
                }
            }

            pc.downloadFile(withUUID: id.UUIDString, progress: p, completion: c)
        }

        return true
    }

    @objc private func pingTimedOut(timer:NSTimer) {

        pingTimedOut = true

        if pingWasAcknowledgedByServer == false {
            delegate?.pingReturned(false)
            DDLogWarn("Ping to server timed out")
        }
        // else, the delegate was already notified that the server answered

        pingWasAcknowledgedByServer = false
    }

    private func connectToNextAddress() {

        guard let socket = asyncSocket
            else { DDLogError("Can't connect, socket is nil") ; return }

        var done = false

        while (!done && serverAddresses.count > 0)
        {
            // Iterate forwards
            let addr = serverAddresses.first!
            serverAddresses.removeFirst()

            DDLogVerbose("Attempting connection to\(addr)")

            do {
                try socket.connectToAddress(addr)
                done = true
            }
            catch {
                DDLogError("Unable to connect: \(error)")
            }

        }

        if !done {
            DDLogError("Unable to connect to any resolved address")
        } else {
            DDLogVerbose("Connecting to an address")
        }
    }

    private func doHandshake(answer msg:HandShake?) {
        //Begin
        if msg == nil {
            DDLogInfo("Begin Negotiation: Ask Server if PIN is required.")
            let negotiation = HandShake(type: .REQAskIfPinIsNeeded)
            sendObject(negotiation)
        }

        //Server answered with message m
        if let m = msg {

            //Connect to a server which requires no pin
            if m.type == .ACKNoPinIsNotNeeded {
                DDLogInfo("Server answered in Negotiation: Pin is NOT required.")
                requiredPasscode = nil
                tellServerImConnected()
                delegate?.connectionToServerEstablished()
            }

            //Server requires pin
            if m.type == .ACKYesPinIsNeeded {
                DDLogInfo("Server answered in Negotiation: Pin IS required.")
                requiredPasscode = m.passcode
                delegate?.connectionToServerFailed(.RequiresPasscode)
            }
        }
    }

    private func stripHeader(header:NSData) -> NSData {
        // Remove the CRLF from the header
        return header.subdataWithRange(NSMakeRange(0, header.length - 2))
    }

    private func tellServerImConnected() {
        let shake = HandShake(type: .ACKClientIsAbleToSend)
        sendObject(shake)
    }
}




extension WifiClient : GCDAsyncSocketDelegate {
    // MARK: - GCDAsyncSocket Delegate methods

    public func socket(sender:GCDAsyncSocket, didReadData data:NSData, withTag tag:Int) {

        // Header came in
        if tag == WifiClient._k_headerTag {

            let stripped = stripHeader(data)

            guard let header = String(data: stripped, encoding: NSUTF8StringEncoding)
                else { DDLogError("Malformed Header by Server. Stopped reading. (1) : \(data)") ; return }

            guard let length = Int(header)
                else { DDLogError("Malformed Header by Server. Stopped reading. (2) : \(data)") ; return }

            incomingByteCounter = 0
            incomingDataLength = length
            assembledData = NSMutableData()

            sender.readDataWithTimeout(-1, tag: WifiClient._k_dataTag)
        }

            // Data came in
        else {
            assembledData.appendData(data)
            incomingByteCounter += data.length

            let percent = Double(incomingByteCounter)/Double(incomingDataLength)
            delegate?.transferFromServerDidProgress(percent)

            // Transmitted entire file
            if (incomingDataLength > 0 && incomingByteCounter >= incomingDataLength) {
                receivedFile()
                sender.readDataToData(GCDAsyncSocket.CRLFData(), withTimeout: -1, tag: WifiClient._k_headerTag)
            } else {
                sender.readDataWithTimeout(-1, tag: WifiClient._k_dataTag)
            }
        }
    }

    public func socket(sock:GCDAsyncSocket, didWritePartialDataOfLength partialLength:UInt, tag:Int) {
        guard tag == WifiClient._k_dataTag else { return }

        outgoingDataCounter += Int(partialLength)
        let percent = (Double(outgoingDataCounter) / Double(outgoingDataLength))
        delegate?.transferToServerDidProgress(percent)
    }

    public func socket(socket: GCDAsyncSocket, didConnectToHost host:String, port p:UInt16) {
        DDLogInfo("Socket connected to host: \(host) Port: \(p)")
        asyncSocket = socket
        socket.delegate = self

        /* It is essential to start reading with the header tag, because the other side will always send the
         size of the data first. Since this is the first time the client comes in contact with the server,
         the first data we will see will certainly be the header (i.e. the size) of some other data */
        socket.readDataToData(GCDAsyncSocket.CRLFData(), withTimeout: -1, tag: WifiClient._k_headerTag)

        // Ask for permission to send files
        doHandshake(answer:nil)
    }

    public func socket(sock:GCDAsyncSocket, didWriteDataWithTag tag:Int) {
        DDLogVerbose("Socket wrote data with tag \(tag)")
        if tag == WifiClient._k_dataTag {
            outgoingDataLength  = 0
            outgoingDataCounter = 0
            delegate?.transferToServerDidProgress(1.0)
        }
    }
    
    public func socketDidDisconnect(sock: GCDAsyncSocket, withError: NSError?) {
        DDLogInfo("Socket did disconnect")
    }
}




// MARK: - NSNetService Delegate

extension WifiClient : NSNetServiceDelegate {

    public func netServiceDidResolveAddress(sender: NSNetService) {
        DDLogVerbose("Did resolve")

        guard let addresses = sender.addresses
            else { DDLogError("NetService addresses are nil") ; return }

        serverAddresses = addresses

        asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        connectToNextAddress()
    }

    public func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        DDLogError("Did not resolve")
    }
}




// MARK: - NSNetServiceBrowser Delegate

extension WifiClient : NSNetServiceBrowserDelegate {

    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didFindService aNetService: NSNetService, moreComing: Bool) {
        DDLogVerbose("Found service. More coming: \(moreComing)")

        serversFound.append(aNetService)
        if moreComing == false {
            let serverNames = serversFound.map({server in "\(server.name)"})
            delegate?.discoveredListOfServers(serverNames)
        }
    }

    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didRemoveService aNetService: NSNetService, moreComing: Bool) {
        DDLogWarn("Lost Connection to Server")
        serversFound.removeObject(aNetService)
        delegate?.lostConnectionToServer(aNetService.name)
    }

    public func netServiceBrowserDidStopSearch(aNetServiceBrowser: NSNetServiceBrowser) {
        DDLogVerbose("Stopped searching")
    }

    public func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        DDLogError("NetService browser did not search: \(errorDict)")
    }
}

