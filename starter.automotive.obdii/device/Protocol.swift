/**
 * Copyright 2019 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * https://github.com/ibm-watson-iot/iota-starter-obd-ios/blob/master/LICENSE
 *
 * You may not use this file except in compliance with the license.
 */

import Foundation

enum Protocol: String {
    case HTTP = "HTTP"
    case MQTT = "MQTT"
    
    static let allValues = [HTTP, MQTT]
    
    func prefName(key: String) -> String {
        return self.rawValue + "_" + key
    }
    
    func createVehicleData(accessInfo: Dictionary<String, String?>, eventKeys: Array<String>) -> VehicleDevice? {
        if (self == Protocol.HTTP) {
            return HTTPVehicleDevice(accessInfo: accessInfo, eventKeys: eventKeys, format: EventFormat.JSON)
        } else if (self == Protocol.MQTT) {
            return IoTPVehicleDevice(accessInfo: accessInfo, eventKeys: eventKeys, format: EventFormat.CSV)
        }
        return nil
    }
}
