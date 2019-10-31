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

import Foundation
import Alamofire

class HTTPVehicleDevice: VehicleDevice {
    private static let defaultVdhUserAgent = "IBM IoT Connected Vehicle Insights Client";
   
    override init(accessInfo: Dictionary<String, String?>, eventKeys: Array<String>, format: EventFormat) {
        super.init(accessInfo: accessInfo, eventKeys: eventKeys, format: EventFormat.JSON)
    }
    
    override func isReady() -> Bool {
        if (endpoint == nil || endpoint!.count == 0) {
            return false;
        }
        return true;
    }

    override func publishJsonEvent(eventDict: Dictionary<String, Any>) throws -> Bool {
        let credentials: String = username! + ":" + password!;
        let credentialsData = (credentials).data(using: String.Encoding.utf8)
        let credentialsBase64 = credentialsData!.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        let headers: HTTPHeaders = [
            "User-Agent": userAgent ?? HTTPVehicleDevice.defaultVdhUserAgent,
            "Authorization": "Basic " + credentialsBase64
        ];
        var url: String = "\(endpoint!)?op=sync"
        if tenant_id != nil {
            url += "&tenant_id=\(tenant_id!)"
        }
        
        Alamofire.request(url, method: HTTPMethod.post, parameters: eventDict, encoding: JSONEncoding.default, headers: headers)
            .responseJSON { (response) in
                let statusCode = response.response?.statusCode;
                if statusCode == 200 {
                    self.delegate?.showStatus(title: "Successfully Published to Server", progress: false)
                } else if statusCode != nil {
                    self.delegate?.showStatus(title: "Failed to publish event (\(statusCode!))", progress: false)
                } else {
                    self.delegate?.showStatus(title: "Failed to publish event (Unkown)", progress: false)
                }
        }
        return true;
    }
  }
