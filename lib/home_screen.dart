import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyundai_ble_test_app/ble_handler.dart';

// TODO : 버튼 클릭 -> UUID 생성 하는 기능 추가 하기
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final bleController;
  @override
  void initState() {
    bleController = ref.read(bleProvider.notifier);
    bleController.init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);
    debugPrint("build!!");
    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buttons(bleState),
                const SizedBox(height: 50),
                Text("Watch uuid : ${bleState.uuid}"),
                const SizedBox(height: 10),
                Text("Ble On/Off : ${bleState.bleAdapterState}"),
                const SizedBox(height: 10),
                Text(
                    "Scan Result : ${bleState.scanResult?.device.platformName}"),
                const SizedBox(height: 10),
                Text("Current Connect Device: ${bleState.connectedDevice}"),
                const SizedBox(height: 10),
                Text("Connect State : ${bleState.isConnected}"),
                const SizedBox(height: 20),
                const Center(
                    child: Text(
                  "<Read Data>",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                Text("${bleState.data}"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttons(BleState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                await bleController.startScan();
              },
              child: const Text("스캔 하기"),
            ),
            ElevatedButton(
              onPressed: () async {
                await bleController.stopScan();
              },
              child: const Text("스캔 스탑"),
            ),
          ],
        ),
        Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                await bleController.checkBleAdapter();
              },
              child: const Text("Ble Adapter 상태 체크"),
            ),
            ElevatedButton(
              onPressed: () async {
                await bleController.disConnect();
              },
              child: const Text("연결 끊기"),
            ),
            ElevatedButton(
              onPressed: () async {
                await bleController.writeData("0");
              },
              child: const Text("데이터 트리거 버튼"),
            ),
          ],
        ),
      ],
    );
  }
}
