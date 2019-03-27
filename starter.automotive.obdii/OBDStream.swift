/**
 * Copyright 2016 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DDIN-AHKQ8X&popup=n&title=IBM%20IoT%20for%20Automotive%20Sample%20Starter%20Apps%20%28iOS%20Mobile%29
 *
 * You may not use this file except in compliance with the license.
 */

import UIKit

protocol OBDStreamDelegate: class {
    func showStatus(title: String, progress: Bool)
    func checkDeviceRegistry()
    func obdStreamError()
}

class OBDStream: NSObject, StreamDelegate {
    weak var delegate: OBDStreamDelegate?
    private var buffer = [UInt8](repeating: 0, count: 1024)
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var host: String = "192.168.0.10"
    private var port: Int = 35000
    
    private var counter: Int = 0
    private var inProgress: Bool = false
    static var sessionStarted: Bool = false
    private var canWrite: Bool = false
    
    private var alreadySent: Bool = false
    
    public var obdTimer = Timer()
    
    init(host: String = "192.168.0.10", port: Int = 35000) {
        self.host = host
        self.port = port
    }
    
    func connect() {
        print("Attempting to Connect to Device")
        delegate?.showStatus(title: "Connecting to Device", progress: true)
        
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        inputStream!.delegate = self
        inputStream!.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        inputStream!.open()
        
        outputStream!.delegate = self
        outputStream!.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        outputStream!.open()
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            while(inputStream!.hasBytesAvailable){
                let bytes = inputStream!.read(&buffer, maxLength: buffer.count)
                
                if bytes > 0 {
                    if let result = NSString(bytes: buffer, length: bytes, encoding: String.Encoding.ascii.rawValue) {
                        print("\n[Socket] - Result:\n\(result)")
                        
                        if result.contains(">") {
                            canWrite = true
                            
                            if !OBDStream.sessionStarted {
                                obdTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(writeQueries), userInfo: nil, repeats: true)
                                
                                OBDStream.sessionStarted = true
                                canWrite = true
                                
                                delegate?.showStatus(title: "Updating Values", progress: true)
                            }
                        }
                        
                        if OBDStream.sessionStarted && counter < ViewController.obdCommands.count {
                            if counter == 0 {
                                inProgress = true
                            } else {
                                if result.contains(ViewController.obdCommands[counter - 1]) {
                                    parseValue(from: String(result), index: counter - 1)
                                }
                            }
                            
                            if canWrite {
                                writeToStream(message: "01 \(ViewController.obdCommands[counter])")
                                
                                canWrite = false
                                
                                counter += 1
                            }
                        }
                        
                        if (counter == ViewController.obdCommands.count) {
                            ViewController.sharedInstance.tableView.reloadData()
                            
                            inProgress = false
                            
                            counter = 0
                            
                            print("DONE \(ViewController.tableItemsValues)")
                        }
                    }
                }
            }
            
            break
        case Stream.Event.hasSpaceAvailable:
            print("Space Available")
            
            if (!alreadySent) {
                writeToStream(message: "AT Z")
                
                alreadySent = true
            }
            
            break
        case Stream.Event.openCompleted:
            print("Stream Opened Successfully")
            delegate?.showStatus(title: "Connection Established", progress: false)
            
            delegate?.checkDeviceRegistry()
            
            break
        case Stream.Event.endEncountered:
            print("Stream Ended")
            
            delegate?.showStatus(title: "Connection Ended", progress: false)
            
            OBDStream.sessionStarted = false
            
            break
        case Stream.Event.errorOccurred:
            print("Error")
            
            delegate?.obdStreamError()
            
            break
        case Stream.Event():
            break
        default:
            break
        }
    }
    
    @objc func writeQueries() {
        if (OBDStream.sessionStarted && canWrite && !inProgress) {
            writeToStream(message: "AT Z")
        }
    }
    
    func writeToStream(message: String){
        let formattedMessage = message + "\r"
        
        if let data = formattedMessage.data(using: String.Encoding.ascii) {
            print("[Socket] - Writing: \"\(message)\"")
            outputStream!.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
        }
    }
    
    func sendMessage(_ message: String){
        let message = "\(message)\r"
        let data = message.data(using: String.Encoding.ascii)
        
        if let data = data {
            outputStream!.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
            
            return
        }
    }
    
    func parseValue(from: String, index: Int) {
        from.enumerateLines { (line, stop) -> () in
            if !line.contains(">") {
                var lineArray = line.components(separatedBy: " ")
                var hexValue = ""
                
                for (index, item) in lineArray.enumerated() {
                    if item == "" {
                        lineArray.remove(at: index)
                    } else {
                        if index > 1 {
                            hexValue += item
                        }
                    }
                }
                
                if lineArray.count > 2 {
                    var result: Double = -1
                    
                    if let decimalValue = UInt64(hexValue, radix: 16) {
                        switch lineArray[1] {
                        case "2F":
                            result = Double(decimalValue)/2.55
                            ViewController.tableItemsValues[index] = "\(String(format: "%.2f", result))"
                            
                            break
                        case "05":
                            ViewController.tableItemsValues[index] = "\(decimalValue)"
                            
                            break
                        case "0D":
                            ViewController.tableItemsValues[index] = "\(decimalValue)"
                            
                            break
                        case "0C":
                            result = Double(decimalValue)/4.0
                            ViewController.tableItemsValues[index] = "\(result)"
                            
                            break
                        case "5C":
                            ViewController.tableItemsValues[index] = "\(decimalValue)"
                            
                            break
                        default:
                            result = Double(decimalValue)
                        }
                    }
                }
            }
        }
    }
}
