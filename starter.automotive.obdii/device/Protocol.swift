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
