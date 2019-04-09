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
import AVFoundation

class QRCodeReaderViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate
{
    var objCaptureSession:AVCaptureSession?
    var objCaptureVideoPreviewLayer:AVCaptureVideoPreviewLayer?
    var vwQRCode:UIView?
    var sourceViewController: String?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.configureVideoCapture()
        self.addVideoPreviewLayer()
        self.initializeQRView()
    }
    
    func configureVideoCapture() {
        let objCaptureDevice = AVCaptureDevice.default(for: AVMediaType(rawValue: AVMediaType.video.rawValue))
        var error:NSError?
        let objCaptureDeviceInput: AnyObject!
        if (objCaptureDevice != nil) {
            do {
                objCaptureDeviceInput = try AVCaptureDeviceInput(device: objCaptureDevice!) as AVCaptureDeviceInput
                
            } catch let error1 as NSError {
                error = error1
                objCaptureDeviceInput = nil
            }
        } else {
            objCaptureDeviceInput = nil;
        }
        if (objCaptureDevice == nil || error != nil) {
            let alert = UIAlertController(title: "No camera detected",
                                          message: "Enter the route to the server", preferredStyle: .alert)
            let endpoint: Dictionary<String, String?> = API.getEndpoint()
            // Add the text field for entering the route manually
            var routeTextField: UITextField?
            
            alert.addTextField { textField in
                routeTextField = textField
                routeTextField?.placeholder = NSLocalizedString("Application Route", comment: "")
                if let appRoute: String = endpoint[USER_DEFAULTS_KEY_APP_ROUTE] as? String {
                    routeTextField?.text = appRoute
                }
            }

            // Add the text field for entering the app user manually
            var userTextField: UITextField?
            
            alert.addTextField { textField in
                userTextField = textField
                userTextField?.placeholder = NSLocalizedString("Username", comment: "")
                if let appUser: String = endpoint[USER_DEFAULTS_KEY_APP_USER] as? String {
                    userTextField?.text = appUser
                }
            }

            // Add the text field for entering the Push Notifications Client Secret manually
            var passwdTextField: UITextField?
            
            alert.addTextField { textField in
                passwdTextField = textField
                passwdTextField?.placeholder = NSLocalizedString("Password", comment: "")
                if let appPassword: String = endpoint[USER_DEFAULTS_KEY_APP_PASSWORD] as? String {
                    passwdTextField?.text = appPassword
                }
            }
            
            // Create the actions.
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
                self.navigationController?.popViewController(animated: true)
            }
            
            let okAction = UIAlertAction(title: "OK", style: .default) { action in
                let appRoute = routeTextField?.text
                let appUser = userTextField?.text
                let appPassword = passwdTextField?.text
                if appRoute != "" {
                    API.updateEndpoint(appUrl: appRoute!, appUsername: appUser ?? "", appPassword: appPassword ?? "")
                }
                self.navigationController?.popViewController(animated: true)
            }
            
            // Add the actions.
            alert.addAction(cancelAction)
            alert.addAction(okAction)
            
            self.present(alert, animated: true){}
            return
        }
        
        objCaptureSession = AVCaptureSession()
        objCaptureSession?.addInput(objCaptureDeviceInput as! AVCaptureInput)
        let objCaptureMetadataOutput = AVCaptureMetadataOutput()
        objCaptureSession?.addOutput(objCaptureMetadataOutput)
        objCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        objCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
    }
    
    func addVideoPreviewLayer() {
        if (objCaptureSession == nil) {
            return;
        }
        objCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: objCaptureSession!)
        objCaptureVideoPreviewLayer?.videoGravity = AVLayerVideoGravity(rawValue: convertFromAVLayerVideoGravity(AVLayerVideoGravity.resizeAspectFill))
        objCaptureVideoPreviewLayer?.frame = view.layer.bounds
        self.view.layer.addSublayer(objCaptureVideoPreviewLayer!)
        objCaptureSession?.startRunning()
    }
    
    func initializeQRView() {
        vwQRCode = UIView()
        vwQRCode?.layer.borderColor = UIColor.red.cgColor
        vwQRCode?.layer.borderWidth = 5
        self.view.addSubview(vwQRCode!)
        self.view.bringSubviewToFront(vwQRCode!)
    }
    
    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects == nil || metadataObjects.count == 0 {
            vwQRCode?.frame = CGRect.zero
            return
        }
        let objMetadataMachineReadableCodeObject = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if objMetadataMachineReadableCodeObject.type.rawValue == AVMetadataObject.ObjectType.qr.rawValue {
            let objBarCode = objCaptureVideoPreviewLayer?.transformedMetadataObject(for: objMetadataMachineReadableCodeObject as AVMetadataMachineReadableCodeObject) as! AVMetadataMachineReadableCodeObject
            
            vwQRCode?.frame = objBarCode.bounds;
            
            if objMetadataMachineReadableCodeObject.stringValue != nil {
                let fullString = objMetadataMachineReadableCodeObject.stringValue!.components(separatedBy: ",")
                
                if fullString.count == 4 && fullString[0] == "1" && fullString[1] != ""{
                    let appRoute = fullString[1]
                    let appUser = fullString[2]
                    let appPassword = fullString[3]
                    API.updateEndpoint(appUrl: appRoute, appUsername: appUser, appPassword: appPassword)
                }
            }
        }
        navigationController?.popViewController(animated: true)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVMediaType(_ input: AVMediaType) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVLayerVideoGravity(_ input: AVLayerVideoGravity) -> String {
    return input.rawValue
}
