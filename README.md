# ISTimeCheckR

This repo holds R and Python scripts to query NEON TIS LCs grab a few seconds of data to analyze for timestamp issues.

#### `funcTimeStampCheck.R`
This function pulls data with timestamps from the LC are pulled for n seconds, at the end of the pull and "endTime" is calculated. The 
difference between the endTime and each unique sensor is then calculated. The data is then saved as a csv in the `reports` folder. This script 
then deletes any previously saved data in the `ins` and `outs` directories

#### `bat` directory
This directory hosts the batch file that executes the Python script `viewData.py` written by Dan Allen and adapted for this purpose

#### `scripts` directory
This directory hosts the Python script, `viewData.py`, executed by the batch. This script takes any data in the `ins` directory and converts the binary into 
human readable. Then saves it as a csv in the `outs` directory

#### `ins` directory
Briefly holds the data pulled directory from the LC before the `viewData.py` script converts it

#### `outs` directory
Briefly holds the data converted from binary by the `viewData.py` script
