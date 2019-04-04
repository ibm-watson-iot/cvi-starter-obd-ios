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

class SpecifyServerViewController: UIViewController {
    
    @IBOutlet weak var moreInfoButton: UIButton!
    @IBOutlet weak var useDefaultButton: UIButton!
    @IBOutlet weak var clearCacheButton: UIButton!
    var serverSpecified = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serverSpecified = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.backItem?.title = ""
        self.title = "Specify Server"
        
        if let appRoute: String = UserDefaults.standard.value(forKey: USER_DEFAULTS_KEY_APP_ROUTE) as? String {
            if let url : URL = URL(string: appRoute) {
                if UIApplication.shared.canOpenURL(url) {
                    if(serverSpecified){
                        performSegue(withIdentifier: "goToHomeScreen", sender: self)
                    }
                } else {
                    showError("No valid URL found from data provided:\n\n\(appRoute)")
                    serverSpecified = false
                }
            } else {
                showError("No valid URL found from data provided:\n\n\(appRoute)")
                serverSpecified = false
            }
        }
        
        super.viewWillAppear(animated)
    }
    
    func showError(_ message: String) {
        let alert = UIAlertController(title: "Scan Error", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel) { action -> Void in
            alert.removeFromParent()
        }
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func useDefaultAction(_ sender: AnyObject) {
        API.useDefault();
    }
    
    @IBAction func moreInfoAction(_ sender: AnyObject) {
        let url : URL = URL(string: "http://www.ibm.com/internet-of-things/iot-industry/iot-automotive/")!
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.openURL(url)
        }
    }

    
    @IBAction func clearCacheAction(_ sender: AnyObject) {
        API.clearCache();
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let target :UITabBarController? = segue.destination as? UITabBarController
        if(segue.identifier == "goToHomeScreen"){
            target?.viewControllers!.remove(at: 0)
        }else if(segue.identifier == "goToCodeReader"){
            serverSpecified = true
        }
    }
}
