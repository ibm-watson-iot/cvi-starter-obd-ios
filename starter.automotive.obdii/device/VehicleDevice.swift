/**
 * Copyright 2019 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DDIN-AHKQ8X&popup=n&title=IBM%20IoT%20for%20Automotive%20Sample%20Starter%20Apps%20%28iOS%20Mobile%29
 *
 * You may not use this file except in compliance with the license.
 */

import Foundation


class VehicleDevice {
    weak var delegate: DeviceDelegate?

    private var scheduler: Timer?
    private var accessInfo: Dictionary<String, String?>?
    private var eventFormat: EventFormat = EventFormat.JSON
    
    internal let eventKeys: Array<String>?
    
    internal var trip_id: String?
    internal let endpoint: String?
    internal let username: String?
    internal let password: String?
    internal let mo_id: String?
    internal let tenant_id: String?
    internal let vendor: String?
    internal let userAgent: String?
    
    init(accessInfo: Dictionary<String, String?>, eventKeys: Array<String>, format: EventFormat) {
        self.accessInfo = accessInfo
        self.scheduler = nil
        self.eventFormat = format
        self.eventKeys = eventKeys

        endpoint = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT] ?? ""
        username = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_USERNAME] ?? ""
        password = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_PASSWORD] ?? ""
        mo_id = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_MOID] ?? ""
        tenant_id = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_TENANTID] ?? nil
        vendor = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_VENDOR] ?? nil
        userAgent = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_USERAGENT] ?? nil
    }
    
    private func getTripId() -> String {
        if trip_id == nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let currentDate = NSDate()
            var tid = dateFormatter.string(from: currentDate as Date)
            tid += "-" + NSUUID().uuidString
            trip_id = tid
        }
        return trip_id!
    }
    
    func startPublishing(uploadInterval: Int) {
        stopPublishing()
        scheduler = Timer.scheduledTimer(timeInterval: TimeInterval(uploadInterval), target: self, selector: #selector(self.timerUpdate), userInfo: nil, repeats: true)
    }
    
    func stopPublishing() {
        scheduler?.invalidate()
        scheduler = nil
    }
    
    func getAccessInfo() -> Dictionary<String, String?> {
        return accessInfo!;
    }
    
    func clean() {
        stopPublishing();
        delegate = nil
    }
    
    func isReady() -> Bool {
        return false
    }

    func publishEvent(eventDict: Dictionary<String, Any>, eventFormat: EventFormat) throws -> Bool {
        switch eventFormat {
        case EventFormat.JSON:
            return try publishJsonEvent(eventDict: eventDict)
        case EventFormat.CSV:
            return try publishCSVEvent(event: createCSVText(eventDict: eventDict))
        }
    }
    
    func publishJsonEvent(eventDict: Dictionary<String, Any>) throws -> Bool {
        return false
    }

    func publishCSVEvent(event: String) throws -> Bool {
        return false
    }

    @objc func timerUpdate() {
        if (!ViewController.simulation && !OBDStream.sessionStarted) || !isReady() {
            return
        }

        if let eventDict: Dictionary<String, Any> = delegate?.generateData() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
            let date = Date()
            let dateString = dateFormatter.string(from: date)

            var dict: Dictionary<String, Any> = Dictionary<String, Any>()
            dict.updateValue(dateString, forKey: "timestamp")
            dict.updateValue(getTripId(), forKey: "trip_id")
            dict.updateValue(mo_id!, forKey: "mo_id")
            let merged = eventDict.merging(dict) { (_, new) in new }
            
            do {
                let success: Bool = try publishEvent(eventDict: merged, eventFormat: eventFormat)
                if (!success) {
                    stopPublishing();
                }
            } catch {
                stopPublishing();
            }
        }
    }
    
    private func createCSVText(eventDict: Dictionary<String, Any>) -> String {
        var event: String = "SEND_CARPROBE,sync"
        for key in eventKeys! {
            var value: Any?
            if (key == "mo_id") {
                value = mo_id
            } else if (key == "tenant_id") {
                value = tenant_id
            } else if (String(key.prefix(6)) == "props_") {
                let k = String(key.suffix(key.count - 6))
                let props = eventDict["props"] as! Dictionary<String, Any?>
                value = props[k]!
            } else if (eventDict[key] != nil) {
                value = eventDict[key]
            }
            event += ","
            if (value != nil) {
                event += String(describing: value!)
            }
        }
        return event;
    }
}
