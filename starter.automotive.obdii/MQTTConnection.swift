//
//  MQTTConnection.swift
//  starter.automotive.obdii
//
//  Created by Eliad Moosavi on 2016-12-14.
//  Copyright © 2016 IBM. All rights reserved.
//

import CocoaMQTT

protocol MQTTConnectionDelegate: class {
    func showStatus(title: String, progress: Bool)
}

class MQTTConnection {
    weak var delegate: MQTTConnectionDelegate?
    private var mqtt: CocoaMQTT?
    public var timer = Timer()
    static var timerInterval: Double = 5.0
    
    init(clientId: String, host: String, port: Int) {
        self.mqtt = CocoaMQTT(clientId: clientId, host: host, port: UInt16(port))
    }
    
    func connect(deviceId: String) {
        if let mqtt = self.mqtt {
            mqtt.username = "use-token-auth"
            mqtt.password = API.getStoredData(key: ("iota-obdii-auth-" + deviceId))
            mqtt.keepAlive = 90
            mqtt.delegate = self
            mqtt.secureMQTT = true
        }
        
        mqtt?.connect()
    }
    
    @objc func mqttPublish() {
        if(mqtt == nil || mqtt!.connState != CocoaMQTTConnState.connected){
            mqtt?.connect()
        }
        
        let data: [String: String] = [
            "trip_id": createTripId()
        ]
        
        var stringData: String = ""
        
        if ViewController.simulation {
            let props: [String: String] = [
                "engineRPM": "\(ViewController.randomEngineRPM)",
                "speed": "\(Double(arc4random_uniform(70) + 5))",
                "engineOilTemp": "\(ViewController.randomEngineOilTemp)",
                "engineTemp": "\(ViewController.randomEngineCoolant)",
                "fuelLevel": "\(ViewController.randomFuelLevel)",
                "lng": ViewController.location != nil ? "\((ViewController.location?.coordinate.longitude)!)" : "",
                "lat": ViewController.location != nil ? "\((ViewController.location?.coordinate.latitude)!)" : ""
            ]
            
            stringData = jsonToString(data: data, props: props)
        } else {
            if (ViewController.sessionStarted) {
                let props: [String: String] = [
                    "engineRPM": ViewController.tableItemsValues[3],
                    "speed": ViewController.tableItemsValues[2],
                    "engineOilTemp": ViewController.tableItemsValues[4],
                    "engineTemp": ViewController.tableItemsValues[0],
                    "fuelLevel": ViewController.tableItemsValues[1],
                    "lng": ViewController.location != nil ? "\((ViewController.location?.coordinate.longitude)!)" : "",
                    "lat": ViewController.location != nil ? "\((ViewController.location?.coordinate.latitude)!)" : ""
                ]
                
                stringData = jsonToString(data: data, props: props)
            }
        }
        
        
        mqtt!.publish("iot-2/evt/fuelAndCoolant/fmt/format_string", withString: stringData)
    }
    
    func updateTimer(interval: Double) {
        if interval != MQTTConnection.timerInterval {
            MQTTConnection.timerInterval = interval
            
            timer.invalidate()
            
            timer = Timer.scheduledTimer(timeInterval: MQTTConnection.timerInterval, target: self, selector: #selector(MQTTConnection.mqttPublish), userInfo: nil, repeats: true)
        }
    }
    
    private func createTripId() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let currentDate = NSDate()
        
        var tid = dateFormatter.string(from: currentDate as Date)
        
        tid += "-" + NSUUID().uuidString
        
        return tid;
    }
    
    private func jsonToString(data: [String: String], props: [String: String]) -> String {
        var temp: String = "{\"d\":{"
        var accum: Int = 0
        
        for i in data {
            if accum == (data.count - 1) && props.count == 0 {
                temp += "\"\(i.0)\": \"\(i.1)\"}}"
            } else {
                temp += "\"\(i.0)\": \"\(i.1)\", "
            }
            
            accum += 1
        }
        
        if props.count > 0 {
            temp += "\"props\":{"
            var propsAccum: Int = 0
            
            for i in props {
                if propsAccum == (props.count - 1) {
                    temp += "\"\(i.0)\": \"\(i.1)\"}}}"
                } else {
                    temp += "\"\(i.0)\": \"\(i.1)\", "
                }
                
                propsAccum += 1
            }
        }
        
        return temp
    }
}

extension MQTTConnection: CocoaMQTTDelegate {
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
            
            delegate?.showStatus(title: "Connected, Preparing to Send Data", progress: true)
            
            if ViewController.simulation || ViewController.sessionStarted {
                timer = Timer.scheduledTimer(timeInterval: MQTTConnection.timerInterval, target: self, selector: #selector(MQTTConnection.mqttPublish), userInfo: nil, repeats: true)
            }
            
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
