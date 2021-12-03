import 'package:sd5509/redux/accelero_data.dart';
import 'package:sd5509/redux/bluetooth_state.dart';
import 'package:sd5509/redux/music_state.dart';
import 'package:sd5509/redux/music_sync_state.dart';
import 'package:sd5509/redux/speed_mode.dart';

class AppState {
  BLEState bluetoothState;
  MusicState musicState;
  AcceleroDataState acceleroDataState;
  MusicSyncState musicSyncState;
  SpeedModeState speedModeState;

  AppState(this.bluetoothState, this.musicState, this.acceleroDataState,
      this.musicSyncState, this.speedModeState);

  AppState copyWith(
      {BLEState? bluetoothState,
      MusicState? musicState,
      AcceleroDataState? acceleroDataState,
      MusicSyncState? musicSyncState,
      SpeedModeState? speedModeState}) {
    return AppState(
        bluetoothState ?? this.bluetoothState,
        musicState ?? this.musicState,
        acceleroDataState ?? this.acceleroDataState,
        musicSyncState ?? this.musicSyncState,
        speedModeState ?? this.speedModeState);
  }
}

AppState appStateReducer(AppState prevState, dynamic action) {
  if (action is SetAcceleroDataAction) {
    return prevState.copyWith(acceleroDataState: action.data);
  } else if (action is SetMusicAction) {
    return prevState.copyWith(musicState: action.data);
  } else if (action is SetBluetoothAction) {
    return prevState.copyWith(bluetoothState: action.data);
  } else if (action is SetMusicSyncAction) {
    return prevState.copyWith(musicSyncState: action.data);
  } else if (action is SetSpeedModeAction) {
    return prevState.copyWith(speedModeState: action.data);
  } else {
    return prevState;
  }
}
