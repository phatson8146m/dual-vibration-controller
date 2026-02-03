#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

const int MOTOR_PIN = 4; 
bool deviceConnected = false;

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// เพิ่ม Class เช็คการเชื่อมต่อ (สำคัญมาก จะได้รู้ว่าต่อติดจริงไหม)
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println(">>> CONNECTED: มือถือเชื่อมต่อเข้ามาแล้ว!");
      // สั่นเตือน 1 ครั้งเมื่อต่อติด
      digitalWrite(MOTOR_PIN, HIGH); delay(100); digitalWrite(MOTOR_PIN, LOW);
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println(">>> DISCONNECTED: มือถือหลุด");
      BLEDevice::startAdvertising(); // ให้ต่อใหม่ได้ทันที
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue();

      if (value.length() > 0) {
        // ปริ้นค่าที่ได้รับออกมาดู
        Serial.print("Received: ");
        Serial.println(value[0]);

        if (value[0] == '1') {
          Serial.println("Vibrating!");
          digitalWrite(MOTOR_PIN, HIGH);
          delay(200);
          digitalWrite(MOTOR_PIN, LOW);
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  pinMode(MOTOR_PIN, OUTPUT);
  digitalWrite(MOTOR_PIN, LOW);

  // **** ชื่ออุปกรณ์ (เช็คให้ชัวร์ว่าเป็น Vibe_Right) ****
  BLEDevice::init("Vibe_Right"); 

  BLEServer *pServer = BLEDevice::createServer();
  
  // เพิ่มบรรทัดนี้เพื่อเช็ค onConnect
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // **** แก้ไขตรงนี้: เพิ่ม PROPERTY_WRITE_NR ****
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ |
                                         BLECharacteristic::PROPERTY_WRITE |
                                         BLECharacteristic::PROPERTY_WRITE_NR
                                       );

  pCharacteristic->setCallbacks(new MyCallbacks());
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();
  Serial.println("Waiting for App... (Vibe_Right)");
}

void loop() {
  delay(1000);
}