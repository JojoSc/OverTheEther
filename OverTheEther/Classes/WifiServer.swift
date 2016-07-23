//
//  Server.swift
//

import CocoaLumberjack
import CocoaAsyncSocket


/** A Server is a central service, which clients can connect to. A server advertises its service
    with some name on the network. Clients can discover this service and connect to it.
    Multiple Clients can be connected to one server.
*/
public class WifiServer: NSObject {

    public weak var delegate:WifiServerDelegate?

    /// The server's name that is visible on the network. Can't be changed, unless you start a new server.
    private(set) var localName = "" // Is set in startServer(...)
    private var netService:  NSNetService?
    private var asyncSocket: GCDAsyncSocket? // We need to keep a reference to the socket in startServer(...). Not used for anything else

    private var connectedSockets = [GCDAsyncSocket]()
    private var dataLength       = [GCDAsyncSocket:Int]()
    private var assembledData    = [GCDAsyncSocket:NSMutableData]()
    private var byteCounter      = [GCDAsyncSocket:Int]()

    private var isHosting = false

    /** If not nil, requires the client to have the same passcode
        in order to send objects */
    public var passcode:String? = nil // Default: allow sending files


    
    
    // MARK: - Public methods

    /** 
    Start the server. This makes the device visible to the local network.
    - parameter name: The name that other devices on the network will see
    - parameter infoDict: Here you can provide additional information, e.g. about the type of service.
    */
    public func startServer(name serverName:String, infoDict:[String:NSData]?) {

        DDLogInfo("Starting server")
        
        localName = serverName
        asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        
        do {
            try asyncSocket!.acceptOnPort(0)
            let port = Int32(asyncSocket!.localPort)
            netService = NSNetService(domain: "", type: "_filetransfer._tcp", name: serverName, port: port)
            netService!.delegate = self
            netService!.includesPeerToPeer = true
            netService!.publish()
            isHosting = true

            if let info = infoDict {
                let txtData = NSNetService.dataFromTXTRecordDictionary(info)
                netService!.setTXTRecordData(txtData)
            }

        } catch {
            DDLogError("Server didn't start. Socket doesn't accept connection")
        }
    }

    /// Experimental
    public func stopServer() {
        netService?.stop()
        netService = nil
        asyncSocket?.disconnect()
        asyncSocket = nil
    }


    /** Is the server active?
     */
    public func isRunning() -> Bool {
        return isHosting && asyncSocket != nil && netService != nil
    }


    /** Send an object to all connected clients
    */
    public func broadCastObject(object:NSCoding) {
        let data = NSKeyedArchiver.archivedDataWithRootObject(object)
        broadCastData(data)
    }


    /** Send an object only to a single client
    */
    public func sendObject(object:NSCoding, toClient client:GCDAsyncSocket) {
        let data = NSKeyedArchiver.archivedDataWithRootObject(object)
        sendData(data, toClient:client)
    }


    /**
    Experimental
    */
    public func rename(to newName:String) {
        stopServer()
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
        let s = self
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            s.startServer(name: newName, infoDict: nil) //FIXME: use original dict
        }
    }


    // MARK: - Private methods

    private func broadCastData(data:NSData) {
        DDLogInfo("Sending out broadcast...")
        for clientSocket in connectedSockets {
            sendData(data, toClient: clientSocket)
        }
    }

    private func sendData(data:NSData, toClient client:GCDAsyncSocket) {
        let limit = 100000 // Number of bytes after which Internet is preferred to BT
        let shouldSendViaInternet = !isWifiConnected() && data.length > limit

        // Send via BT or Wifi
        if !shouldSendViaInternet {
            for clientSocket in connectedSockets {
                if clientSocket == client {
                    let length = "\(data.length)".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)

                    let mutable = NSMutableData(data: length!)
                    mutable.appendData(GCDAsyncSocket.CRLFData())
                    let header = NSData(bytes: mutable.bytes, length: mutable.length)

                    clientSocket.writeData(header, withTimeout: -1, tag: WifiClient._k_headerTag)
                    clientSocket.writeData(data, withTimeout: -1, tag: WifiClient._k_dataTag)

                    DDLogVerbose("Sending data to \(clientSocket)")
                }
            }
        }

        // Send via Internet
        else {
            DDLogInfo("Sending Via Internet")

            let pc = ParseClient()

            let p:Double -> Void = { (p:Double) in self.delegate?.transferDidProgress(p) }

            let c = { (error:NSError?, uuid:String) -> Void in
                if let e = error {
                    DDLogError("Upload failed: \(e)")
                } else {
                    self.delegate?.transferDidProgress(1.0)

                    let idOpt = NSUUID(UUIDString: uuid)
                    if let id = idOpt {
                        self.sendObject(id, toClient: client)
                    } else {
                        DDLogError("ID String is not a valid UUID")
                    }
                }
            }

            pc.uploadFile(data, progress: p, completion: c)
        }
    }
    
    private func isPing(data:AnyObject?) -> Bool {
        guard let d = data as? String
            else { return false }

        return d == WifiClient._k_pingPacket
    }

    private func acknowledgePing(sender:GCDAsyncSocket) {
        sendObject(WifiClient._k_pingPacket, toClient: sender)
    }

    private func receivedFile(sender:GCDAsyncSocket) {

        defer {
            cleanUp(sender)
        }

        guard let data = assembledData[sender]
            else {
                DDLogError("assembled data for \(sender) is nil")
                return
        }

        let unarchived = NSKeyedUnarchiver.unarchiveObjectWithData(data)

        if isPing(unarchived) {
            acknowledgePing(sender)
        } else if let shake = unarchived as? HandShake {
            doHandshake(answer: shake, client: sender)
        } else if let id = unarchived as? NSUUID {

            let pc = ParseClient()

            let p:Double->Void = { (progress) in self.delegate?.transferDidProgress(progress) }

            let c = { (error:NSError?, data:NSData) in
                if let e = error {
                    DDLogError("Error Downloading: \(e)")
                } else {
                    let obj = NSKeyedUnarchiver.unarchiveObjectWithData(data)
                    self.delegate?.didReceiveData(obj, fromClient: sender)
                }
            }

            pc.downloadFile(withUUID: id.UUIDString, progress: p, completion: c)
        } else {
            delegate?.didReceiveData(unarchived, fromClient: sender)
        }
    }

    private func doHandshake(answer ans:HandShake?, client:GCDAsyncSocket) {

        guard let msg = ans
            else { return }

        DDLogVerbose("Server doing handshake")

        if msg.type == .REQAskIfPinIsNeeded {

            var reply:HandShake
            if let pin = passcode {
                reply = HandShake(type: .ACKYesPinIsNeeded)
                reply.passcode = pin
            } else {
                reply = HandShake(type: .ACKNoPinIsNotNeeded)
            }

            sendObject(reply, toClient: client)
        }

        if msg.type == .ACKClientIsAbleToSend {
            delegate?.clientConnected(client)
        }
    }

    private func stripHeader(header:NSData) -> NSData {
        // Remove the CRLF from the header
        return header.subdataWithRange(NSMakeRange(0, header.length - 2))
    }

    private func cleanUp(sender:GCDAsyncSocket) {
        byteCounter.removeValueForKey(sender)
        dataLength.removeValueForKey(sender)
        assembledData.removeValueForKey(sender)
    }
}




