#include <Wire.h>
#include <ICM_20948.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

ICM_20948_I2C myICM;
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHARACTERISTIC_UUID "abcdef01-1234-5678-1234-56789abcdef0"

// Kalman Filter
class SimpleKalmanFilter {
  float est, errEst, errMeas, q;
public:
  SimpleKalmanFilter(float mea_e, float est_e, float q) {
    errMeas = mea_e;
    errEst = est_e;
    this->q = q;
    est = 0;
  }
  float update(float mea) {
    float kalmanGain = errEst / (errEst + errMeas);
    est = est + kalmanGain * (mea - est);
    errEst = (1.0 - kalmanGain) * errEst + fabs(est - mea) * q;
    return est;
  }
};

SimpleKalmanFilter kfX(0.02, 0.05, 0.01);
SimpleKalmanFilter kfY(0.02, 0.05, 0.01);
SimpleKalmanFilter kfZ(0.02, 0.05, 0.01);

const int BUFFER_SIZE = 200;
String preSpikeBuffer[BUFFER_SIZE];
int bufferIndex = 0;

float lastAccX = 0, lastAccY = 0, lastAccZ = 0;
float lastPitch = 0, lastRoll = 0;

const float PITCH_THRESHOLD = 20.0;
const float ROLL_THRESHOLD = 10.0;
const float ACCEL_THRESHOLD = 700.0;

unsigned long lastUpdate = 0;
bool captureWindow = false;
unsigned long captureStart = 0;
bool sentPreSpike = false;

class MyCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("✅ BLE Connected");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("❌ BLE Disconnected");
    delay(500); // Wait for BLE stack to stabilize
    if (!pServer->getAdvertising()->start()) {
      Serial.println("❌ Failed to restart advertising");
    } else {
      Serial.println("📡 BLE Advertising restarted");
    }
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  Wire.begin(6, 7);

  if (myICM.begin(Wire) != ICM_20948_Stat_Ok) {
    Serial.println("❌ ICM-20948 not detected");
    while (1);
  }
  Serial.println("✅ ICM-20948 initialized");

  BLEDevice::init("ESP32_IMU");
  BLEDevice::setMTU(200); // <-- Set MTU to 200 here
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  // Configure advertising parameters
  BLEAdvertising *pAdvertising = pServer->getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMaxPreferred(0x12);
  pAdvertising->start();

  Serial.println("📡 BLE Advertising started as 'ESP32_IMU'");
  lastUpdate = millis();
}

void loop() {
  if (deviceConnected && myICM.dataReady()) {
    myICM.getAGMT();

    float rawX = myICM.accX();
    float rawY = myICM.accY();
    float rawZ = myICM.accZ();
    float gx = myICM.gyrX();
    float gy = myICM.gyrY();
    float gz = myICM.gyrZ();
    float magX = myICM.magX();
    float magY = myICM.magY();
    float magZ = myICM.magZ();

    float accX = kfX.update(rawX);
    float accY = kfY.update(rawY);
    float accZ = kfZ.update(rawZ);
    float pitch = atan2(-accY, accZ) * 180.0 / PI;
    float roll  = atan2(-accX, accZ) * 180.0 / PI;
    float pitchRad = atan2(-accY, accZ);
    float rollrad = atan2(-accX, accZ);

    // Tilt-compensated Yaw using magnetometer
    float yawRad = atan2(
      -magY * cos(rollrad) + magZ * sin(rollrad),
       magX * cos(pitchRad) +
       magY * sin(pitchRad) * sin(rollrad) +
       magZ * sin(pitchRad) * cos(rollrad)
    );
    float yaw = yawRad * 180.0 / PI;
    if (yaw  < 0 ) yaw += 360.0;
    if (pitch < 0) pitch += 360.0;
    if (roll < 0) roll += 360.0;

    float deltaX = accX - lastAccX;
    float deltaY = accY - lastAccY;
    float deltaZ = accZ - lastAccZ;
    float deltaMag = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ);

    lastAccX = accX;
    lastAccY = accY;
    lastAccZ = accZ;

    float pitchChange = fabs(pitch - lastPitch);
    float rollChange = fabs(roll - lastRoll);
    lastPitch = pitch;
    lastRoll = roll;

    // Format sensor data
    String data = "ACC:" + String(accX, 1) + "," + String(accY, 1) + "," + String(accZ, 1) +
                  " GYR:" + String(gx, 1) + "," + String(gy, 1) + "," + String(gz, 1) +
                  " MAG:" + String(magX, 1) + "," + String(magY, 1) + "," + String(magZ, 1) +
                  " PITCH:" + String(pitch) + " ROLL:" + String(roll) + " YAW:" + String(yaw);

    // Store in circular buffer
    preSpikeBuffer[bufferIndex] = data;
    bufferIndex = (bufferIndex + 1) % BUFFER_SIZE;

    // Detect spike
    bool spike = ((rollChange > ROLL_THRESHOLD && pitchChange > PITCH_THRESHOLD) && deltaMag > ACCEL_THRESHOLD);

    if (spike && !captureWindow) {
      captureWindow = true;
      captureStart = millis();
      sentPreSpike = false;
    }

    // Send pre-spike buffer (only once)
    if (captureWindow && !sentPreSpike) {
      for (int i = bufferIndex; i < BUFFER_SIZE; i++) {
        pCharacteristic->setValue(preSpikeBuffer[i].c_str());
        pCharacteristic->notify();
        delay(5);
      }
      for (int i = 0; i < bufferIndex; i++) {
        pCharacteristic->setValue(preSpikeBuffer[i].c_str());
        pCharacteristic->notify();
        delay(5);
      }
      sentPreSpike = true;
    }

    // During 2s post-spike capture
    if (captureWindow) {
      Serial.println(data);
      pCharacteristic->setValue(data.c_str());
      pCharacteristic->notify();
      if (millis() - captureStart >= 2000) {
        captureWindow = false;
      }
    }

    delay(5); // ~200 Hz
  }
} 