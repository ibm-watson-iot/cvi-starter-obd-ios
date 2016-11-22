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
import CoreLocation
import CocoaMQTT

class ViewController: UIViewController, CLLocationManagerDelegate {
    private var reachability = Reachability()!
    private let randomFuelLevel: Double = Double(arc4random_uniform(95) + 5);
    private let randomEngineCoolant: Double = Double(arc4random_uniform(120) + 20);
    
    private var simulation: Bool = false
    
    @IBOutlet weak var engineCoolantLabel: UILabel!
    @IBOutlet weak var fuelLevelLabel: UILabel!
    
    private var navigationBar: UINavigationBar?
    
    let locationManager = CLLocationManager()
    private var location: CLLocation?
    
    private var deviceBSSID: String = ""
    
    private let credentialHeaders: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Basic " + API.credentialsBase64
    ]
    
    private var mqtt: CocoaMQTT?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.activityType = .automotiveNavigation
            locationManager.startUpdatingLocation()
        }
        
        navigationBar = self.navigationController?.navigationBar
        navigationBar?.barStyle = UIBarStyle.black
        
        startApp()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = manager.location!
        print("New Location: \(manager.location!.coordinate.longitude), \(manager.location!.coordinate.latitude)")
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
            self.navigationBar?.topItem?.title = "Starting the Simulation"
            
            engineCoolantLabel.text = randomEngineCoolant.description + "C"
            fuelLevelLabel.text = randomFuelLevel.description + "%"
            
            checkDeviceRegistry()
        } else {
            self.navigationBar?.topItem?.title = "No Internet Connection Available"
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
            url = API.platformAPI + "/device/types/" + API.typeId + "/devices/" + API.getUUID()
        } else {
            url = API.platformAPI + "/device/types/" + API.typeId + "/devices/" + deviceBSSID.replacingOccurrences(of: ":", with: "-")
        }
        
        
        
        // TODO - Remove
        print(url)
        print(credentialHeaders)
        
        Alamofire.request(url, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: credentialHeaders).responseJSON { (response) in
            print(response)
            print("\(response.response?.statusCode)")
            
            let statusCode = response.response!.statusCode
            
            switch statusCode{
                case 200:
                    print("Check Device Registry: \(response)");
                    print("Check Device Registry: ***Already Registered***");
                    
//                    if let result = response.result.value {
//                        let resultDictionary = result as! NSDictionary
//                        authToken = (((resultDictionary["registration"] as! NSDictionary)["auth"] as! NSDictionary)["id"]!)
//                    }
                    
                    self.navigationBar?.topItem?.title = "Device Already Registered"
                    
                    self.deviceRegistered()
//                    progressBar.setVisibility(View.GONE);
                    
//                    currentDevice = result.getJSONObject(0);
//                    deviceRegistered();
                    
                    break;
                case 404, 405:
                    print("Check Device Registry: ***Not Registered***");
//                    progressBar.setVisibility(View.GONE);
                    
                    let alertController = UIAlertController(title: "Your Device is NOT Registered!", message: "In order to use this application, we need to register your device to the IBM IoT Platform", preferredStyle: UIAlertControllerStyle.alert)
                    
                    alertController.addAction(UIAlertAction(title: "Register", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                        self.registerDevice()
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
                        self.navigationBar?.topItem?.title = "Failed to connect to IBM IoT Platform"
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
    }
    
    private func getBSSID() -> String{
        let interfaces:NSArray? = CNCopySupportedInterfaces()
        if let interfaceArray = interfaces {
            let interfaceDict:NSDictionary? = CNCopyCurrentNetworkInfo(interfaceArray[0] as! CFString)
            
            if interfaceDict != nil {
                return interfaceDict!["BSSID"]! as! String
            }
        }
        
        return "0:17:df:37:94:b1"
        // TODO - Change to NONE
    }
    
    private func registerDevice() {
        let url: URL = URL(string: API.addDevices)!
        
            self.navigationBar?.topItem?.title = "Registering Your Device";
//        progressBar.setVisibility(View.VISIBLE);
        
        let parameters: Parameters = [
            "typeId": API.typeId,
            "deviceId": simulation ? API.getUUID() : deviceBSSID.replacingOccurrences(of: ":", with: "-"),
            "authToken": API.apiToken
        ]
        
        Alamofire.request(url, method: .post, parameters: parameters, encoding: deviceParamsEncoding(), headers: credentialHeaders).responseJSON { (response) in
            print("Register Device: \(response)")
            
            let statusCode = response.response!.statusCode
            print(statusCode)
            
            switch statusCode{
            case 200, 201:
                if let result = response.result.value {
                    let resultDictionary = (result as! [NSDictionary])[0]
                    
                    let authToken = (resultDictionary["authToken"] ?? "N/A") as? String
                    
                    let alertController = UIAlertController(title: "Your Device is Now Registered!", message: "Please take note of this Autentication Token as you will need it in the future", preferredStyle: UIAlertControllerStyle.alert)
                    
                    alertController.addAction(UIAlertAction(title: "Copy to my Clipboard", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                        UIPasteboard.general.string = authToken
                    })
                    
                    alertController.addTextField(configurationHandler: {(textField: UITextField!) in
                        textField.text = authToken
                        textField.isEnabled = false
                    })
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
                break;
            case 404, 405:
                print(statusCode)
                
                break;
            default:
                print("Failed to connect IoTP: statusCode: \(statusCode)");
                //                    progressBar.setVisibility(View.GONE);
                
                let alertController = UIAlertController(title: "Failed to connect to IBM IoT Platform", message: "Check orgId, apiKey and apiToken of your IBM IoT Platform. statusCode: \(statusCode)", preferredStyle: UIAlertControllerStyle.alert)
                
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                    self.navigationBar?.topItem?.title = "Failed to connect to IBM IoT Platform"
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
            
//            switch (statusCode) {
//            case 201, 202:
////                final String authToken = result.getJSONObject(0).getString("authToken");
////                final String deviceId = result.getJSONObject(0).getString("deviceId");
////                final String sharedPrefsKey = "iota-obdii-auth-" + deviceId;
////                
////                if (!API.getStoredData(sharedPrefsKey).equals(authToken)) {
////                    API.storeData(sharedPrefsKey, authToken);
////                }
////                
////                final AlertDialog.Builder alertDialog = new AlertDialog.Builder(Home.this, R.style.AppCompatAlertDialogStyle);
////                View authTokenAlert = getLayoutInflater().inflate(R.layout.activity_home_authtokenalert, null, false);
////                
////                EditText authTokenField = (EditText) authTokenAlert.findViewById(R.id.authTokenField);
////                authTokenField.setText(authToken);
////                
////                Button copyToClipboard = (Button) authTokenAlert.findViewById(R.id.copyToClipboard);
////                copyToClipboard.setOnClickListener(new View.OnClickListener() {
////                    @Override
////                    public void onClick(View view) {
////                        ClipboardManager clipboardManager = (ClipboardManager) getSystemService(CLIPBOARD_SERVICE);
////                        ClipData clipData = ClipData.newPlainText("authToken", authToken);
////                        clipboardManager.setPrimaryClip(clipData);
////                        
////                        Toast.makeText(Home.this, "Successfully copied to your Clipboard!", Toast.LENGTH_SHORT).show();
////                    }
////                });
////                
////                alertDialog.setView(authTokenAlert);
////                alertDialog
////                    .setCancelable(false)
////                    .setTitle("Your Device is Now Registered!")
////                    .setMessage("Please take note of this Autentication Token as you will need it in the future")
////                    .setPositiveButton("Close", new DialogInterface.OnClickListener() {
////                        @Override
////                        public void onClick(DialogInterface dialogInterface, int which) {
////                            try {
////                            currentDevice = result.getJSONObject(0);
////                            deviceRegistered();
////                            } catch (JSONException e) {
////                            e.printStackTrace();
////                            }
////                        }
////                    })
////                    .show();
////                break;
//            default:
//                break;
//            }
//            
//            progressBar.setVisibility(View.GONE);
        }
    }
    
    private func deviceRegistered() {
//        DispatchQueue.main.sync(execute: {
//            let clientIdPid = "d:\(API.orgId):\(API.typeId):\(deviceBSSID)"
//            mqtt = CocoaMQTT(clientId: clientIdPid, host: "\(API.orgId).messaging.internetofthings.ibmcloud.com", port: 8883)
//            
//            if let mqtt = mqtt {
//                mqtt.username = "use-token-auth"
//                mqtt.password = deviceCredentials.objectForKey("token") as? String
//                mqtt.keepAlive = 90
//                mqtt.delegate = self
//                mqtt.secureMQTT = true
//            }
//            
//            ViewController.mqtt?.connect()
//            
//        })
    }
    
    private static func deviceParamsToString(parameters: Parameters) -> String {
        var temp: String = "[{"
        
        for (index, item) in parameters.enumerated() {
            temp += "\"\(item.key)\":\"\(item.value)\""
            
            if index < (parameters.count - 1) {
                temp += ", "
            }
        }
        
        temp += "}]"
        
        return temp
    }
    
    struct deviceParamsEncoding: ParameterEncoding {
        func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
            var request = try urlRequest.asURLRequest()
            request.httpBody = ViewController.deviceParamsToString(parameters: parameters!).data(using: .utf8)
            
            return request
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

