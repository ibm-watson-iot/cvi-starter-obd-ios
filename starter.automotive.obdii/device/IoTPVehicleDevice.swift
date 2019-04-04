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
import CocoaMQTT

class IoTPVehicleDevice: VehicleDevice, CocoaMQTTDelegate {
    private var deviceId: String?
    private var accepted: Bool = false
    private var mqtt: CocoaMQTT?

    
    override init(accessInfo: Dictionary<String, String?>, eventKeys: Array<String>, format: EventFormat) {
        super.init(accessInfo: accessInfo, eventKeys: eventKeys, format: EventFormat.CSV)
        
        let orgId = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT] as! String
        let typeId = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_VENDOR] as! String
        let mo_id = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_MOID] as! String
        let username = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_USERNAME] ?? ""
        let password = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_PASSWORD] ?? ""
        let clientId = "d:\(orgId):\(typeId):\(mo_id)"
        let host = "\(orgId).messaging.internetofthings.ibmcloud.com"
        
        self.mqtt = CocoaMQTT(clientID: clientId, host: host, port: UInt16(8883))
        if let mqtt = self.mqtt {
            mqtt.username = username
            mqtt.password = password
            mqtt.keepAlive = 90
            mqtt.delegate = self
            mqtt.enableSSL = true
        }
        mqtt?.connect()
    }
    
    override func isReady() -> Bool {
        return accepted;
    }

    override func publishCSVEvent(event: String) throws -> Bool {
        if(mqtt == nil || mqtt!.connState != CocoaMQTTConnState.connected){
            mqtt?.connect()
        }
        mqtt!.publish( "iot-2/evt/carprobe/fmt/csv", withString: event)
        return true;
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didConnect host: String, port: Int) {
        print("didConnect \(host):\(port)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("didConnectAck: \(ack)，rawValue: \(ack.rawValue)")
        
        if ack == .accept {
            print("ACCEPTED")
            accepted = true
            
            delegate?.showStatus(title: "Connected, Preparing to Send Data", progress: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.delegate?.showStatus(title: "Live Data is Being Sent", progress: true)
            }
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("didPublishMessage with message: \((message.string)!)")
        
        delegate?.showStatus(title: "Successfully Published to Server", progress: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.delegate?.showStatus(title: "Live Data is Being Sent", progress: true)
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        print("didPublishAck with id: \(id)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        print("didReceivedMessage: \(message.string) with id \(id)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {
        print("didSubscribeTopic to \(topic)")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {
        print("didUnsubscribeTopic to \(topic)")
    }
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        print("didPing")
    }
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        _console("didReceivePong")
    }
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        _console("mqttDidDisconnect")
    }
    
    func _console(_ info: String) {
        print("Delegate: \(info)")
    }
}