// MARK: - NSNetService Delegate methods

extension WifiServer : NSNetServiceDelegate {

    public func netServiceDidPublish(sender: NSNetService) {
        DDLogInfo("NetService published with name '\(sender.name)'")
    }

    public func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        DDLogError("NetService did not publish")

        //FIXME: What to do here? Just publishing again doesn't seem to allow clients to connect
    }
}




// MARK: - GCDAsyncSocket Delegate methods

extension WifiServer : GCDAsyncSocketDelegate {

    public func socket(sender:GCDAsyncSocket, didReadData data:NSData, withTag tag:Int) {

        // Header came in
        if tag == WifiClient._k_headerTag {
            DDLogVerbose("Received Header")

            let stripped = stripHeader(data)

            guard let header = String(data: stripped, encoding: NSUTF8StringEncoding)
                else { DDLogError("Malformed Header by Server. Stopped reading. (\(stripped))") ; return }

            guard let length = Int(header)
                else { DDLogError("Malformed Header by Server. Stopped reading. (\(header))") ; return }

            DDLogVerbose("Header: \(header)")

            byteCounter[sender] = 0
            dataLength[sender] = length
            assembledData[sender] = NSMutableData()

            sender.readDataWithTimeout(-1, tag: WifiClient._k_dataTag)
        }

            // Data came in
        else {
            guard let assembling = assembledData[sender]
                else { DDLogError("Servers assembledData is nil") ; return }

            guard byteCounter[sender] != nil
                else { DDLogError("Servers bytecounter is nil") ; return }

            guard let length = dataLength[sender]
                else { DDLogError("Servers dataLength is nil") ; return }

            assembling.appendData(data)
            byteCounter[sender]! += data.length

            let percent = Double(byteCounter[sender]!)/Double(length)
            delegate?.transferDidProgress(percent)

            // Transmitted entire file
            if (dataLength[sender] > 0) && (byteCounter[sender] >= dataLength[sender]) {
                receivedFile(sender)
                sender.readDataToData(GCDAsyncSocket.CRLFData(), withTimeout: -1, tag: WifiClient._k_headerTag)
            } else {
                sender.readDataWithTimeout(-1, tag: WifiClient._k_dataTag)
            }
        }
    }

    public func socket(sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        DDLogInfo("Socket \(sock) accepted new socket \(newSocket) with IP \(newSocket.connectedHost) (local: \(newSocket.localHost)")
        connectedSockets.append(newSocket)
        newSocket.delegate = self

        /* It is essential to start reading with the header tag, because the other side will always send the
        size of the data first. Since this is the first time the server comes in contact with the client,
        the first data we will see will certainly be the header (i.e. the size) of some other data */
        newSocket.readDataToData(GCDAsyncSocket.CRLFData(), withTimeout: -1, tag: WifiClient._k_headerTag)
    }

    public func socketDidDisconnect(sock: GCDAsyncSocket, withError: NSError?) {
        DDLogInfo("Socket \(sock) with IP \(sock.connectedHost) did disconnect")
        delegate?.clientDisconnected(sock)
    }
    
    public func socket(sock:GCDAsyncSocket, didWriteDataWithTag tag:Int) {
        DDLogVerbose("Socket \(sock) wrote data with tag \(tag)")
    }
}
