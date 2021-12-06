#include "NimBLEDevice.h";

const int X_INPUT_PIN = 34;
const int Y_INPUT_PIN = 39;
const int Z_INPUT_PIN = 36;

NimBLECharacteristic *xChar;
NimBLECharacteristic *yChar;
NimBLECharacteristic *zChar;

NimBLEService *accelerometerService;

void setup() {
    Serial.begin(115200);
    Serial.println("Hello World");
    NimBLEDevice::init("SD5509");
    
    NimBLEServer *nimbleServer = NimBLEDevice::createServer();
    accelerometerService = nimbleServer->createService("ACCE");
    
    xChar = accelerometerService->createCharacteristic("0001", NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::INDICATE);
    yChar = accelerometerService->createCharacteristic("0002", NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::INDICATE);
    zChar = accelerometerService->createCharacteristic("0003", NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::INDICATE);
    
    accelerometerService->start();
    
    NimBLEAdvertising *nimbleAdvertising = NimBLEDevice::getAdvertising();
    nimbleAdvertising->addServiceUUID("ACCE"); 
    nimbleAdvertising->start();
}

void loop() {
  int xValue = analogRead(X_INPUT_PIN);
  int yValue = analogRead(Y_INPUT_PIN);
  int zValue = analogRead(Z_INPUT_PIN);

  Serial.print("x: ");
  Serial.print(xValue);
  Serial.print(" y: ");
  Serial.print(yValue);
  Serial.print(" z: ");
  Serial.println(zValue);
  
  xChar->setValue(String(xValue));
  yChar->setValue(String(yValue));
  zChar->setValue(String(zValue));

  xChar->notify();
  yChar->notify();
  zChar->notify();

  delay(100);
}
