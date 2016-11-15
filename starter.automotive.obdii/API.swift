//
//  API.swift
//  starter.automotive.obdii
//
//  Created by Eliad Moosavi on 2016-11-15.
//  Copyright © 2016 IBM. All rights reserved.
//

import Foundation
import UIKit

struct API {
    static var moveToRootOnError = true
    
    static func getUUID() -> String {
        if let uuid = UserDefaults.standard.string(forKey: "iota-starter-uuid") {
            return uuid
        } else {
            let value = NSUUID().uuidString
            UserDefaults.standard.setValue(value, forKey: "iota-starter-uuid")
            return value
        }
    }
    
    static func doRequest(request: NSMutableURLRequest, callback: ((HTTPURLResponse, [NSDictionary]) -> Void)?) {
        print("\(request.httpMethod) to \(request.url!)")
        request.setValue(getUUID(), forHTTPHeaderField: "iota-starter-uuid")
        print("using UUID: \(getUUID())")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil && data != nil else {
                print("error=\(error!)")
                handleError(error: error! as NSError)
                return
            }
            
            print("response = \(response!)")
            
            let responseString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
            print("responseString = \(responseString!)")
            
            let jsonArray = toJsonArray(data: data! as NSData)
            
            let httpStatus = response as? HTTPURLResponse
            print("statusCode was \(httpStatus!.statusCode)")
            
            let statusCode = httpStatus?.statusCode
            
            switch statusCode! {
            case 500..<600:
                self.handleServerError(data: data! as NSData, response: (response as? HTTPURLResponse)!)
                break
            case 200..<400:
                fallthrough
            default:
                callback?((response as? HTTPURLResponse)!, jsonArray)
                moveToRootOnError = false
            }
        }
        task.resume()
    }
    
    static private func toJsonArray(data: NSData) -> [NSMutableDictionary] {
        var jsonArray: [NSMutableDictionary] = []
        do {
            if let tempArray:[NSMutableDictionary] = try JSONSerialization.jsonObject(with: data as Data, options: [JSONSerialization.ReadingOptions.mutableContainers]) as? [NSMutableDictionary] {
                jsonArray = tempArray
            } else {
                if let temp = try JSONSerialization.jsonObject(with: data as Data, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSMutableDictionary {
                    jsonArray.append(temp)
                }
            }
        } catch {
            print("data returned wasn't array of json")
            /*
             do {
             if let temp = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as? NSDictionary {
             jsonArray[0] = temp
             }
             } catch {
             print("data returned wasn't json")
             }
             */
        }
        return jsonArray
    }
    
    static func handleError(error: NSError) {
        doHandleError(title: "Communication Error", message: "\(error)", moveToRoot: moveToRootOnError)
    }
    
    static func handleServerError(data:NSData, response: HTTPURLResponse) {
        let responseString = String(data: data as Data, encoding: String.Encoding.utf8)
        let statusCode = response.statusCode
        doHandleError(title: "Server Error", message: "Status Code: \(statusCode) - \(responseString!)", moveToRoot: false)
    }
    
    static func doHandleError(title:String, message: String, moveToRoot: Bool) {
        var vc: UIViewController?
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            vc = topController
        } else {
            let window:UIWindow?? = UIApplication.shared.delegate?.window
            vc = window!!.rootViewController!
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel) { action -> Void in
            alert.removeFromParentViewController()
            if(moveToRoot){
                UIApplication.shared.cancelAllLocalNotifications()
                // reset view back to Get Started
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let controller = storyboard.instantiateInitialViewController()! as UIViewController
                UIApplication.shared.windows[0].rootViewController = controller
            }
        }
        alert.addAction(okAction)
        
        DispatchQueue.main.async(execute: {
            vc!.present(alert, animated: true, completion: nil)
        })
    }
}
