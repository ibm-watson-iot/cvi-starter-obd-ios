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
