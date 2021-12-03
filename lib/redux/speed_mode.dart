import 'package:sd5509/components/bluetooth_connection.dart';

class SpeedModeState {
  SpeedMode mode;

  SpeedModeState(this.mode);
}

class SetSpeedModeAction {
  SpeedModeState data;

  SetSpeedModeAction(this.data);
}
