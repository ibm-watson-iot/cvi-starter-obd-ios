/**
 * Copyright 2019 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License. */

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
    
    override func viewWillDisappear(_ animated: Bool) {
        ViewController.isServerSpecified = true
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
        navigationController?.popViewController(animated: true)
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
