//
//  ParseClient.swift
//  ThroughOuterSpace
//
//  Created by Johannes Schreiber on 29/01/16.
//  Copyright © 2016 Johannes Schreiber. All rights reserved.
//

import Foundation
import Parse
import CocoaLumberjack

class ParseClient: BaaSClient {

    required init() {
        Parse.setApplicationId("XetMqR3J7rUitAgiWz5ShIBssx7LOuNqVMSyxGC2",
            clientKey: "m1IDG1DACxQEt24jBFkN5xUskwZhFsDmvoAaUtol")
    }

    func downloadFile(withUUID uuid: String, progress: ProgressBlock?, completion: CompletionDownloadBlock) {
        let query = PFQuery(className: "Data")
        query.whereKey("uuid", equalTo: uuid)
        query.findObjectsInBackgroundWithBlock { (objects, error) -> Void in
            guard error == nil
                else { DDLogError("Parse didnt find objects: \(error)") ; return }

            guard let results = objects
                else { DDLogError("Objects array is nil") ; return }

            guard results.count == 1
                else { DDLogError("Parse found more than one or no object") ; return }

            let result = results.first!
            let receivedFileOptArr = result.objectForKey("data")
            guard let receivedFileArr = receivedFileOptArr as? [PFFile]
                else { DDLogError("Received file array is not [PFFile] array") ; return }

            guard let receivedFile = receivedFileArr.first
                else { DDLogError("Received array has no first element") ; return }

            receivedFile.getDataInBackgroundWithBlock({ (data, error) -> Void in
                guard error == nil else { DDLogError("Error while downloding file") ; return }
                guard let receivedData = data
                    else { DDLogError("Received data is nil") ; return }

                let err:NSError? = nil
                completion(err, receivedData)

                // Remove the file from the server
                result.deleteInBackgroundWithBlock({ (success, error) -> Void in
                    guard success
                        else { DDLogError("Couldn't delete file") ; return }
                    guard error == nil
                        else { DDLogError("Delete error: \(error!)") ; return }

                    DDLogInfo("Deleted received file from Parse")
                })

                }, progressBlock: { (percentComplete) -> Void in
                    if let p = progress {
                        p(Double(percentComplete) / 100.0)
                    }
            })
        }
    }

    func uploadFile(data: NSData, progress: ProgressBlock?, completion: CompletionUploadBlock) {
        let dataOpt = PFFile(data: data)
        guard let data = dataOpt else { DDLogError("Couldnt create PFFile") ; return }
        let uuid = NSUUID().UUIDString
        let parseObject = PFObject(className: "Data")

        parseObject.addObject(uuid, forKey: "uuid")
        parseObject.addObject(data, forKey: "data")
        parseObject.saveInBackgroundWithBlock { (success, error) -> Void in
            if let err = error {
                completion(err, uuid)
            } else if !success {
                completion(NSError(domain: "Upload", code: 0, userInfo: nil), uuid)
            } else {
                completion(nil, uuid)
            }
        }

    }
}