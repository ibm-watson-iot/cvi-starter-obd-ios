////
////  IoTPlatformDevice.swift
////  starter.automotive.obdii
////
////  Created by Eliad Moosavi on 2016-12-07.
////  Copyright © 2016 IBM. All rights reserved.
////
//
//import Foundation
//
//class IoTPlatformDevice {
//    static let MQTT_FREQENCY: String = "mqtt-freqency"
//    static let MIN_FREQUENCY_SEC: Int = 5
//    static let MAX_FREQUENCY_SEC: Int = 60
//    static let DEFAULT_FREQUENCY_SEC: Int = 10
//    static let DEFAULT_UPLOAD_DELAY_SEC: Int = 5
//    
//    static func getMqttFrequencySec() -> Int {
//        let freq_str: String = API.getStoredData(key: MQTT_FREQENCY)
//        
//        return API.DOESNOTEXIST == freq_str ? DEFAULT_FREQUENCY_SEC : Int(freq_str)!
//    }
//    
//    static func setMqttFrequencySec(sec: Int) {
//        API.storeData(key: MQTT_FREQENCY, value: "\(sec)")
//    }
//    
////    private var deviceClient: DeviceClient = nil
////    private var currentDevice
//    
//    private var uploadDelay: Int = DEFAULT_UPLOAD_DELAY_SEC * 1000
//    private var uploadInterval: Int = DEFAULT_FREQUENCY_SEC * 1000
//    
//    func setDeviceDefinition(deviceDefinition: Any?) {
//        currentDevice = deviceDefinition
//        
//        if (deviceClient != null) {
//            disconnectDevice();
//            deviceClient = null;
//        }
//    }
//    
//    func getDeviceToken(deviceId: String) -> String {
//    let sharedPrefsKey: String = "iota-obdii-auth-" + deviceId
//    
//        return API.getStoredData(key: sharedPrefsKey)
//    }
//    
//    func hasDeviceToken(deviceId: String) -> Bool {
//        return !(API.DOESNOTEXIST == getDeviceToken(deviceId: deviceId))
//    }
//    
//    func setDeviceToken(deviceId: String, authToken: String) {
//        let sharedPrefsKey: String = "iota-obdii-auth-" + deviceId
//    
//        if !(API.getStoredData(key: sharedPrefsKey) == authToken) {
//            API.storeData(key: sharedPrefsKey, value: authToken);
//        }
//    }
//}
