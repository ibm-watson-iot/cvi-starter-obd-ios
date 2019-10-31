/**
 * Copyright 2019 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License. */

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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.delegate?.showStatus(title: "Live Data is Being Sent", progress: true)
            }
            do {
                let success: Bool = try publishEvent(eventDict: merged, eventFormat: eventFormat)
                if (!success) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.delegate?.showStatus(title: "Failed to publish event", progress: false)
                    }
                    stopPublishing();
                }
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.delegate?.showStatus(title: "Failed to publish event", progress: false)
                }
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
