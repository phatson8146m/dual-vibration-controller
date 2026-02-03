import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DualVibrationApp(),
  ));
}

class DualVibrationApp extends StatefulWidget {
  const DualVibrationApp({super.key});

  @override
  State<DualVibrationApp> createState() => _DualVibrationAppState();
}

class _DualVibrationAppState extends State<DualVibrationApp> {
  BluetoothCharacteristic? charLeft;
  BluetoothCharacteristic? charRight;
  
  bool isLeftConnected = false;
  bool isRightConnected = false;
  String statusLog = "พร้อมใช้งาน กดปุ่ม SCAN";

  // UUID (ต้องตรงกับ ESP32)
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  StreamSubscription? _scanSubscription;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> initBluetooth() async {
    // 1. ขอ Permission
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // 2. เริ่มสแกน
    startScan();
  }

  void startScan() async {
    setState(() => statusLog = "กำลังค้นหาอุปกรณ์...");
    
    // สแกน 15 วินาที
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        String name = r.device.platformName; 
        
        // เจอตัวซ้าย
        if (name == "Vibe_Left" && !isLeftConnected) {
          connectToDevice(r.device, isLeft: true);
        }
        // เจอตัวขวา
        else if (name == "Vibe_Right" && !isRightConnected) {
          connectToDevice(r.device, isLeft: false);
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device, {required bool isLeft}) async {
    try {
      // **** แก้ไข: ใส่ license กลับเข้าไปให้ เพื่อให้รองรับเวอร์ชันเก่า ****
      // ถ้ามันขีดเส้นแดงตรง License.free ให้กด Alt+Enter เพื่อ Import Library หรือเลือกวิธีที่ 1 (อัปเดต)
      await device.connect(autoConnect: false, license: License.free);
      
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid.toString() == CHAR_UUID) {
              setState(() {
                if (isLeft) {
                  charLeft = c;
                  isLeftConnected = true;
                } else {
                  charRight = c;
                  isRightConnected = true;
                }
                statusLog = "ซ้าย: ${isLeftConnected ? 'OK' : '-'} | ขวา: ${isRightConnected ? 'OK' : '-'}";
              });
              print("Connected to ${device.platformName}");
            }
          }
        }
      }
    } catch (e) {
      print("Error connecting: $e");
    }
  }

  void vibrate(String side) async {
    var data = utf8.encode("1"); 
    
    try {
      // ตั้งค่าเป็น false เพื่อให้การสื่อสารเสถียร
      if (side == "LEFT" && charLeft != null) {
        await charLeft!.write(data, withoutResponse: false);
        print("Sent to LEFT");
      } 
      else if (side == "RIGHT" && charRight != null) {
        await charRight!.write(data, withoutResponse: false);
        print("Sent to RIGHT");
      } 
      else if (side == "BOTH") {
        if (charLeft != null) await charLeft!.write(data, withoutResponse: false);
        if (charRight != null) await charRight!.write(data, withoutResponse: false);
        print("Sent to BOTH");
      }
    } catch (e) {
      print("Error sending command: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ESP32 Dual Control")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(statusLog, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: initBluetooth,
              child: const Text("SCAN / CONNECT"),
            ),
            
            const SizedBox(height: 50),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isLeftConnected ? () => vibrate("LEFT") : null, 
                  child: const Text("LEFT")
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: isRightConnected ? () => vibrate("RIGHT") : null, 
                  child: const Text("RIGHT")
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: (isLeftConnected && isRightConnected) ? () => vibrate("BOTH") : null, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              child: const Text("BOTH VIBRATE")
            ),
          ],
        ),
      ),
    );
  }
}