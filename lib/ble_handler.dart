import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BleData {
  // 파싱 이후 데이터
  String? data;
  String? command;
  BleData({
    this.command,
    this.data,
  });

  // factory 생성자를 사용해 파싱된 데이터를 처리
  factory BleData.fromBytes(List<int> value) {
    String result = String.fromCharCodes(value);
    var items = result.split(",");
    debugPrint("items: $items");
    if (items.length >= 2) {
      String command = items[0];
      String data = items.sublist(1).join(",");
      return BleData(
        command: command,
        data: data,
      );
    } else {
      return BleData();
    }
  }

  @override
  String toString() {
    return 'Command: $command,\nData: $data';
  }
}

class BleState {
  String uuid;
  bool isScanning;
  bool isConnected;
  bool bleAdapterState;

  late ScanResult? scanResult;
  late BluetoothDevice? connectedDevice;
  late BluetoothCharacteristic? connectedCharacteristic;

  late BleData? data;

  BleState({
    this.connectedCharacteristic,
    this.connectedDevice,
    this.scanResult,
    this.data,
    required this.isScanning,
    required this.isConnected,
    required this.bleAdapterState,
    required this.uuid,
  });

  BleState copyWith({
    String? uuid,
    bool? isScanning,
    bool? isConnected,
    bool? bleAdapterState,
    ScanResult? scanResult,
    BluetoothDevice? connectedDevice,
    BluetoothCharacteristic? connectedCharacteristic,
    BleData? data,
    //null 값을 명시적으로 넣어야 할 때가 필요함.
    bool overrideNullValues = false,
  }) {
    return BleState(
      uuid: uuid ?? this.uuid,
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      bleAdapterState: bleAdapterState ?? this.bleAdapterState,
      scanResult: overrideNullValues || scanResult != null
          ? scanResult
          : this.scanResult,
      connectedDevice: overrideNullValues || connectedDevice != null
          ? connectedDevice
          : this.connectedDevice,
      connectedCharacteristic:
          overrideNullValues || connectedCharacteristic != null
              ? connectedCharacteristic
              : this.connectedCharacteristic,
      data: data ?? this.data,
    );
  }
}

final bleProvider =
    StateNotifierProvider<BleProvider, BleState>((ref) => BleProvider());

class BleProvider extends StateNotifier<BleState> {
  // 초기 값 셋팅
  BleProvider()
      : super(
          BleState(
            isScanning: false,
            isConnected: false,
            uuid: "",
            bleAdapterState: false,
          ),
        );

  // 연결 상태 Stream
  StreamSubscription<BluetoothConnectionState>? isConnectSubscription;

  Future<void> init() async {
    checkBleAdapter();
    // 0045 7fd64432-1b6c-7317-bdec-358610041c0e
    // 0005 fec26ec4-6d71-4442-9f81-55bc21d658d0
    state.uuid = "fec26ec4-6d71-4442-9f81-55bc21d658d0";
  }

  // Ble Adapter 체크
  Future<void> checkBleAdapter() async {
    // 지원 기기
    if (!await FlutterBluePlus.isSupported) return;

    BluetoothAdapterState adapterState =
        await FlutterBluePlus.adapterState.first;
    if (adapterState == BluetoothAdapterState.on) {
      state = state.copyWith(bleAdapterState: true);
    } else {
      state = state.copyWith(bleAdapterState: false);
    }
  }

  Future<void> startScan() async {
    // Ble off
    if (!state.bleAdapterState) {
      Fluttertoast.showToast(msg: "블루투스가 꺼져있습니다.");
      return;
    }
    if (state.connectedDevice != null) {
      if (state.isConnected == false) {
        state = state.copyWith(connectedDevice: null);
      }
      return;
    }
    try {
      var _uuid = Guid(state.uuid);
      await FlutterBluePlus.startScan(
        withServices: [_uuid],
        timeout: const Duration(seconds: 30),
      );
      FlutterBluePlus.scanResults.listen(
        (results) async {
          for (ScanResult scanDevice in results) {
            if (_uuid == scanDevice.advertisementData.serviceUuids.first) {
              await stopScan();
              state = state.copyWith(scanResult: scanDevice);
              await connect(scanDevice.device);
              break;
            }
          }
        },
      );
    } catch (e) {
      debugPrint("Scan Error : $e");
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    state = state.copyWith(isScanning: false);
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.connect();
      state = state.copyWith(connectedDevice: device);
      setConnectingListener(device);
    } catch (e) {
      debugPrint("Connect Error : $e");
      Fluttertoast.showToast(msg: "연결을 다시 시도해 주세요.");
    }
  }

  Future<void> setConnectingListener(BluetoothDevice? device) async {
    if (device == null) {
      debugPrint("device is null");
      return;
    }
    isConnectSubscription = device.connectionState.listen((event) async {
      /// Ble가 끊어졌을 경우 진입
      if (event == BluetoothConnectionState.disconnected) {
        if (state.connectedDevice != null) {
          disConnect();
        }
        isConnectSubscription!.cancel();
      }
      if (event == BluetoothConnectionState.connected) {
        // await setMtu(device);
        discoverService().then((value) {
          state = state.copyWith(
            isConnected: true,
          );
        });
      }
    });
  }

  Future<void> setMtu(
    BluetoothDevice device,
  ) async {
    int mtu = await device.mtu.first;
    //512
    try {
      await device.requestMtu(512);
      while (mtu != 512) {
        await Future.delayed(const Duration(seconds: 1));
        mtu = await device.mtu.first;
      }
    } catch (e) {
      debugPrint("mtu Failed : $e");
    }
  }

  Future<void> discoverService() async {
    try {
      List<BluetoothService> services =
          await state.connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == state.uuid) {
          await serviceDiscovery(service);
          break;
        }
      }
    } catch (e) {
      debugPrint("discoverService Error : $e");
      rethrow;
    }
  }

  Future<void> serviceDiscovery(BluetoothService service) async {
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      try {
        state = state.copyWith(
          connectedCharacteristic: characteristic,
        );
        await state.connectedCharacteristic!.setNotifyValue(true);
      } catch (e) {
        rethrow;
      }
      state.connectedCharacteristic!.onValueReceived.listen(handleNotification);
      break;
    }
  }

  /// Ble 알림 핸들러
  Future<void> handleNotification(List<int> value) async {
    // String result = String.fromCharCodes(value);
    BleData bleData = BleData.fromBytes(value);
    debugPrint("bleData : ${bleData.toString()}");
    state = state.copyWith(data: bleData);
  }

  Future<void> disConnect() async {
    if (state.connectedDevice == null) {
      Fluttertoast.showToast(msg: "이미 연결이 끊어져 있습니다.");
      return;
    }
    await state.connectedDevice!.disconnect();
    state = state.copyWith(
      connectedCharacteristic: null,
      connectedDevice: null,
      isConnected: false,
      scanResult: null,
      overrideNullValues: true,
    );
  }

  Future<void> writeData(String data) async {
    await state.connectedCharacteristic!.write(utf8.encode(data));
  }
}
