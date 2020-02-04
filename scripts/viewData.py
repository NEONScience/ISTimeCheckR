#!/usr/bin/env python3
################################################################################
# 
#   Custom NEON view data app
#
#   Author: Dan Allen
#
#   Description: Extract data from sockets file, ands allow for  
#       batch job to pull data from all sensors for 1 day.
#       
#
################################################################################

import configargparse
import struct
import datetime
import time
import os
import csv

FRONT_NIBBLE_MASK = 0b11110000
BACK_NIBBLE_MASK = 0b00001111


def parse_args():
    ''' Parse Command Line arguments'''
    argp = configargparse.ArgParser(
        default_config_files=['sensor_extract.conf']
    )
    argp.add('-f', '--file', required=True, 
            help='Sockets file path')
    argp.add('-o', '--outputfile', required=False, 
            help='Path to direct output')
    argp.add('-s', '--splitsensors', required=False, action='store_true', 
            help='Create a seperate file for each sensor')
    argp.add('-p', '--printoutput', required=False, action='store_true',
            help='Print output to shell')
    argp.add('-c', '--csvoutput', required=False, action='store_true',
            help='Make csv file')
    # argp.add('-s', '--site', required=False, action='store_true',
    #         help='IP address of site to read from RTU.')

    options = argp.parse_args()
    # Debug options
    # print(argp.format_help())
    return options


def main():
    
    options = parse_args()
    with open(options.file, 'rb') as f:
        
        i = 0
        while True:
            rawHeader = bytearray()
            rawTimestamp = bytearray()
            rawSensorID = bytearray()
            rawSourceMAC = bytearray()
            rawData = bytearray()
            
            outputLine = ""
            
            # Extract Header Info
            rawHeader = f.read(4)
            sampleFormatVersion = (rawHeader[0] & FRONT_NIBBLE_MASK) >> 4
            outputLine += "Version: " + str(sampleFormatVersion) + " "

            dataType = rawHeader[0] & BACK_NIBBLE_MASK
            outputLine += "Type: " + str(dataType) + " "
            
            statusHex = "%02x" % struct.unpack("<B", rawHeader[1:2])
            outputLine += "Status: 0x" + statusHex + " "
            
            outputLine += "Length: " + str(rawHeader[3]) + " "
            
            streamNumber = rawHeader[2]
            outputLine += "Stream: " + str(streamNumber) + "\t"
            
            # Extract timestamp
            rawTimestamp = f.read(8)
            timestamp = struct.unpack("<Q", rawTimestamp)[0]
            timeFormatted = datetime.datetime.fromtimestamp(timestamp/1000000000).strftime('%Y-%m-%d %H:%M:%S.%f')
            outputLine += "Timestamp: " + timeFormatted + "\t"
            
            # Extract Sensor ID
            rawSensorID = f.read(8)
            sensorID = struct.unpack("<Q", rawSensorID)[0]
            outputLine += "Sensor ID: "
            if sensorID > 999999:
                sensorID = "%02x:%02x:%02x:%02x:%02x:%02x" % struct.unpack("<BBBBBB", rawSensorID[5::-1])
                outputLine += sensorID + "\t"
            else:
                outputLine += str(sensorID) + "\t\t"
            
            # Extract Source MAC address
            rawSourceMAC = f.read(8)
            sourceMACAddress = "%02x:%02x:%02x:%02x:%02x:%02x" % struct.unpack("<BBBBBB", rawSourceMAC[5::-1])
            outputLine += "Source MAC: " + sourceMACAddress + "\t"
            
            # Extract Data
            rawData = f.read(4)
            floatData = struct.unpack("<f", rawData)[0]
            outputLine += "Data: " + str(floatData)
            
            # Print to terminal if selected
            if options.printoutput: 
                print(outputLine)
                
            # Print to csv file by sensor
            if options.csvoutput:
                fileLocation = "C:/GitHub/ISTimeCheckR/outs/output.csv"
                # if not os.path.isdir(fileLocation):
                #     os.makedirs(fileLocation)
                
                # fileLocation += "/" + sourceMACAddress.replace(":", "")
                # if not os.path.isdir(fileLocation):
                    # os.makedirs(fileLocation)
                    
                # fileLocation += "/"+ str(sensorID).replace(":", "") + "_" + str(streamNumber) + ".csv"
                with open( fileLocation, 'a', encoding='utf-8') as csvfile:
                    csv_writer = csv.writer(csvfile, delimiter=',',
                                            quoting=csv.QUOTE_MINIMAL)
                    csv_writer.writerow([
                            # timeFormatted,
                            timestamp,
                            sourceMACAddress,
                            sensorID,
                            streamNumber,
                            str(floatData)])
  
            
            # i += 1
            # if i == 10000:
            #     break
   

if __name__ == "__main__":
    main()


