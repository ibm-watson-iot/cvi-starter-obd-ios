/**
 * Copyright 2019 IBM Corp. All Rights Reserved.
 *
 * Licensed under the IBM License, a copy of which may be obtained at:
 *
 * http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?li_formnum=L-DDIN-AHKQ8X&popup=n&title=IBM%20IoT%20for%20Automotive%20Sample%20Starter%20Apps%20%28iOS%20Mobile%29
 *
 * You may not use this file except in compliance with the license.
 */

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
                    self.delegate?.showStatus(title: "Live Data is Being Sent", progress: true)
                } else if statusCode != nil {
                    self.delegate?.showStatus(title: "Failed to publish event (\(statusCode!))", progress: true)
                } else {
                    self.delegate?.showStatus(title: "Failed to publish event (Unkown)", progress: true)
                }
        }
        return true;
    }
  }
