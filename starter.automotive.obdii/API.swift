/**
 * Copyright 2016,2019 IBM Corp. All Rights Reserved.
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
import UIKit
import Alamofire

let USER_DEFAULTS_KEY_APP_ROUTE = "appRoute"
let USER_DEFAULTS_KEY_APP_USER = "appUser"
let USER_DEFAULTS_KEY_APP_PASSWORD = "appPassword"

let USER_DEFAULTS_KEY_FREQUENCY = "frequency"

let USER_DEFAULTS_KEY_PROTOCOL = "protocol"
let USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT = "endpoint"
let USER_DEFAULTS_KEY_PROTOCOL_VENDOR = "vendor"
let USER_DEFAULTS_KEY_PROTOCOL_MOID = "mo_id"
let USER_DEFAULTS_KEY_PROTOCOL_TENANTID = "tenant_id"
let USER_DEFAULTS_KEY_PROTOCOL_USERNAME = "username"
let USER_DEFAULTS_KEY_PROTOCOL_PASSWORD = "password"
let USER_DEFAULTS_KEY_PROTOCOL_USERAGENT = "userAgent"

struct API {
    // Platform API URLs
    private static let defaultAppURL = "https://iota-starter-server-fleetmgmt.mybluemix.net"
    private static let defaultAppUser: String = ""
    private static let defaultAppPassword: String = ""
    private static let deviceUUID: String = ""
    
    private static var connectedAppURL = defaultAppURL
    private static var connectedAppUser = defaultAppUser
    private static var connectedAppPassword = defaultAppPassword

    private static let DOESNOTEXIST: String = "doesNotExist"

    private static var sessionManager: SessionManager!

    static func isServerSpecified() -> Bool {
        let uuid = UserDefaults.standard.string(forKey: "iota-starter-uuid")
        return uuid != nil
    }
    
    static func initialize() {
        var uuid = UserDefaults.standard.string(forKey: "iota-starter-uuid")
        if uuid == nil {
            uuid = self.getUUID();
            UserDefaults.standard.setValue(uuid, forKey: "iota-starter-uuid")
        }
        
        let appUrl = UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_ROUTE)
        let appUser = UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_USER) ?? ""
        let appPassword = UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_PASSWORD) ?? ""
        if (appUrl == nil) {
            setEndpoint(appUrl: defaultAppURL, appUsername: defaultAppUser, appPassword: defaultAppPassword)
        } else {
            setEndpoint(appUrl: appUrl!, appUsername: appUser, appPassword: appPassword)
        }

        /*
               let serverTrustPolicies: [String: ServerTrustPolicy] = [
                   "example.mybluemix.net": .pinCertificates(
                       certificates: ServerTrustPolicy.certificates(),
                       validateCertificateChain: true,
                       validateHost: true
                   ),
                   "xxxx.automotive.internetofthings.ibmcloud.com": .pinCertificates(
                       certificates: ServerTrustPolicy.certificates(),
                       validateCertificateChain: true,
                       validateHost: true
                   )
               ]
               sessionManager = SessionManager(serverTrustPolicyManager: ServerTrustPolicyManager(policies: serverTrustPolicies))
        */

        sessionManager = SessionManager.default
    }
    
    static func getUUID() -> String {
        if let uuid = UserDefaults.standard.string(forKey: "iota-starter-uuid") {
            return uuid
        } else {
            let value = NSUUID().uuidString
            UserDefaults.standard.setValue(value, forKey: "iota-starter-uuid")
            return value
        }
    }

    static func storeData(key: String, value: String) {
        UserDefaults.standard.setValue(value, forKey: key)
    }
    
    static func getStoredData(key: String) -> String {
        if let value = UserDefaults.standard.string(forKey: key) {
            return value
        } else {
            return DOESNOTEXIST
        }
    }
    
    static func getEndpoint() -> Dictionary<String, String?> {
        return Dictionary<String, String?>(uniqueKeysWithValues:[
            (USER_DEFAULTS_KEY_APP_ROUTE, UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_ROUTE)),
            (USER_DEFAULTS_KEY_APP_USER, UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_USER)),
            (USER_DEFAULTS_KEY_APP_PASSWORD, UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_PASSWORD))
        ])
    }

    static func useDefault(){
        let url = UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_ROUTE)
        UserDefaults.standard.removeObject(forKey: USER_DEFAULTS_KEY_APP_ROUTE)
        UserDefaults.standard.removeObject(forKey: USER_DEFAULTS_KEY_APP_USER)
        UserDefaults.standard.removeObject(forKey: USER_DEFAULTS_KEY_APP_PASSWORD)
        setEndpoint(appUrl: defaultAppURL, appUsername: defaultAppUser, appPassword: defaultAppPassword)
        if (url != nil) {
            self.clearCache()
        }
        UserDefaults.standard.synchronize()
    }

    static func updateEndpoint(appUrl: String, appUsername: String, appPassword: String) {
        let url = UserDefaults.standard.string(forKey: USER_DEFAULTS_KEY_APP_ROUTE)
        UserDefaults.standard.set(appUrl, forKey: USER_DEFAULTS_KEY_APP_ROUTE)
        UserDefaults.standard.set(appUsername, forKey: USER_DEFAULTS_KEY_APP_USER)
        UserDefaults.standard.set(appPassword, forKey: USER_DEFAULTS_KEY_APP_PASSWORD)
        setEndpoint(appUrl: appUrl, appUsername: appUsername, appPassword: appPassword)
        if (url == nil || url != appUrl) {
            self.clearCache()
        }
        UserDefaults.standard.synchronize()
    }

    static func clearCache() {
        for proto in Protocol.allValues {
            UserDefaults.standard.removeObject(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT))
            UserDefaults.standard.removeObject(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_USERNAME))
            UserDefaults.standard.removeObject(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_PASSWORD))
            UserDefaults.standard.removeObject(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_MOID))
            UserDefaults.standard.removeObject(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_TENANTID))
            UserDefaults.standard.removeObject(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_USERAGENT))
            UserDefaults.standard.removeObject(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_VENDOR))
        }
    }
    
    static func setAccessInfo(proto: Protocol, accessInfo: Dictionary<String, String?>) {
        let endpoint = (accessInfo[USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT] ?? "")
        let username = (accessInfo[USER_DEFAULTS_KEY_PROTOCOL_USERNAME] ?? "")
        let password = (accessInfo[USER_DEFAULTS_KEY_PROTOCOL_PASSWORD] ?? "")
        let userAgent = (accessInfo[USER_DEFAULTS_KEY_PROTOCOL_USERAGENT] ?? "")
        let tenant_id = (accessInfo[USER_DEFAULTS_KEY_PROTOCOL_TENANTID] ?? "")
        let vendor = (accessInfo[USER_DEFAULTS_KEY_PROTOCOL_VENDOR] ?? "")
        let mo_id = (accessInfo[USER_DEFAULTS_KEY_PROTOCOL_MOID] ?? "")
        
        UserDefaults.standard.setValue(endpoint, forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT))
        UserDefaults.standard.setValue(username, forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_USERNAME))
        UserDefaults.standard.setValue(password, forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_PASSWORD))
        UserDefaults.standard.setValue(userAgent, forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_USERAGENT))
        UserDefaults.standard.setValue(vendor, forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_VENDOR))
        UserDefaults.standard.setValue(mo_id, forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_MOID))
        UserDefaults.standard.setValue(tenant_id, forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_TENANTID))
        UserDefaults.standard.synchronize()
    }
    
    static func createAccessInfo(proto: Protocol) -> Dictionary<String, String?>? {
        let endpoint = UserDefaults.standard.string(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT))
        let username = UserDefaults.standard.string(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_USERNAME))
        let password = UserDefaults.standard.string(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_PASSWORD))
        let mo_id = UserDefaults.standard.string(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_MOID))
        if (endpoint == nil || endpoint?.count == 0 || mo_id == nil || mo_id?.count == 0 || username == nil || username?.count == 0) {
            return nil
        }
        
        let vendor = UserDefaults.standard.string(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_VENDOR))
        let tenant_id = UserDefaults.standard.string(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_TENANTID))
        let userAgent = UserDefaults.standard.string(forKey: proto.prefName(key: USER_DEFAULTS_KEY_PROTOCOL_USERAGENT))

        var accessInfo = Dictionary<String, String?>(uniqueKeysWithValues:
            [(USER_DEFAULTS_KEY_PROTOCOL_ENDPOINT, endpoint), (USER_DEFAULTS_KEY_PROTOCOL_MOID, mo_id),
             (USER_DEFAULTS_KEY_PROTOCOL_USERNAME, username), (USER_DEFAULTS_KEY_PROTOCOL_PASSWORD, password)])
        if (vendor != nil) {
            accessInfo.updateValue(vendor, forKey: USER_DEFAULTS_KEY_PROTOCOL_VENDOR)
        }
        if (tenant_id != nil) {
            accessInfo.updateValue(tenant_id, forKey: USER_DEFAULTS_KEY_PROTOCOL_TENANTID)
        }
        if (userAgent != nil) {
            accessInfo.updateValue(userAgent, forKey: USER_DEFAULTS_KEY_PROTOCOL_USERAGENT)
        }
        return accessInfo
    }
    
    private static func setEndpoint(appUrl: String, appUsername: String, appPassword: String) {
        connectedAppURL = appUrl
        connectedAppUser = appUsername
        connectedAppPassword = appPassword
    }

    static func getDeviceAccessInfo(p: Protocol, callback: @escaping (Int, Any)->()){
        let url = connectedAppURL + "/user/device/" + getUUID() + "?protocol=" + p.rawValue.lowercased()
        let params: Parameters = [:]
        doRequest(url: url, method: HTTPMethod.get, params: params, callback: callback)
    }

    static func registerDevice(p: Protocol, callback: @escaping (Int, Any)->()){
        let url = connectedAppURL + "/user/device/" + getUUID() + "?protocol=" + p.rawValue.lowercased()
        let params: Parameters = [:]
        doRequest(url: url, method: HTTPMethod.post, params: params, callback: callback)
    }
    
    static func checkMQTTAvailable(callback: @escaping (Int, Any)->()){
        let url = connectedAppURL + "/user/capability/device"
        let params: Parameters = [:]
        doRequest(url: url, method: HTTPMethod.get, params: params, callback: callback)
    }

    private static func doRequest(url: String, method: HTTPMethod, params: Parameters, callback: @escaping (Int, Any)->()) {
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        sessionManager.request(url, method: method, parameters: params, headers: headers)
            .authenticate(user:connectedAppUser, password: connectedAppPassword)
            .responseJSON { (response) in
                let statusCode = response.response?.statusCode;
                if (statusCode == 200 || statusCode == 201 || statusCode == 202) {
                    callback(statusCode!, response.result.value!)
                } else if (statusCode != nil) {
                    callback(statusCode!, response.error as Any)
                } else {
                    callback(-1, response.error as Any)
                }
            }
    }
}
