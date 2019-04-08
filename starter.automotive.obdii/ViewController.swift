/**
 * Copyright 2016,2019 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DDIN-AHKQ8X&popup=n&title=IBM%20IoT%20for%20Automotive%20Sample%20Starter%20Apps%20%28iOS%20Mobile%29
 *
 * You may not use this file except in compliance with the license.
 */

import UIKit
import ReachabilitySwift
import Alamofire
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import CocoaMQTT

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource, UIViewControllerTransitioningDelegate, OBDStreamDelegate, DeviceDelegate {
    
//    private let tableItemsTitles: [String] = ["Engine Coolant Temperature", "Fuel Level", "Speed", "Engine RPM", "Engine Oil Temperature"]
    private let tableItemsTitles: [String] = ["Speed", "Engine RPM", "Fuel Level", "Engine Oil Temperature", "Engine Coolant Temperature"]
    private let tableItemsUnits: [String] = [" MPH", " RPM", " %", " °F", " °F"]
    static let obdCommands: [String] = ["0D", "0C", "2F", "5C", "05"]
    private let eventKeys: [String] = ["mo_id", "latitude", "longitude", "altitude", "heading", "timestamp", "trip_id", "speed", "confidence", "map_vendor_name", "map_version", "tenant_id", "props_engineTemp", "props_fuel", "props_engineOilTemp", "props_engineRPM"]

    @IBOutlet weak var navigationRightButton: UIBarButtonItem!
    @IBOutlet weak var vehicleIDLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var protocolSwitch: UISegmentedControl!
    @IBOutlet weak var pauseResumeButton: UIButton!

    private var reachability = Reachability()!
    let locationManager = CLLocationManager()
    static var location: CLLocation?
    
    private var prevLongitude: Double = -1000
    private var prevLatitude: Double = -1000
    private var curHeading: Int = -1000
    
    static var tableItemsValues: [String] = []
    static var tableDisplayValues: [String] = []
    static var navigationBar: UINavigationBar?
    
    private var activityIndicator: UIActivityIndicatorView?
    private var isLicenseAgreed: Bool = false
    private var isApplicationStarted: Bool = false
    static var isServerSpecified: Bool = false

    private var obdStream: OBDStream?
    private var obdSimulation: OBDSimulation?
    static var simulation: Bool = false

    private var frequencyArray: [Int] = Array(1...60)
    private var currentFrequency: Int = 1
    private var curProtocol: Protocol = Protocol.HTTP
    private var vehicleDevice: VehicleDevice?
    
    static var sharedInstance = ViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize this mobile application
        ViewController.isServerSpecified = API.isServerSpecified()
        API.initialize();

        // Initialize the table view to show data
        tableView.dataSource = self
        tableView.delegate = self
        ViewController.tableDisplayValues = [String](repeating: "N/A", count: ViewController.obdCommands.count)
    }

    // Show disclamer UI
    func confirmDisclaimer() {
        let licenseVC: LicenseViewController = self.storyboard!.instantiateViewController(withIdentifier: "licenseViewController") as! LicenseViewController
        licenseVC.modalPresentationStyle = .custom
        licenseVC.transitioningDelegate = self
        licenseVC.onAgree = {() -> Void in
            self.isLicenseAgreed = true
            // Start the application when aggreed to the license
            if ViewController.isServerSpecified {
                self.startApp()
            }
        }
        self.present(licenseVC, animated: true, completion: nil)
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return LicensePresentationController(presentedViewController: presented, presenting: presenting)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        ViewController.navigationBar = self.navigationController?.navigationBar
        ViewController.navigationBar?.barStyle = UIBarStyle.blackOpaque
        ViewController.sharedInstance = self

        activityIndicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.white)
        navigationRightButton.customView = activityIndicator
        
        if isApplicationStarted {
            // Back from the specify server
            checkMQTTAvailable(callback:{() in
                self.checkDeviceRegistry()
            })
        } else if ViewController.isServerSpecified == false {
            // First, show the specify server page to set connecting fleet management server
            if let viewController = self.storyboard!.instantiateViewController(withIdentifier: "specifyServerView") as? SpecifyServerViewController {
                if let navigator = self.navigationController {
                    navigator.pushViewController(viewController, animated: true)
                }
            }
        } else if isLicenseAgreed == true && isApplicationStarted == false {
            startApp()
        }

        if isLicenseAgreed == false {
            confirmDisclaimer()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        vehicleDevice?.stopPublishing()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        ViewController.location = manager.location!
//        print("New Location: \(manager.location!.coordinate.longitude), \(manager.location!.coordinate.latitude)")

        let longitude: Double = ViewController.location?.coordinate.longitude ?? -1000
        let latitude: Double = ViewController.location?.coordinate.latitude ?? -1000
        if (prevLongitude != -1000 && prevLatitude != -1000 &&
            longitude != -1000 && latitude != -1000 &&
            prevLatitude != latitude && prevLongitude != longitude) {
            curHeading = calcHeading(lon1: prevLongitude, lat1: prevLatitude, lon2: longitude, lat2: latitude)
        }
        prevLongitude = longitude
        prevLatitude = latitude
    }
    
    private func calcHeading(lon1: Double, lat1: Double, lon2: Double, lat2: Double) -> Int {
        // this will calculate bearing
        let p1lon = toRadians(n: lon1);
        let p1lat = toRadians(n: lat1);
        let p2lon = toRadians(n: lon2);
        let p2lat = toRadians(n: lat2);
        let y = sin(p2lon-p1lon) * cos(p2lat);
        let x = cos(p1lat)*sin(p2lat) - sin(p1lat)*cos(p2lat)*cos(p2lon-p1lon);
        let brng = atan2(y, x);
        return Int(brng * (180 / Double.pi) + 360) % 360;
    }

    private func toRadians(n: Double) -> Double {
        return n * (Double.pi / 180);
    };

    // Start the application
    func startApp() {
        // Initialize the location manager
        self.locationManager.requestAlwaysAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager.activityType = .automotiveNavigation
            self.locationManager.startUpdatingLocation()
        }
        
        self.checkMQTTAvailable(callback:{() in
            self.isApplicationStarted = true
            let alertController = UIAlertController(title: "Would you like to use our Simulator?", message: "If you do not have a real OBDII device, then click \"Yes\"", preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in
                self.startSimulation()
            })
            alertController.addAction(UIAlertAction(title: "I have a real OBDII dongle", style: UIAlertAction.Style.destructive) { (result : UIAlertAction) -> Void in
                self.actualDevice()
            })
            self.present(alertController, animated: true, completion: nil)
        })
    }

    func updateOBDValues() {
        let speed = Int(round(Double(ViewController.tableItemsValues[0])! * 0.621371192))
        let engineRPM = Int(round(Double(ViewController.tableItemsValues[1])!))
        let fuelLevel = Double(ViewController.tableItemsValues[2])!
        let engineOilTemp = (Double(ViewController.tableItemsValues[3])! * 9 / 5) + 32
        let engineTemp =  (Double(ViewController.tableItemsValues[4])! * 9 / 5) + 32

        ViewController.tableDisplayValues = ["\(speed)", "\(engineRPM)", "\(fuelLevel)", "\(engineOilTemp)", "\(engineTemp)"]
        tableView.reloadData()
    }
    
    // Generate car probe data
    func generateData() -> Dictionary<String, Any> {
        
        // Update simulated value
        if ViewController.simulation {
            obdSimulation?.updateSimulatedValues()
        }

        let longitude: Double = ViewController.location?.coordinate.longitude ?? 0.0
        let latitude: Double = ViewController.location?.coordinate.latitude ?? 0.0
        let altitude: Double = ViewController.location?.altitude ?? 0.0
        let heading: Int = curHeading
        let speed: Int = Int(round(Double(ViewController.tableItemsValues[0])!))
        
        var dict = Dictionary<String, Any>()
        dict.updateValue(longitude, forKey: "longitude")
        dict.updateValue(latitude, forKey: "latitude")
        dict.updateValue(altitude, forKey: "altitude")
        dict.updateValue(heading, forKey: "heading")
        dict.updateValue(speed, forKey: "speed")

        var props = Dictionary<String, Any>()
        props.updateValue(ViewController.tableItemsValues[1], forKey: "engineRPM")
        props.updateValue(ViewController.tableItemsValues[2], forKey: "fuel")
        props.updateValue(ViewController.tableItemsValues[3], forKey: "engineOilTemp")
        props.updateValue(ViewController.tableItemsValues[4], forKey: "engineTemp")
        dict.updateValue(props, forKey: "props")
        return dict;
    }

    // Start with simulation mode
    private func startSimulation() {
        ViewController.simulation = true
        if reachability.isReachable {
            showStatus(title: "Starting the Simulation")
            obdSimulation = OBDSimulation()
            obdSimulation?.delegate = self
            obdSimulation?.connect()
            checkDeviceRegistry()
        } else {
            showStatus(title: "No Internet Connection Available")
        }
    }
    
    // Start with real device mode
    private func actualDevice() {
        let alertController = UIAlertController(title: "Are you connected to your OBDII Dongle?", message: "You need to connect to your OBDII dongle through Wi-Fi, and then press \"Yes\"", preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in
            self.talkToSocket()
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.destructive) { (result : UIAlertAction) -> Void in
            let toast = UIAlertController(title: nil, message: "You would need to connect to your OBDII dongle in order to use this feature!", preferredStyle: UIAlertController.Style.alert)
            
            self.present(toast, animated: true, completion: nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                exit(0)
            }
        })
        self.present(alertController, animated: true, completion: nil)
    }
 
    // Start connecting to OBDII device
    func talkToSocket() {
        obdStream = OBDStream()
        obdStream?.delegate = self
        
        obdStream?.connect()
    }

    // Check if MQTT protocol is supported or not. If true, show the switch control to change protocols
    private func checkMQTTAvailable(callback: @escaping ()->()){
        curProtocol = Protocol.HTTP

        API.checkMQTTAvailable(callback: {(statusCode, result) in
            self.protocolSwitch.isHidden = true;
            if statusCode == 200 {
                let resultDictionary = result as! NSDictionary
                let mqttAvailable = resultDictionary["available"] as! Bool
                if mqttAvailable {
                    // If MQTT is available, restore the current protocol
                    let proto = UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_PROTOCOL) ?? self.curProtocol.rawValue
                    self.curProtocol = Protocol(rawValue: proto) ?? Protocol.HTTP
                    
                    // Update protocol switch UI
                    if self.curProtocol == Protocol.MQTT {
                        self.protocolSwitch.selectedSegmentIndex = 1
                    } else {
                        self.protocolSwitch.selectedSegmentIndex = 0
                    }
                    self.protocolSwitch.isHidden = false;
                }
            } else {
                // Error to get the status
                self.curProtocol = Protocol.HTTP
            }
            callback()
        })
    }

    // Check access information in cache or get the information from server if it does not exist in the cache
    internal func checkDeviceRegistry() {
        showStatus(title: "Checking Device Registeration", progress: true)
        
        // Stop existing trip and initialize new trip
        vehicleDevice?.clean()
        vehicleDevice = nil
        
        if let accessInfo: Dictionary<String, String?> = API.createAccessInfo(proto: curProtocol) {
            deviceRegistered(accessInfo: accessInfo)
            return
        }
        
        API.getDeviceAccessInfo(p: curProtocol, callback: { (statusCode: Int, result: Any) in
            switch statusCode{
            case 200:
                print("Check Device Registry: \(result)");
                print("Check Device Registry: ***Already Registered***");
                
                self.showStatus(title: "Your device is already registered")
                let accessInfo: Dictionary<String, String?> = self.setAccessInfo(resultDictionary: result as! NSDictionary)
                self.deviceRegistered(accessInfo: accessInfo)
                self.progressStop()
                
                break;
            case 404, 405:
                print("Check Device Registry: ***Not Registered***")
                
                self.progressStop()
                let alertController = UIAlertController(title: "Your Device is NOT Registered!", message: "In order to use this application, we need to register your device to the IBM IoT Platform", preferredStyle: UIAlertController.Style.alert)
                alertController.addAction(UIAlertAction(title: "Register", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in
                    self.registerDevice()
                })
                alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertAction.Style.destructive) { (result : UIAlertAction) -> Void in
                    self.showToast(message: "Cannot continue without registering your device!")
                })
                self.present(alertController, animated: true, completion: nil)
                break;
            default:
                self.connectingToApplicationError(statusCode: statusCode);
                break;
            }
        });

     }
    
    private func registerDevice() {
        self.showStatus(title: "Registering Your Device", progress: true)
 
        API.registerDevice(p: curProtocol, callback: { (statusCode: Int, result: Any) in
            switch statusCode{
            case 200, 201:
                let accessInfo: Dictionary<String, String?> = self.setAccessInfo(resultDictionary: result as! NSDictionary)

                let alertController = UIAlertController(title: "Success", message: "Your device is registered!",
                                                        preferredStyle: UIAlertController.Style.alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in
                    self.deviceRegistered(accessInfo: accessInfo)
                })
               self.present(alertController, animated: true, completion: nil)
                self.progressStop()
                break;
            default:
                self.connectingToApplicationError(statusCode: statusCode);
                break;
            }
        })
    }
    
    private func setAccessInfo(resultDictionary: NSDictionary) -> Dictionary <String, String?> {
        var accessInfo = Dictionary<String, String?>();
        for (key, value) in resultDictionary {
            accessInfo.updateValue(value as? String, forKey: key as! String)
        }
        API.setAccessInfo(proto: self.curProtocol, accessInfo: accessInfo)
        return accessInfo
    }
    
    private func connectingToApplicationError(statusCode: Int) {
        print("Failed to register device : statusCode: \(statusCode)");
        
        progressStop()
        
        let alertController = UIAlertController(title: "Failed to register device", message: "Check configurations of the starter app server. statusCode: \(statusCode)", preferredStyle: UIAlertController.Style.alert)
        
        alertController.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in
            self.showStatus(title: "Failed to register device")
        })
        
        alertController.addAction(UIAlertAction(title: "Exit", style: UIAlertAction.Style.destructive) { (result : UIAlertAction) -> Void in
            self.showToast(message: "Cannot continue without connecting to starter app!")
        })
        present(alertController, animated: true, completion: nil)
    }
    
    private func deviceRegistered(accessInfo: Dictionary<String, String?>) {
        showStatus(title: "Device is Ready", progress: true)

        // Show vehicle ID to UI
        let mo_id: String! = accessInfo[USER_DEFAULTS_KEY_PROTOCOL_MOID] ?? "<None>"
        vehicleIDLabel.text = mo_id

        // Start publishing
        vehicleDevice = curProtocol.createVehicleData(accessInfo: accessInfo, eventKeys: eventKeys)
        vehicleDevice?.delegate = self
        vehicleDevice?.startPublishing(uploadInterval: currentFrequency)
    }
    
    @IBAction func changeFrequency(_ sender: Any) {
        let alertController = UIAlertController(title: "Change the Frequency of Data Being Sent (in Seconds)", message: nil, preferredStyle: UIAlertController.Style.alert)
        
        let uiViewController = UIViewController()
        uiViewController.preferredContentSize = CGSize(width: 250,height: 275)
        
        let pickerView = UIPickerView(frame: CGRect(x: 0, y: 0, width: 250, height: 275))
        pickerView.delegate = self
        pickerView.dataSource = self
        
        uiViewController.view.addSubview(pickerView)
        alertController.setValue(uiViewController, forKey: "contentViewController")
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.destructive) { (result : UIAlertAction) -> Void in})
        
        alertController.addAction(UIAlertAction(title: "Update", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in
            self.currentFrequency = self.frequencyArray[pickerView.selectedRow(inComponent: 0)]
            self.vehicleDevice?.startPublishing(uploadInterval: self.currentFrequency)
        })
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func changeProtocol(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            curProtocol = Protocol.HTTP
            break
        case 1:
            curProtocol = Protocol.MQTT
            break
        default:
            return
        }
        UserDefaults.standard.set(curProtocol.rawValue, forKey: USER_DEFAULTS_KEY_PROTOCOL)
        self.checkDeviceRegistry()
    }
    
    @IBAction func pauseResumeAction(_ sender: UIButton) {
        if pauseResumeButton.currentTitle == "Pause" {
            pauseResumeButton.setTitle("Resume", for: UIControl.State.normal)
            vehicleDevice?.stopPublishing()
        } else {
            pauseResumeButton.setTitle("Pause", for: UIControl.State.normal)
            vehicleDevice?.startPublishing(uploadInterval: currentFrequency)
        }
    }

    @IBAction func endSession(_ sender: Any) {
        showToast(message: "Session Ended, application will close now!")
    }
    
    internal func obdStreamError() {
        let alertController = UIAlertController(title: "Connection Failed", message: "Did you want to try again?", preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "Yes", style: UIAlertAction.Style.default) { (result : UIAlertAction) -> Void in
            self.talkToSocket()
        })
        alertController.addAction(UIAlertAction(title: "Back", style: UIAlertAction.Style.destructive) { (result : UIAlertAction) -> Void in
            self.startApp()
        })
        
        self.present(alertController, animated: true, completion: nil)
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
        let toast = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
        
        self.present(toast, animated: true, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            exit(0)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableItemsTitles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "HomeTableCells")
        
        cell.textLabel?.text = tableItemsTitles[indexPath.row]
        
        if ViewController.tableDisplayValues[indexPath.row] == "N/A" {
            cell.detailTextLabel?.text = ViewController.tableDisplayValues[indexPath.row]
        } else {
            cell.detailTextLabel?.text = ViewController.tableDisplayValues[indexPath.row] + tableItemsUnits[indexPath.row]
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
