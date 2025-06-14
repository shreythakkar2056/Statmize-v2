class BLEConstants {
  // Device identifiers
  static const String DEVICE_NAME = "ESP32_IMU";
  static const String SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0";
  static const String CHARACTERISTIC_UUID = "abcdef01-1234-5678-1234-56789abcdef0";
  
  // Connection timeouts
  static const int IOS_TIMEOUT_SECONDS = 15;
  static const int ANDROID_TIMEOUT_SECONDS = 10;
  static const int SCAN_TIMEOUT_SECONDS = 15;
  
  // Connection states
  static const String STATE_CONNECTED = "Connected & Tracking";
  static const String STATE_CONNECTING = "Connecting...";
  static const String STATE_SCANNING = "Scanning for Tracker";
  static const String STATE_DISCONNECTED = "Not Connected";
}