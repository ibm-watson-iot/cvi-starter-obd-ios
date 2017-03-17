# IBM IoT for Automotive - OBDII Fleet Management App for iOS


## Overview
The IBM IoT for Automotive - Mobility Starter Application uses the **IBM IoT Platform** that is available on **IBM Bluemix** to help you to quickly build a smart fleet management solution. The solution consists of a mobile app and a server component which is the **IBM IoT for Automotive - Fleet Management Starter Web Application**.

### Mobile app
The starter app provides a mobile app to connect to an OBDII dongle plugged in to your car. If you are a user of the application, you can use the mobile app to do the following tasks:

- See real-time data from your car on the screen
- Beam the data to the IBM IoT Platform, which will automatically get synced to the **Fleet Management Web Application**

While you drive the car, the service tracks your location and also records the health of your car. This will happen in the background, which means you could lock your phone in the meantime or use other applications.

Once you want to stop the application from recording your data, simply press "End Session", and the application will close.

You can currently download and install the mobile app on your iOS mobile device.

### Server component
The "IoT for Automotive - OBDII Fleet Management App" interacts with a server component. The server component provides the back-end fleet management and system monitoring service that provides more features for fleet management companies. By default, the mobile app connects to a test server that is provided by IBM. You can also choose to deploy your own server instance to IBM Bluemix and connect your mobile app to that instance instead of the test system. For more information about deploying the fleet management server component, see [ibm-watson-iot/iota-starter-server-fm](https://github.com/ibm-watson-iot/iota-starter-server-fm).

### OBDII Parsing
The application uses a class made in-house to initiate OBDII connection and parse values. It can currently only parse the variables used in this application, but can easily be scaled to support more commands.
[OBDStream.swift](https://github.ibm.com/Watson-IoT/IoT-Automotive-OBD2-iOS/blob/master/starter.automotive.obdii/OBDStream.swift)


## Prerequisites

Before you deploy the iOS application, ensure that the following prerequisites are met:

- The sample source code for the mobile app is only supported for use with an official Apple iOS device.
- The sample source code for the mobile app is also supported only with officially licensed Apple development tools that are customized and distributed under the terms and conditions of your licensed Apple iOS Developer Program or your licensed Apple iOS Enterprise Program.
- Apple Xcode 8.0 integrated development environment (IDE) and [CocoaPods](https://cocoapods.org/) must be installed on the computer that you plan to clone the mobile app source repository onto.


## Deploying the mobile app

To try the iOS application using iOS Emulator, complete the following steps:

1. Open a Terminal session and install CocoaPods by using the following command:   
```$ sudo gem install cocoapods```    
1. Clone the source code repository for the mobile app by using the following git command:    

    ```$ git clone https://github.com/ibm-watson-iot/iota-starter-obd-ios```  
2. Go to source code folder, and then enter the following commands:   
```$ pod install```  
```$ open starter.automotive.obdii.xcworkspace```


3. Edit the **API.swift file**, and set the `orgId` variable to your Organization's ID, and the `apiKey` and `apiToken` variables to your API key and Auth Token from your instance of the IoT Platform.

4. Go to the upper left of the Xcode UI, click **Run**.

5. To deploy the mobile app on your device, see [Launching Your App on Devices](https://developer.apple.com/library/content/documentation/IDEs/Conceptual/AppDistributionGuide/LaunchingYourApponDevices/LaunchingYourApponDevices.html).

## Running the mobile app
Before running the mobile app with a real OBDII dongle, you need to set up WiFi connection between your phone and the OBDII device to use a static IP address, unless the instruction given from the device manufacturer directs otherwise. Do the following steps:

1. Connect your iPhone to the WiFi for your OBD2 dongle

2. Go to "Settings" and select Wi-Fi then select the blue INFO icon to the right of the name of your OBD2 Wi-Fi

3. Make note of both the IP Address and the Subnet Mask address (e.g. 192.168.0.11, 255.255.255.0)

4. Select the "Static" option and enter only the IP and Subnet Mask addresses from Step 3; leave everything else blank

## Reporting defects
To report a defect with the IoT for Automotive - Mobility Starter Application mobile app, go to the [Issues](https://github.com/ibm-watson-iot/iota-starter-obd-ios/issues) section.

## Privacy notice
The "IoT for Automotive - OBDII Fleet Management App for iOS" on Bluemix stores all of the driving data that is obtained while you use the mobile app.

## Questions, comments or suggestions
For your questions, comments or suggestions to us, visit [Watson IoT for Automotive Application community site] (https://www.ibm.com/developerworks/community/groups/service/html/communitystart?communityUuid=3b06ca1c-fd7c-4a59-a888-e5e3a8384091).

## Useful links

- [IBM IoT for Automotive](http://www.ibm.com/internet-of-things/iot-industry/iot-automotive)
- [IBM Watson Internet of Things](http://www.ibm.com/internet-of-things/)  
- [IBM Watson IoT Platform](http://www.ibm.com/internet-of-things/iot-solutions/watson-iot-platform/)   
- [IBM Watson IoT Platform Developers Community](https://developer.ibm.com/iotplatform/)
- [IBM Bluemix](https://bluemix.net/)  
- [IBM Bluemix documentation](https://www.ng.bluemix.net/docs/)  
- [IBM Bluemix developers community](http://developer.ibm.com/bluemix) 
