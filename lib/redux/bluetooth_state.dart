import 'package:flutter_blue/flutter_blue.dart';

class BLEState {
  BluetoothState state;
  BluetoothDevice? connectedDevice;

  BLEState(this.state, this.connectedDevice);

  BLEState copyWith({BluetoothState? state, BluetoothDevice? connectedDevice}) {
    return BLEState(
      state ?? this.state,
      connectedDevice ?? this.connectedDevice,
    );
  }
}

class SetBluetoothAction {
  BLEState data;

  SetBluetoothAction(this.data);
}
