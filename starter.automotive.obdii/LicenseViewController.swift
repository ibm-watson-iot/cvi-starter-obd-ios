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

class LicenseViewController: UIViewController {
    @IBOutlet weak var licenseText: UITextView!
    var onAgree = {}
    var onDisagree = {}
    override func viewDidLoad(){
        var message = ""
        
        // load License.txt
        if let filepath = Bundle(for:ViewController.self).path(forResource: "LICENSE", ofType: "") {
            do {
                message = try NSString(contentsOfFile: filepath, usedEncoding: nil) as String
            } catch {
            }
        }
        licenseText.text = message
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        licenseText.setContentOffset(CGPoint.zero, animated: false)
    }
    @IBAction func _onAgree() {
        self.dismiss(animated: true, completion: onAgree)
    }
    @IBAction func _onDisagree() {
        self.dismiss(animated: true, completion: {Void in
            self.onDisagree()
            exit(-1)
        })
    }
}
