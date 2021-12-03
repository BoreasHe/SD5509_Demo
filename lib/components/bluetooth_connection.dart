import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:sd5509/redux/accelero_data.dart';
import 'package:sd5509/redux/app_state.dart';
import 'package:sd5509/redux/bluetooth_state.dart';
import 'package:sd5509/redux/music_sync_state.dart';
import 'package:sd5509/redux/speed_mode.dart';

class BluetoothConnection extends StatefulWidget {
  const BluetoothConnection({Key key = const Key("bluetooth-connection")})
      : super(key: key);

  @override
  _BluetoothConnectionState createState() => _BluetoothConnectionState();
}

class _BluetoothConnectionState extends State<BluetoothConnection> {
  final int BUFFER_SIZE = 70;
  final int LOW_SPEED_BOUND = -200;
  final int MIDDLE_SPEED_BOUND = -400;
  final int HIGH_SPEED_BOUND = -1000;

  final int LOW_SPEED_PEAK_THRESHOLD = 3;
  final int MIDDLE_SPEED_PEAK_THRESHOLD = 2;
  final int HIGH_SPEED_PEAK_THRESHOLD = 2;

  FlutterBlue flutterBlue = FlutterBlue.instance;
  List<BluetoothDevice> _devicesList = [];
  bool _isScanning = false;

  BluetoothCharacteristic? _xChar;
  BluetoothCharacteristic? _yChar;
  BluetoothCharacteristic? _zChar;
  StreamSubscription<BluetoothDeviceState>? _connectedDeviceStateSub;
  StreamSubscription<List<int>>? _xSub;
  StreamSubscription<List<int>>? _ySub;
  StreamSubscription<List<int>>? _zSub;

  List<int>? _calibration;

  List<int> _bufferValue = <int>[];

  BluetoothState? get _isBLEOn =>
      StoreProvider.of<AppState>(context).state.bluetoothState.state;

  BluetoothDevice? get _connectedDevice =>
      StoreProvider.of<AppState>(context).state.bluetoothState.connectedDevice;

  @override
  void initState() {
    log("Start Init.");
    super.initState();

    flutterBlue.state.listen((status) {
      log("Bluetooth is " + (status.toString()));
      StoreProvider.of<AppState>(context).dispatch(
        SetBluetoothAction(
          StoreProvider.of<AppState>(context)
              .state
              .bluetoothState
              .copyWith(state: status),
        ),
      );
    });
    _asyncScan();
  }

  _asyncScan() async {
    var isBLEOn = await flutterBlue.isOn;

    log("Bluetooth $_isBLEOn.");
    if (isBLEOn) {
      log("Listen to discovered devices.");
      flutterBlue.scanResults.listen((List<ScanResult> results) {
        for (ScanResult result in results) {
          _addDeviceTolist(result.device);
        }
      });

      log("Start scanning");

      setState(() {
        _isScanning = true;
      });

      flutterBlue
          .startScan(timeout: const Duration(seconds: 5))
          .then((value) => {_stopScan()});
    } else {
      log("Bluetooth is closed.");
    }
  }

  _stopScan() {
    try {
      flutterBlue.stopScan();
      setState(() {
        _devicesList.clear();
        _isScanning = false;
      });
    } catch (e) {
      log("Error: stop scan");
    }
  }

  _addDeviceTolist(final BluetoothDevice device) {
    if (device.name == "SD5509" && !_devicesList.contains(device)) {
      log("Deviced found: ${device.name} | ${device.id}");
      setState(() {
        _devicesList.add(device);
      });
    }
  }

  _startSync() {
    StoreProvider.of<AppState>(context).dispatch(
      SetMusicSyncAction(
        MusicSyncState(MusicSyncStatus.Sync),
      ),
    );
    _startCalibrate();
  }

  Future<List<int>> _startCalibrate() async {
    StoreProvider.of<AppState>(context).dispatch(
      SetMusicSyncAction(
        MusicSyncState(MusicSyncStatus.Calibrate),
      ),
    );

    List<int> xCalibrateList = <int>[];
    List<int> yCalibrateList = <int>[];
    List<int> zCalibrateList = <int>[];

    // Calibrate for 2s
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      xCalibrateList
          .add(StoreProvider.of<AppState>(context).state.acceleroDataState.x);
      yCalibrateList
          .add(StoreProvider.of<AppState>(context).state.acceleroDataState.y);
      zCalibrateList
          .add(StoreProvider.of<AppState>(context).state.acceleroDataState.z);
    }

