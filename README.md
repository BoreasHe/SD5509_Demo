# SD5509 Demo

## Overview
This is a mini project that aims to develop a Music player for runners. It adjust the upcoming music queue according to the current running speed.

This project uses ESP32 as a BLE server and data collector. An ADXL3xx (Any of the series should work) Accelerometer is connected to the board to collect the acceleration of the runner. Then, it sends the data through BLE service to the mobile. The mobile app will be able to pair up with the board, subscribe to the BLE service and receive changes from the board.

## Configuration
### Board
- ESP32
- ADXL3xx Accelerometer
- NimBLE Arduino library

### Mobile App
- Flutter w/ Dart
- just_audio package
- flutter_blue package 

## Methodology
We conducted tests on the treadmill with the accelerometer and found different level of reading values for different speed. We devided three thresholds for slow, middle and fast speed. The app will determine the running speed level every 7 seconds. Songs with different BPM values will be played according to the current running speed.

## Additional setup
Since this is only a prototype, we set the path of reading the music to be `/storage/emulated/0/Music/sd5509/{slow / mid / fast}`.

## Board source code
[The ino file](https://github.com/BoreasHe/SD5509_Demo/tree/main/_arduino)