//
//  BaaSClient.swift
//  ThroughOuterSpace
//
//  Created by Johannes Schreiber on 29/01/16.
//  Copyright © 2016 Johannes Schreiber. All rights reserved.
//

import Foundation

/// String contains the uuid that is used to id data on server
typealias CompletionUploadBlock = (NSError?, String) -> Void

typealias CompletionDownloadBlock = (NSError?, NSData) -> Void

/// Double must be between 0.0 and 1.0
typealias ProgressBlock = Double -> Void


protocol BaaSClient {
    init()
    func uploadFile(data:NSData, progress:ProgressBlock?, completion:CompletionUploadBlock)
    func downloadFile(withUUID uuid:String, progress:ProgressBlock?, completion:CompletionDownloadBlock)
}