    // Average the calibration
    int xMean = (xCalibrateList.reduce((a, b) => a + b) / xCalibrateList.length)
        .round();
    int yMean = (yCalibrateList.reduce((a, b) => a + b) / yCalibrateList.length)
        .round();
    int zMean = (zCalibrateList.reduce((a, b) => a + b) / zCalibrateList.length)
        .round();

    setState(() {
      _calibration = [xMean, yMean, zMean];
    });

    StoreProvider.of<AppState>(context).dispatch(
      SetMusicSyncAction(
        MusicSyncState(MusicSyncStatus.Sync),
      ),
    );

    return [xMean, yMean, zMean];
  }

  _stopSync() {
    StoreProvider.of<AppState>(context).dispatch(
      SetMusicSyncAction(
        MusicSyncState(MusicSyncStatus.Desync),
      ),
    );
  }

  _manualDisconnect() async {
    log("Start manual disconnection.");

    BluetoothDevice? device = StoreProvider.of<AppState>(context)
        .state
        .bluetoothState
        .connectedDevice;

    log("Connected device is: " + (device?.name ?? "null"));

    await device?.disconnect();
    StoreProvider.of<AppState>(context).dispatch(
      SetBluetoothAction(
        StoreProvider.of<AppState>(context)
            .state
            .bluetoothState
            .copyWith(connectedDevice: null),
      ),
    );
  }

  _bufferAcceleroValue(int value) {
    _bufferValue.add(value);
    // Current: 7sec = 70 values in total
    if (_bufferValue.length >= BUFFER_SIZE) {
      // Analyize the buffer

      int targetNorm = _calibration?[1] ?? 1950;
      targetNorm = 1950;

      // High speed
      if (_bufferValue
              .where((val) => val < targetNorm + MIDDLE_SPEED_BOUND)
              .length >=
          HIGH_SPEED_PEAK_THRESHOLD) {
        StoreProvider.of<AppState>(context).dispatch(
          SetSpeedModeAction(
            SpeedModeState(SpeedMode.Fast),
          ),
        );
      }
      // Middle speed
      else if (_bufferValue
              .where((val) => val < targetNorm + LOW_SPEED_BOUND)
              .length >=
          MIDDLE_SPEED_PEAK_THRESHOLD) {
        StoreProvider.of<AppState>(context).dispatch(
          SetSpeedModeAction(
            SpeedModeState(SpeedMode.Middle),
          ),
        );
      }
      // Low speed
      else if (_bufferValue.where((val) => val < targetNorm).length >=
          LOW_SPEED_PEAK_THRESHOLD) {
        StoreProvider.of<AppState>(context).dispatch(
          SetSpeedModeAction(
            SpeedModeState(SpeedMode.Slow),
          ),
        );
      }

      _bufferValue.clear();
    }
  }

  _onDeviceDisconnect() async {
    try {
      await _connectedDeviceStateSub?.cancel();

      await _xChar?.setNotifyValue(false);
      await _yChar?.setNotifyValue(false);
      await _zChar?.setNotifyValue(false);

      await _xSub?.cancel();
      await _ySub?.cancel();
      await _zSub?.cancel();
    } catch (e) {}
  }

  _readCharacteristics() async {
    if (_connectedDevice == null) return;

    log("Reading characteristics");

    List<BluetoothService> services =
        await _connectedDevice!.discoverServices();

    BluetoothService accService = services
        .firstWhere((sv) => sv.uuid.toString().substring(0, 8) == "0000acce");

    log("Discovered target ACCE service");

    setState(() {
      _xChar = accService.characteristics[0];
      _yChar = accService.characteristics[1];
      _zChar = accService.characteristics[2];
    });

    // X
    await accService.characteristics[0].setNotifyValue(true);
    StreamSubscription<List<int>> xSub =
        accService.characteristics[0].value.listen((value) {
      StoreProvider.of<AppState>(context).dispatch(
        SetAcceleroDataAction(
          StoreProvider.of<AppState>(context).state.acceleroDataState.copyWith(
                x: _decodeCharacteristics(value),
              ),
        ),
      );
    });

    setState(() {
      _xSub = xSub;
    });

    log("Finished init X characteristics");
    // Y
    await accService.characteristics[1].setNotifyValue(true);

    StreamSubscription<List<int>> ySub =
        accService.characteristics[1].value.listen((value) {
      int val = _decodeCharacteristics(value);
      _bufferAcceleroValue(val);
      StoreProvider.of<AppState>(context).dispatch(
        SetAcceleroDataAction(
          StoreProvider.of<AppState>(context)
              .state
              .acceleroDataState
              .copyWith(y: val),
        ),
      );
    });

    setState(() {
      _ySub = ySub;
    });

    log("Finished init X characteristics");
    // Z
    await accService.characteristics[2].setNotifyValue(true);
    StreamSubscription<List<int>> zSub =
        accService.characteristics[2].value.listen((value) {
      StoreProvider.of<AppState>(context).dispatch(
        SetAcceleroDataAction(
          StoreProvider.of<AppState>(context).state.acceleroDataState.copyWith(
                z: _decodeCharacteristics(value),
              ),
        ),
      );
    });

    setState(() {
      _zSub = zSub;
    });

    log("Finished init Z characteristics");
  }

  int _decodeCharacteristics(List<int> value) {
    if (value.isEmpty) return -1;
    value = value.sublist(0, value.length - 1);
    String decoded = String.fromCharCodes(value.where((v) => v != 0));
    int intVal = int.parse(decoded.replaceAll(" ", ""));
    return intVal;
  }

  Widget _render() {
    return Expanded(
      child: Column(
        children: [
          _renderConnectedDeviceLayout(),
          //_renderBlueToothDevicesAmount(),
          _renderButtonLayout(),
          Expanded(child: _buildListViewOfDevices())
        ],
      ),
    );
  }

  Widget _renderBlueToothDevicesAmount() {
    return Text("Discovered devices: ${_devicesList.length}");
  }

  Widget _renderScanButton() {
    return StoreConnector<AppState, BLEState>(
      converter: (store) => store.state.bluetoothState,
      builder: (context, state) {
        Color color = state.state != BluetoothState.on
            ? Colors.grey
            : _isScanning
                ? Colors.red
                : Colors.blue;
        VoidCallback? onPressed = state.state != BluetoothState.on
            ? null
            : _isScanning
                ? _stopScan
                : _asyncScan;
        String text = state.state != BluetoothState.on
            ? "BLE is off"
            : _isScanning
                ? "Stop Scan"
                : "Start Scan";
        IconData iconData = state.state != BluetoothState.on
            ? Icons.bluetooth_disabled
            : _isScanning
                ? Icons.sensors_off
                : Icons.sensors;
        return ElevatedButton.icon(
          icon: Icon(iconData),
          style: ElevatedButton.styleFrom(primary: color),
          onPressed: onPressed,
          label: Text(text),
        );
      },
    );
  }

  Widget _renderConnectedDeviceActionButtonsLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
              child: StoreConnector<AppState, BluetoothDevice?>(
                converter: (store) =>
                    store.state.bluetoothState.connectedDevice,
                builder: (context, device) {
                  VoidCallback? func =
                      device != null ? _manualDisconnect : null;

                  return SizedBox(
                    width: 140,
                    child: OutlinedButton(
                      style: ElevatedButton.styleFrom(onPrimary: Colors.red),
                      onPressed: func,
                      child: const Text("Detach"),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
              child: StoreConnector<AppState, BluetoothDevice?>(
                converter: (store) =>
                    store.state.bluetoothState.connectedDevice,
                builder: (context, device) {
                  VoidCallback? func = device != null && _xSub == null
                      ? _readCharacteristics
                      : null;

                  return SizedBox(
                    width: 140,
                    child: OutlinedButton(
                      style: ElevatedButton.styleFrom(onPrimary: Colors.green),
                      onPressed: func,
                      child: const Text("Read"),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
              child: StoreConnector<AppState, MusicSyncState>(
                converter: (store) => store.state.musicSyncState,
                builder: (context, state) {
                  Color color = state.status == MusicSyncStatus.Desync
                      ? Colors.green
                      : state.status == MusicSyncStatus.Sync
                          ? Colors.red
                          : Colors.grey;

                  String text = state.status == MusicSyncStatus.Desync
                      ? "Sync"
                      : state.status == MusicSyncStatus.Sync
                          ? "Desync"
                          : "Calibrate";

                  VoidCallback? func =
                      state.status == MusicSyncStatus.Desync && _xSub != null
                          ? _startSync
                          : state.status == MusicSyncStatus.Sync
                              ? _stopSync
                              : null;

                  return SizedBox(
                    width: 140,
                    child: OutlinedButton(
                      style: ElevatedButton.styleFrom(onPrimary: color),
                      onPressed: func,
                      child: Text(text),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderCharacteristicNorm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text("Norm: "),
          ),
          Expanded(
              child: Card(
            elevation: 0,
            color: const Color(0x55F44336),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
              child: Text(
                _calibration?[0].toString() ?? "-",
                textAlign: TextAlign.center,
              ),
            ),
          )),
          Expanded(
            child: Card(
              elevation: 0,
              color: const Color(0x554CAF50),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                child: Text(
                  _calibration?[1].toString() ?? "-",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            child: Card(
              elevation: 0,
              color: const Color(0x552196F3),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                child: Text(
                  _calibration?[2].toString() ?? "-",
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderCurrentSpeedMode() {
    return StoreConnector<AppState, SpeedModeState>(
      converter: (store) => store.state.speedModeState,
      builder: (context, state) {
        Color color = state.mode == SpeedMode.Fast
            ? Colors.red
            : state.mode == SpeedMode.Middle
                ? Colors.orange
                : Colors.lightGreen;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text("Speed Mode:"),
              ),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: color,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Text(
                      state.mode.toString().split(".").last.toUpperCase(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _renderCharacteristicReader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: StoreConnector<AppState, AcceleroDataState>(
        converter: (store) => store.state.acceleroDataState,
        builder: (context, state) {
          return Row(
            children: [
              const Expanded(
                child: Text("Data: "),
              ),
              Expanded(
                  child: Card(
                elevation: 0,
                color: const Color(0x55F44336),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  child: Text(
                    state.x.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              )),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: const Color(0x554CAF50),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Text(
                      state.y.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  elevation: 0,
                  color: const Color(0x552196F3),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Text(
                      state.z.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _renderConnectedDeviceLayout() {
    return StoreConnector<AppState, BLEState>(
      converter: (store) => store.state.bluetoothState,
      builder: (context, state) {
        String text = "No Connected Device";
        if (state.connectedDevice != null) {
          text = state.connectedDevice!.id.id;
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Card(
                color: const Color(0xff464347),
                child: IgnorePointer(
                  ignoring: state.connectedDevice == null,
                  child: ExpansionTile(
                    title: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        text,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    children: [
                      _renderConnectedDeviceActionButtonsLayout(),
                      _renderCharacteristicReader(),
                      _renderCharacteristicNorm(),
                      _renderCurrentSpeedMode(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _renderButtonLayout() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_renderScanButton()]);
  }

  void _tryConnect(BluetoothDevice device) async {
    try {
      StreamSubscription<BluetoothDeviceState>? connectedDeviceStateSub =
          device.state.listen(
        (deviceState) {
          log("Selected device state changed: [" +
              deviceState.toString() +
              "]");
          if (deviceState == BluetoothDeviceState.disconnected) {
            log("Selected device disconnected");
            _onDeviceDisconnect();
          }
        },
      );

      setState(() {
        _connectedDeviceStateSub = connectedDeviceStateSub;
      });

      await device.connect(
        timeout: const Duration(seconds: 5),
        autoConnect: false,
      );
      log("Connected ${device.name}");

      StoreProvider.of<AppState>(context).dispatch(
        SetBluetoothAction(
          StoreProvider.of<AppState>(context)
              .state
              .bluetoothState
              .copyWith(connectedDevice: device),
        ),
      );

      //_readCharacteristics();

      _stopScan();
    } catch (e) {
      log(e.toString());
    }
  }

  ListView _buildListViewOfDevices() {
    List<Padding> containers = [];
    for (BluetoothDevice device in _devicesList) {
      containers.add(
        Padding(
          padding: const EdgeInsets.all(10),
          child: Card(
            color: const Color(0xff464347),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        device.name == '' ? 'Unknown device' : device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        device.id.toString(),
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: ElevatedButton.styleFrom(onPrimary: Colors.green),
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                    onPressed: () async {
                      log("Start connecting ${device.name}");
                      _tryConnect(device);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        ...containers,
      ],
    );
  }

  @override
  Widget build(BuildContext context) => _render();
}

enum SpeedMode { Slow, Middle, Fast }
