# Projektkurs 1DT301
#   
#
# Owner: Christoffer Roth
# Date: 05-03-2018

from time import sleep, time
from datetime import datetime
import picamera  
import RPi.GPIO as GPIO
import paho.mqtt.client as mqtt
import cameraStream as stream
import threading



#Function that subscrubes the mqtt client to topics
def connectionStatus(client, userdata, flags, rc):
    
    mqttClient.subscribe("rpi/cam")
    mqttClient.subscribe("rpi/pic")
    mqttClient.subscribe("rpi/dist")
    mqttClient.subscribe("rpi/cls")
    

#Function that get a msg from iphone and does something
def messageDecoder(client,userdata, msg):
    
    message = msg.payload.decode(encoding='UTF-8')

    if message == "StrtStream":
        print(message)
        cameraStream()

    elif message == "TakePic":
        print(message)
        timestamp = datetime.fromtimestamp(time()).strftime('%-Y%-m%-s-%-H-%-M%-S')
        
        if serverStreaming():
            camera.wait_recording(1)
            camera.rotation = 180
            camera.capture('/home/pi/Python/HomeSecurityPic/img{}.jpeg'.format(timestamp), use_video_port=True, resize=(1024, 768))

        else:
            camera.rotation = 180
            camera.capture('/home/pi/Python/HomeSecurityPic/img{}.jpeg'.format(timestamp), use_video_port=True, resize=(1024, 768))
        print("Picture is taken")

    elif message == "CloseStream":
        camera.stop_recording()
        server_thread = threading.Thread(target=server.shutdown)
        server_thread.deamon = True
        server_thread.start()
        server_streaming = False
        print(message)
        
    else:
        print("Not a valid message") 
        
def serverStreaming():
    return server_streaming
    
#Function that sends a message that the distance have changed to iphone
def sendDistChangeMsg():

    mqttClient.publish("rpi/dist", "DistChanged")
    print("Notification is sent, calibrate new distance")
    sleep(10)
    calibDistance = calibratedDistance()
    print("Calibrated distance ", calibDistance)
    

#Function that starts the streamserver and streams the video
def cameraStream():

        camera.rotation = 180
        camera.start_recording(stream.output, format='mjpeg')
        print("+++Stream has started+++")
        #try:
        server_thread = threading.Thread(target=server.serve_forever)
        server_thread.deamon = True
        print("Server is starting")
        server_thread.start()
        server_streaming = True
        print("Server thread running ", server_thread.name)


#Function that activates the sensor and takes its distance
def distSensor():

    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)

    ECHO = 3
    TRIG = 2
    
    GPIO.setup(TRIG, GPIO.OUT)
    GPIO.setup(ECHO, GPIO.IN)

    GPIO.output(TRIG, False)
    sleep(2)

    GPIO.output(TRIG, True)
    sleep(0.00001)
    GPIO.output(TRIG, False)

    while GPIO.input(ECHO)==0:
        pulse_start = time()

    while GPIO.input(ECHO)==1:
        pulse_end = time()

    pulse_duration = pulse_end - pulse_start

    distance = pulse_duration * 17150

    distance = round(distance, 2)

    GPIO.cleanup()

    return distance


#Function that checks if the distance of the sensor has change
def isDistanceChanged(calibDist):

    currentDist = distSensor()
    print("Distance deviance is " , currentDist - calibDist)
    if (currentDist - calibDist) > 10:
        return True
    else:
        return False
        

#Calibrate a new distance
def calibratedDistance():

    newDistance = distSensor()

    return newDistance



###########################
#                         #
# SETUP AND MAIN FUNCTION #
#                         #
###########################


#Setup for the mqtt-client
mqttClientName = "RPI3B"
serverAddress = "192.168.0.104"
mqttClient = mqtt.Client(mqttClientName)

mqttClient.on_connect = connectionStatus
mqttClient.on_message = messageDecoder

mqttClient.connect(serverAddress)
print("Client connected to MQTT-server")
mqttClient.loop_start()

#Setup for video stream server
stream.output = stream.StreamingOutput()
address = ('', 8090)
server = stream.StreamingServer(address, stream.StreamingHandler)
server_streaming = False

#Camera setup
camera = picamera.PiCamera(resolution='320x240', framerate=24)


calibDistance = calibratedDistance()


#main function that will run all the time
def main():
    
    print("Calibrated distance ", calibDistance)
    
    while True:

        if isDistanceChanged(calibDistance):
                sendDistChangeMsg()


                
if __name__ == '__main__':
    main()








    
