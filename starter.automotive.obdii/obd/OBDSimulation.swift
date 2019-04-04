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

class OBDSimulation {
    weak var delegate: OBDStreamDelegate?
    private var fuelLevel: Double?
    private var engineCoolant: Double?
    private var engineRPM: Double?
    private var engineOilTemp: Double?
    
    func connect() {
        fuelLevel = Double(arc4random_uniform(50) + 50)
        engineCoolant = Double(Int(arc4random_uniform(115) + 50))
        engineRPM = round(Double(arc4random_uniform(2000))/100)*100 + 2000
        engineOilTemp = Double(Int(arc4random_uniform(115) + 50))
        updateTable()
    }
    
    func updateSimulatedValues() {
        fuelLevel = fuelLevel! - round(Double(arc4random_uniform(10))/10.0)
        if fuelLevel! < 5.0 {
            fuelLevel = Double(arc4random_uniform(50) + 50)
        }
        engineCoolant = engineCoolant! + Double(arc4random_uniform(700)/10) - 30.0
        if engineCoolant! < -10.0 || engineCoolant! > 350.0 {
            engineCoolant = Double(Int(arc4random_uniform(115) + 50))
        }
        engineRPM = engineRPM! + round(Double(arc4random_uniform(400))/100)*100 - 200
        if engineRPM! < 0.0 || engineRPM! > 8000.0 {
            engineRPM = Double(arc4random_uniform(2000) + 1000)
        }
        engineOilTemp = engineOilTemp! + Double(arc4random_uniform(700)/10) - 30.0
        if engineOilTemp! < -10.0 || engineOilTemp! > 350.0 {
            engineOilTemp = Double(Int(arc4random_uniform(115) + 50))
        }
        updateTable()
    }
    
    private func updateTable() {
        var speed = ViewController.location?.speed ?? 0
        if (speed < 0) {
            speed = 0
        }
        let currentSpeed: Int = Int(round(speed));
        ViewController.tableItemsValues = ["\(engineCoolant!)", "\(fuelLevel!)", "\(currentSpeed)", "\(engineRPM!)", "\(engineOilTemp!)"]
        ViewController.sharedInstance.tableView.reloadData()
    }

}
