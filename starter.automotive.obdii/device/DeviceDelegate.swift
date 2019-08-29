/**
 * Copyright 2019 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * https://github.com/ibm-watson-iot/iota-starter-obd-ios/blob/master/LICENSE
 *
 * You may not use this file except in compliance with the license.
 */

import Foundation

protocol DeviceDelegate: class {
    func generateData() -> Dictionary<String, Any>
    func showStatus(title: String, progress: Bool)
}
