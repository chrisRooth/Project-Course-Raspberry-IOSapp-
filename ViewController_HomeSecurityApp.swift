//
//  ViewController.swift
//  HomeSecurity
//
//  Created by Christoffer Roth on 2018-01-29.
//  Copyright © 2018 Christoffer Roth. All rights reserved.
//

import UIKit
import MjpegPlayer
import CocoaMQTT
import UserNotifications

class ViewController: UIViewController {

    
    @IBOutlet weak var Background: UIImageView!
    @IBOutlet weak var HomeLabel: UILabel!
    @IBOutlet weak var Camera: UIButton!
    @IBOutlet weak var Picture: UIButton!
    @IBOutlet weak var StreamClose: UIButton!
    
    /*
     * Variables for the MJPG-stream
     */
    private var streamingController: MjpegStreamingController!
    private var imageView: UIImageView!
    private let raspURL = URL(string: "http://192.168.0.104:8090/stream.mjpg")
    
    /*
     * Variables for the MQTT-server
     */
    var mqtt:CocoaMQTT?

    /*
     * Setup function
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        UNUserNotificationCenter.current().requestAuthorization(options: ([.alert, .sound, .badge]), completionHandler: {didAllow, error in
            if didAllow {
                print("Granted")
            }
            else {
                print(error?.localizedDescription as Any)
            }
        })
        
        /*
         * Variables for the MQTT-server
         */
        let clientID = "iOSDev-" + String(ProcessInfo().processIdentifier)
        mqtt = CocoaMQTT(clientID: clientID, host: "192.168.0.104", port: 1883)
        mqtt!.delegate = self
        mqtt!.connect()
        
        imageView = UIImageView(frame: CGRect.init(x: 0, y: 100, width: 320, height: 240))
        self.view.addSubview(imageView)
        imageView.isHidden = true
        
    }
    
    
    /*
     * Function that reacts to picture button when pressed.
     * Send to the raspberry to take a picture and send it to the iphone.
     */
    @IBAction func Picture(_ sender: UIButton) {
        
        HomeLabel.text = "Taking Pictures"
        takePicture()
    }
    
    /*
     * Function that gest a picture from the raspberry camera.
     */
    func takePicture() {
        
        mqtt!.publish("rpi/pic", withString: "TakePic")
        HomeLabel.text = "Picture capturead"
        sleep(UInt32(0.5))
        HomeLabel.text = "Home security"
        
    }
    
    /*
     * Function that reacts to camera button when pressed.
     * Send to the raspberry to start stream and the play the stream.
     */
    @IBAction func Camera(_ sender: UIButton) {
        
        HomeLabel.text = "Streaming.."
        mqtt!.publish("rpi/cam", withString: "StrtStream")
        
        sleep(UInt32(1.0))
        
        playMJPEGVideoStream()
        
    }
    
    /*
     *  Function that starts to play the the stream from the
     *  the raspberry camera.
     */
    func playMJPEGVideoStream() {
        
        StreamClose.isHidden = false
        imageView.isHidden = false
        
        self.view.addSubview(imageView)
        streamingController = MjpegStreamingController(imageView: imageView, contentURL: raspURL!)
        streamingController.play()
        
    }

    /*
     *  Function that closes the stream when the the
     *  close button is pressed. Also sends message to
     *  the raspberry that the stream should be shutdown.
     */
    @IBAction func StreamClose(_ sender: UIButton) {
        
        mqtt!.publish("rpi/cls", withString: "CloseStream")
        print("Sent close stream to raspberry")
            
        sleep(UInt32(1))
            
        streamingController.stop()
        StreamClose.isHidden = true
        imageView.isHidden = true
        Picture.isHidden = false
        
        HomeLabel.text = "Home security"
    }

    
    func sendNotification() {
        
        let content = UNMutableNotificationContent()
        content.title = "Sensor has been activated"
        content.subtitle = "The calibrated distance have been changed"
        content.body = "Sensor has been activated"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "DistChange", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        
    }
    
}

//Exstension of the MQTT-client framework
extension ViewController: CocoaMQTTDelegate {
    
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopic topic: String) {}
    
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopic topic: String) {}
    
    func mqttDidPing(_ mqtt: CocoaMQTT) {}
    
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
    
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {}
    
    
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            mqtt.subscribe("rpi/dist", qos: CocoaMQTTQOS.qos1)
            print("Connected and subscribed to rpi/dist")
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        
        let string = message.string!
        print(string, " Publish")

    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        
        let string = message.string!
        print(string, "Recive")
        
        if string == "DistChanged" {
            print("Setup notification")
            sendNotification()
        }
    }
}


