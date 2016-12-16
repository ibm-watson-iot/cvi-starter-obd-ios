//
//  OBDStream.swift
//  starter.automotive.obdii
//
//  Created by Eliad Moosavi on 2016-12-14.
//  Copyright © 2016 IBM. All rights reserved.
//

import UIKit
import Foundation

class OBDStream: NSObject, StreamDelegate {
    private var buffer = [UInt8](repeating: 0, count: 1024)
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private let host: String
    private let port: Int
    
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
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        inputStream!.delegate = self
        inputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        inputStream!.open()
        
        outputStream!.delegate = self
        outputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
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
                                
                                ViewController.showStatus(title: "Updating Values", progress: true)
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
                            ViewController.reloadTable()
                            
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
            ViewController.showStatus(title: "Connection Established", progress: false)
            
//            checkDeviceRegistry()
            
            break
        case Stream.Event.endEncountered:
            print("Stream Ended")
            
            ViewController.showStatus(title: "Connection Ended", progress: false)
            
            OBDStream.sessionStarted = false
            
            break
        case Stream.Event.errorOccurred:
            print("Error")
            
            /*
            let alertController = UIAlertController(title: "Connection Failed", message: "Did you want to try again?", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                ViewController.talkToSocket()
            })
            alertController.addAction(UIAlertAction(title: "Back", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                ViewController.startApp()
            })
            self.present(alertController, animated: true, completion: nil)
            */
            
            break
        case Stream.Event():
            break
        default:
            break
        }
    }
    
    func writeQueries() {
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
                let lineArray = line.components(separatedBy: " ")
                
                if lineArray.count > 2 {
                    let hexValue = lineArray[lineArray.count - 2]
                    var result: Double = -1
                    
                    if let decimalValue = UInt8(hexValue, radix: 16) {
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
