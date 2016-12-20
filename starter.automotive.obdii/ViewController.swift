/**
 * Copyright 2016 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DDIN-ADRVKF&popup=y&title=IBM%20IoT%20for%20Automotive%20Sample%20Starter%20Apps
 *
 * You may not use this file except in compliance with the license.
 */

import UIKit
import ReachabilitySwift
import Alamofire
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import CocoaMQTT

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource, StreamDelegate, MQTTConnectionDelegate, UIViewControllerTransitioningDelegate{
    private var reachability = Reachability()!

    private let tableItemsTitles: [String] = ["Engine Coolant Temperature", "Fuel Level", "Speed", "Engine RPM", "Engine Oil Temperature"]
    private let tableItemsUnits: [String] = ["°C", "%", " KM/hr", " RPM", "°C"]
    private let obdCommands: [String] = ["05", "2F", "0D", "0C", "5C"]
    
    static var tableItemsValues: [String] = []
    
    static var simulation: Bool = false
    
    @IBOutlet weak var navigationRightButton: UIBarButtonItem!
    @IBOutlet weak var tableView: UITableView!
    
    static var navigationBar: UINavigationBar?
    private var activityIndicator: UIActivityIndicatorView?
    
    let locationManager = CLLocationManager()
    static var location: CLLocation?
    
    private var deviceBSSID: String = ""
    private var currentDeviceId: String = ""
    
    private var frequencyArray: [Int] = Array(5...60)
    
    private var mqttConnection: MQTTConnection?
    
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var buffer = [UInt8](repeating: 0, count: 1024)
    private let host: String = "192.168.0.10"
    private let port: Int = 35000
    
    private var counter: Int = 0
    private var inProgress: Bool = false
    static var sessionStarted: Bool = false
    private var canWrite: Bool = false
    
    private var alreadySent: Bool = false
    
    public var obdTimer = Timer()
    
    private let credentialHeaders: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Basic " + API.credentialsBase64
    ]
    
    static let sharedInstance = ViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        confirmDisclaimer()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        ViewController.tableItemsValues = [String](repeating: "N/A", count: obdCommands.count)
    }
    func confirmDisclaimer() {
        let licenseVC: LicenseViewController = self.storyboard!.instantiateViewController(withIdentifier: "licenseViewController") as! LicenseViewController
        licenseVC.modalPresentationStyle = .custom
        licenseVC.transitioningDelegate = self
        licenseVC.onAgree = {() -> Void in
            self.startApp()
        }
        self.present(licenseVC, animated: true, completion: nil)
    }
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return LicensePresentationController(presentedViewController: presented, presenting: presenting)
    }

    func talkToSocket() {
        print("Attempting to Connect to Device")
        showStatus(title: "Connecting to Device", progress: true)

        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        inputStream!.delegate = self
        inputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        inputStream!.open()
        
        outputStream!.delegate = self
        outputStream!.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        outputStream!.open()
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            while(inputStream!.hasBytesAvailable){
                let bytes = inputStream!.read(&buffer, maxLength: buffer.count)
                
                if bytes > 0 {
                    if let result = NSString(bytes: buffer, length: bytes, encoding: String.Encoding.ascii.rawValue) {
                        print("\n[Socket] - Result:\n\(result)")
                        
                        if result.contains(">") {
                            canWrite = true
                            
                            if !ViewController.sessionStarted {
                                obdTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(writeQueries), userInfo: nil, repeats: true)
                                
                                ViewController.sessionStarted = true
                                canWrite = true
                                
                                showStatus(title: "Updating Values", progress: true)
                            }
                        }
                        
                        if ViewController.sessionStarted && counter < obdCommands.count {
                            if counter == 0 {
                                inProgress = true
                            } else {
                                if result.contains(obdCommands[counter - 1]) {
                                    parseValue(from: String(result), index: counter - 1)
                                }
                            }
                            
                            if canWrite {
                                writeToStream(message: "01 \(obdCommands[counter])")
                                
                                canWrite = false
                                
                                counter += 1
                            }
                        }
                        
                        if (counter == obdCommands.count) {
                            tableView.reloadData()
                            
                            inProgress = false
                            
                            counter = 0
                            
                            print("DONE \(ViewController.tableItemsValues)")
                        }
                    }
                }
            }
            
            break
        case Stream.Event.hasSpaceAvailable:
            print("Space Available")
            
            if (!alreadySent) {
                writeToStream(message: "AT Z")
                
                alreadySent = true
            }
            
            break
        case Stream.Event.openCompleted:
            print("Stream Opened Successfully")
            showStatus(title: "Connection Established", progress: false)
            
            self.checkDeviceRegistry()
            
            break
        case Stream.Event.endEncountered:
            print("Stream Ended")
            
            showStatus(title: "Connection Ended", progress: false)
            
            ViewController.sessionStarted = false
            
            break
        case Stream.Event.errorOccurred:
            print("Error")
            
            let alertController = UIAlertController(title: "Connection Failed", message: "Did you want to try again?", preferredStyle: UIAlertControllerStyle.alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                self.talkToSocket()
            })
            alertController.addAction(UIAlertAction(title: "Back", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                self.startApp()
            })
            self.present(alertController, animated: true, completion: nil)
            
            break
        case Stream.Event():
            break
        default:
            break
        }
    }
    
    func writeQueries() {
        if (ViewController.sessionStarted && canWrite && !inProgress) {
            writeToStream(message: "AT Z")
        }
    }
    
    func writeToStream(message: String){
        let formattedMessage = message + "\r"
        
        if let data = formattedMessage.data(using: String.Encoding.ascii) {
            print("[Socket] - Writing: \"\(message)\"")
            outputStream!.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
        }
    }
    
    func sendMessage(_ message: String){
        let message = "\(message)\r"
        let data = message.data(using: String.Encoding.ascii)
        
        if let data = data {
            outputStream!.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
            
            return
        }
    }
    
    func parseValue(from: String, index: Int) {
        from.enumerateLines { (line, stop) -> () in
            if !line.contains(">") {
                let lineArray = line.components(separatedBy: " ")
                
                if lineArray.count > 2 {
                    let hexValue = lineArray[lineArray.count - 2]
                    var result: Double = -1
                    
                    if let decimalValue = UInt8(hexValue, radix: 16) {
                        switch lineArray[1] {
                        case "2F":
                            result = Double(decimalValue)/2.55
                            ViewController.tableItemsValues[index] = "\(String(format: "%.2f", result))"
                            
                            break
                        case "05":
                            ViewController.tableItemsValues[index] = "\(decimalValue)"
                            
                            break
                        case "0D":
                            ViewController.tableItemsValues[index] = "\(decimalValue)"
                            
                            break
                        case "0C":
                            result = Double(decimalValue)/4.0
                            ViewController.tableItemsValues[index] = "\(result)"
                            
                            break
                        case "5C":
                            ViewController.tableItemsValues[index] = "\(decimalValue)"
                            
                            break
                        default:
                            result = Double(decimalValue)
                        }
                    }
                }
            }
        }
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
        
        ViewController.navigationBar = self.navigationController?.navigationBar
        ViewController.navigationBar?.barStyle = UIBarStyle.blackOpaque
        
        
        activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white)
        navigationRightButton.customView = activityIndicator
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        ViewController.location = manager.location!
        print("New Location: \(manager.location!.coordinate.longitude), \(manager.location!.coordinate.latitude)")
    }
    
    private func startApp() {
        self.deviceBSSID = self.getBSSID()
        
        let alertController = UIAlertController(title: "Would you like to use our Simulator?", message: "If you do not have a real OBDII device, then click \"Yes\"", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
            ViewController.simulation = true
            
            self.startSimulation()
        })
        alertController.addAction(UIAlertAction(title: "I have a real OBDII dongle", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
            self.actualDevice()
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    public func updateSimulatedValues(){
        let randomFuelLevel: Double = Double(arc4random_uniform(95) + 5)
        let randomSpeed: Double = Double(arc4random_uniform(150))
        let randomEngineCoolant: Double = Double(-40 + Int(arc4random_uniform(UInt32(215 - (-40) + 1))))
        let randomEngineRPM: Double = Double(arc4random_uniform(600) + 600)
        let randomEngineOilTemp: Double = Double(-40 + Int(arc4random_uniform(UInt32(210 - (-40) + 1))))
        
        ViewController.tableItemsValues = ["\(randomEngineCoolant)", "\(randomFuelLevel)", "\(randomSpeed)", "\(randomEngineRPM)", "\(randomEngineOilTemp)"]
        
        tableView.reloadData()
    }
    
    private func startSimulation() {
        if reachability.isReachable {
            showStatus(title: "Starting the Simulation")
            
            updateSimulatedValues()
            
            checkDeviceRegistry()
        } else {
            showStatus(title: "No Internet Connection Available")
        }
    }
    
    private func actualDevice() {
        let alertController = UIAlertController(title: "Are you connected to your OBDII Dongle?", message: "You need to connect to your OBDII dongle through Wi-Fi, and then press \"Yes\"", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
            self.talkToSocket()
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
        showStatus(title: "Checking Device Registeration", progress: true)
        
        var url: String = ""
        
        if (ViewController.simulation) {
            url = API.platformAPI + "/device/types/" + API.typeId + "/devices/" + API.getUUID()
        } else {
            url = API.platformAPI + "/device/types/" + API.typeId + "/devices/" + deviceBSSID.replacingOccurrences(of: ":", with: "-")
        }
        
        Alamofire.request(url, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: credentialHeaders).responseJSON { (response) in
            print(response)
            print("\(response.response?.statusCode)")
            
            let statusCode = response.response!.statusCode
            
            switch statusCode{
                case 200:
                    print("Check Device Registry: \(response)");
                    print("Check Device Registry: ***Already Registered***");
                    
                    if let result = response.result.value {
                        let resultDictionary = result as! NSDictionary
                        self.currentDeviceId = resultDictionary["deviceId"] as! String
                        
                        self.showStatus(title: "Device Already Registered")
                        
                        self.deviceRegistered()
                    }
                    
                    self.progressStop()
                    
                    break;
                case 404, 405:
                    print("Check Device Registry: ***Not Registered***")
                    
                    self.progressStop()
                    
                    let alertController = UIAlertController(title: "Your Device is NOT Registered!", message: "In order to use this application, we need to register your device to the IBM IoT Platform", preferredStyle: UIAlertControllerStyle.alert)
                    
                    alertController.addAction(UIAlertAction(title: "Register", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                        self.registerDevice()
                    })
                    
                    alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                        self.showToast(message: "Cannot continue without registering your device!")
                    })
                    
                    self.present(alertController, animated: true, completion: nil)
                    
                    break;
                default:
                    print("Failed to connect IoTP: statusCode: \(statusCode)");
                    
                    self.progressStop()
                    
                    let alertController = UIAlertController(title: "Failed to connect to IBM IoT Platform", message: "Check orgId, apiKey and apiToken of your IBM IoT Platform. statusCode: \(statusCode)", preferredStyle: UIAlertControllerStyle.alert)
                    
                    alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                        self.showStatus(title: "Failed to connect to IBM IoT Platform")
                    })
                    
                    alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                        self.showToast(message: "Cannot continue without connecting to IBM IoT Platform!")
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
        
        self.showStatus(title: "Registering Your Device", progress: true)
        
        let parameters: Parameters = [
            "typeId": API.typeId,
            "deviceId": ViewController.simulation ? API.getUUID() : deviceBSSID.replacingOccurrences(of: ":", with: "-"),
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
                    self.currentDeviceId = ((resultDictionary["deviceId"] ?? "N/A") as? String)!
                    let userDefaultsKey = "iota-obdii-auth-" + self.currentDeviceId
                    
                    if (API.getStoredData(key: userDefaultsKey) != authToken) {
                        API.storeData(key: userDefaultsKey, value: authToken!)
                    }
                    
                    let alertController = UIAlertController(title: "Your Device is Now Registered!", message: "Please take note of this Autentication Token as you will need it in the future", preferredStyle: UIAlertControllerStyle.alert)
                    
                    alertController.addAction(UIAlertAction(title: "Copy to my Clipboard", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                        UIPasteboard.general.string = authToken
                        
                        self.deviceRegistered()
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
                print("Failed to connect IoTP: statusCode: \(statusCode)")
                
                self.progressStop()
                
                let alertController = UIAlertController(title: "Failed to connect to IBM IoT Platform", message: "Check orgId, apiKey and apiToken of your IBM IoT Platform. statusCode: \(statusCode)", preferredStyle: UIAlertControllerStyle.alert)
                
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                    self.showStatus(title: "Failed to connect to IBM IoT Platform")
                })
                
                alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in
                    self.showToast(message: "Cannot continue without connecting to IBM IoT Platform!")
                })
                self.present(alertController, animated: true, completion: nil)
                
                break;
            }
        }
    }
    
    private func deviceRegistered() {
        let clientIdPid = "d:\(API.orgId):\(API.typeId):\(currentDeviceId)"
        
        mqttConnection = MQTTConnection(clientId: clientIdPid, host: "\(API.orgId).messaging.internetofthings.ibmcloud.com", port: 8883)
        mqttConnection?.delegate = self
        
        print("Password \(API.getStoredData(key: ("iota-obdii-auth-" + currentDeviceId)))")
        
        mqttConnection?.connect(deviceId: currentDeviceId)
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
    
    @IBAction func changeFrequency(_ sender: Any) {
        let alertController = UIAlertController(title: "Change the Frequency of Data Being Sent (in Seconds)", message: nil, preferredStyle: UIAlertControllerStyle.alert)
        
        let uiViewController = UIViewController()
        uiViewController.preferredContentSize = CGSize(width: 250,height: 275)
        
        let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 250, height: 275))
        pickerView.delegate = self
        pickerView.dataSource = self
        
        uiViewController.view.addSubview(pickerView)
        alertController.setValue(uiViewController, forKey: "contentViewController")
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.destructive) { (result : UIAlertAction) -> Void in})
        
        alertController.addAction(UIAlertAction(title: "Update", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
            let newInterval: Double = Double(self.frequencyArray[pickerView.selectedRow(inComponent: 0)])
            self.mqttConnection?.updateTimer(interval: newInterval)
        })
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func endSession(_ sender: Any) {
        showToast(message: "Session Ended, application will close now!")
    }
    
    func progressStart() {
        activityIndicator?.startAnimating()
    }
    
    func progressStop() {
        activityIndicator?.stopAnimating()
    }
    
    func showStatus(title: String) {
        if (ViewController.navigationBar == nil) {
            return
        }
        
        ViewController.navigationBar?.topItem?.title = title
    }
    
    internal func showStatus(title: String, progress: Bool) {
        if (activityIndicator == nil || ViewController.navigationBar == nil) {
            return
        }

        ViewController.navigationBar?.topItem?.title = title
        
        if progress {
            activityIndicator?.startAnimating()
        } else {
            activityIndicator?.stopAnimating()
        }
    }
    
    func showToast(message: String) {
        let toast = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.alert)
        
        self.present(toast, animated: true, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exit(0)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableItemsTitles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.value1, reuseIdentifier: "HomeTableCells")
        
        cell.textLabel?.text = tableItemsTitles[indexPath.row]
        
        if ViewController.tableItemsValues[indexPath.row] == "N/A" {
            cell.detailTextLabel?.text = ViewController.tableItemsValues[indexPath.row]
        } else {
            cell.detailTextLabel?.text = ViewController.tableItemsValues[indexPath.row] + tableItemsUnits[indexPath.row]
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return 50
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return frequencyArray.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(frequencyArray[row])"
    }
}
class LicensePresentationController: UIPresentationController{
    private static let LICENSE_VIEW_MARGIN:CGFloat = 20
    var overlay: UIView!
    override func presentationTransitionWillBegin() {
        let containerView = self.containerView!
        self.overlay = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        self.overlay.frame = containerView.bounds
        containerView.insertSubview(self.overlay, at: 0)
    }
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            self.overlay.removeFromSuperview()
        }
    }
    func sizeForChildContentContainer(container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {
        return CGSize(width: parentSize.width - LicensePresentationController.LICENSE_VIEW_MARGIN*2, height: parentSize.height - LicensePresentationController.LICENSE_VIEW_MARGIN*2)
    }
    override var frameOfPresentedViewInContainerView:CGRect {
        var presentedViewFrame = CGRect.zero
        let containerBounds = self.containerView!.bounds
        presentedViewFrame.size = self.sizeForChildContentContainer(container: self.presentedViewController, withParentContainerSize: containerBounds.size)
        presentedViewFrame.origin.x = LicensePresentationController.LICENSE_VIEW_MARGIN
        presentedViewFrame.origin.y = LicensePresentationController.LICENSE_VIEW_MARGIN
        return presentedViewFrame
    }
    override func containerViewWillLayoutSubviews() {
        self.overlay.frame = self.containerView!.bounds
        self.presentedView!.frame = self.frameOfPresentedViewInContainerView
    }
}
