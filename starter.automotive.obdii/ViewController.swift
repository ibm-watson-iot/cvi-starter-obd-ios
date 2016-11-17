//
//  ViewController.swift
//  starter.automotive.obdii
//
//  Created by Eliad Moosavi on 2016-11-14.
//  Copyright © 2016 IBM. All rights reserved.
//

import UIKit
import ReachabilitySwift
import Alamofire
import SystemConfiguration.CaptiveNetwork

class ViewController: UIViewController {
    private var reachability = Reachability()!
    private let randomFuelLevel: Double = Double(arc4random_uniform(95) + 5);
    private let randomEngineCoolant: Double = Double(arc4random_uniform(120) + 20);
    
    private var simulation: Bool = false
    
    @IBOutlet weak var engineCoolantLabel: UILabel!
    @IBOutlet weak var fuelLevelLabel: UILabel!
    
    private var deviceBSSID: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        startApp()
    }
    
    private func startApp() {
        let alertController = UIAlertController(title: "Would you like to use our Simulator?", message: "If you do not have a real OBDII device, then click \"Yes\"", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
            self.simulation = true
            
            self.deviceBSSID = self.getBSSID()
            
            self.startSimulation()
        })
        alertController.addAction(UIAlertAction(title: "I have a real OBDII dongle", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
            self.actualDevice()
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func startSimulation() {
        if reachability.isReachable {
            
            engineCoolantLabel.text = randomEngineCoolant.description + "C"
            fuelLevelLabel.text = randomFuelLevel.description + "%"
            
            checkDeviceRegistry()
        } else {
            print("No Simulation")
        }
    }
    
    private func actualDevice() {
        let alertController = UIAlertController(title: "Are you connected to your OBDII Dongle?", message: "You need to connect to your OBDII dongle through Wi-Fi, and then press \"Yes\"", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
            print("OK")
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
            let toast = UIAlertController(title: nil, message: "You would need to connect to your OBDII dongle in order to use this feature!", preferredStyle: UIAlertControllerStyle.alert)
            self.present(toast, animated: true, completion: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                exit(0)
            }
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func checkDeviceRegistry() {
//        getAccurateLocation();
        
        var url: String = ""
        
        if (simulation) {
            url = API.platformAPI + "/device/types/" + API.typeId + "/devices/" + deviceBSSID
        } else {
            url = API.platformAPI + "/device/types/" + API.typeId + "/devices/"
        }
        
        let headers: HTTPHeaders = [
            "Authorization": "Basic " + API.credentialsBase64
        ]
        
        print(url)
        print(headers)
        
        Alamofire.request(url, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { (response) in
            print(response)
            print("\(response.response?.statusCode)")
            
            let statusCode = response.response!.statusCode
            
            switch statusCode{
                case 200:
                    print("Check Device Registry: \(response)");
                    print("Check Device Registry: ***Already Registered***");
                    
//                    getSupportActionBar().setTitle("Device Already Registered");
//                    progressBar.setVisibility(View.GONE);
                    
//                    currentDevice = result.getJSONObject(0);
//                    deviceRegistered();
                    
                    break;
                case 404, 405:
                    print("Check Device Registry: ***Not Registered***");
//                    progressBar.setVisibility(View.GONE);
                    
                    let alertController = UIAlertController(title: "Your Device is NOT Registered!", message: "In order to use this application, we need to register your device to the IBM IoT Platform", preferredStyle: UIAlertControllerStyle.alert)
                    
                    alertController.addAction(UIAlertAction(title: "Register", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
//                        registerDevice();
                    })
                    
                    alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                        let toast = UIAlertController(title: nil, message: "Cannot continue without registering your device!", preferredStyle: UIAlertControllerStyle.alert)
                        self.present(toast, animated: true, completion: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            exit(0)
                        }
                    })
                    self.present(alertController, animated: true, completion: nil)
                    
                    break;
                default:
                    print("Failed to connect IoTP: statusCode: \(statusCode)");
//                    progressBar.setVisibility(View.GONE);
                    
                    let alertController = UIAlertController(title: "Failed to connect to IBM IoT Platform", message: "Check orgId, apiKey and apiToken of your IBM IoT Platform. statusCode: \(statusCode)", preferredStyle: UIAlertControllerStyle.alert)
                    
                    alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
//                        getSupportActionBar().setTitle("Failed to connect to IBM IoT Platform");
                    })
                    
                    alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                        let toast = UIAlertController(title: nil, message: "Cannot continue without connecting to IBM IoT Platform!", preferredStyle: UIAlertControllerStyle.alert)
                        self.present(toast, animated: true, completion: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            exit(0)
                        }
                    })
                    self.present(alertController, animated: true, completion: nil)
                    
                    break;
            }
        }
        
        print(getBSSID())
    }
    
    private func getBSSID() -> String{
        let interfaces:NSArray? = CNCopySupportedInterfaces()
        if let interfaceArray = interfaces {
            let interfaceDict:NSDictionary? = CNCopyCurrentNetworkInfo(interfaceArray[0] as! CFString)
            
            if interfaceDict != nil {
                return interfaceDict!["BSSID"]! as! String
            }
        }
        
        return "NONE"
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

