/**
 * Copyright 2016 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DDIN-AHKQ8X&popup=n&title=IBM%20IoT%20for%20Automotive%20Sample%20Starter%20Apps%20%28iOS%20Mobile%29
 *
 * You may not use this file except in compliance with the license.
 */
import CocoaMQTT

protocol MQTTConnectionDelegate: class {
    func showStatus(title: String, progress: Bool)
    func updateSimulatedValues()
}

class MQTTConnection {
    weak var delegate: MQTTConnectionDelegate?
    private var mqtt: CocoaMQTT?
    public var timer = Timer()
    static var timerInterval: Double = 5.0
    private var tripId: String?
    
    init(clientId: String, host: String, port: Int) {
        self.mqtt = CocoaMQTT(clientID: clientId, host: host, port: UInt16(port))
        self.tripId = createTripId()
    }
    
    func connect(deviceId: String) {
        if let mqtt = self.mqtt {
            mqtt.username = "use-token-auth"
            mqtt.password = API.getStoredData(key: ("iota-obdii-auth-" + deviceId))
            mqtt.keepAlive = 90
            mqtt.delegate = self
            mqtt.enableSSL = true
        }
        
        mqtt?.connect()
    }
    
    @objc func mqttPublish() {
        if(mqtt == nil || mqtt!.connState != CocoaMQTTConnState.connected){
            mqtt?.connect()
        }
        
        var data: [String: Any] = [
            "trip_id": self.tripId!,
            "lng": ViewController.location != nil ? ((ViewController.location?.coordinate.longitude)!) : 0,
            "lat": ViewController.location != nil ? ((ViewController.location?.coordinate.latitude)!) : 0
        ]
        
        var deviceValues: [String]? = nil
        
        if ViewController.simulation {
            delegate?.updateSimulatedValues()
            deviceValues = ViewController.tableItemsValues
        } else {
            if (OBDStream.sessionStarted) {
                deviceValues = ViewController.tableItemsValues
            }
        }

        var stringData: String = ""
        if(deviceValues != nil){
            data["speed"] = Double(deviceValues![2])
            
            let props: [String: String] = [
                "engineRPM": deviceValues![3],
                "engineOilTemp": deviceValues![4],
                "engineTemp": deviceValues![0],
                "fuelLevel": deviceValues![1]
            ]
            
            stringData = jsonToString(data: data, props: props)
        }
        
        
        mqtt!.publish("iot-2/evt/carprobe/fmt/json", withString: stringData)
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
    
    private func jsonToString(data: [String: Any], props: [String: String]) -> String {
        var temp: String = "{\"d\":{"
        var accum: Int = 0
        
        for i in data {
            let valType = type(of: (i.1))
            let val = valType == Double.self || valType == Int.self ? i.1 : "\"\(i.1)\""
            if accum == (data.count - 1) && props.count == 0 {
                temp += "\"\(i.0)\": \(val)}}"
            } else {
                temp += "\"\(i.0)\": \(val), "
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
            
            if ViewController.simulation || OBDStream.sessionStarted {
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
