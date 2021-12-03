import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:redux/redux.dart';
import 'package:sd5509/components/bluetooth_connection.dart';
import 'package:sd5509/pages/main_page.dart';
import 'package:sd5509/redux/accelero_data.dart';
import 'package:sd5509/redux/app_state.dart';
import 'package:sd5509/redux/bluetooth_state.dart';
import 'package:sd5509/redux/music_state.dart';
import 'package:sd5509/redux/music_sync_state.dart';
import 'package:sd5509/redux/speed_mode.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
//import 'package:sd5509/music_player.dart';
//import 'package:sd5509/bluetooth_connection.dart';

Future<void> main() async {
  final store = Store<AppState>(
    appStateReducer,
    initialState: AppState(
      BLEState(BluetoothState.off, null),
      MusicState(null),
      AcceleroDataState(-1, -1, -1),
      MusicSyncState(MusicSyncStatus.Desync),
      SpeedModeState(SpeedMode.Slow),
    ),
  );

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
  runApp(FlutterReduxApp(
    key: const Key("sd5509"),
    title: 'Flutter Redux Demo',
    store: store,
  ));
}

class FlutterReduxApp extends StatelessWidget {
  final Store<AppState>? store;
  final String? title;

  FlutterReduxApp({Key? key, this.store, this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store!,
      child: MaterialApp(
        title: 'SD5509 Demo',
        home: Scaffold(
          body: SlidingUpPanel(
            backdropEnabled: true,
            backdropColor: Colors.black,
            borderRadius: BorderRadius.circular(30),
            color: const Color(0xff39363a),
            minHeight: 55,
            panel: Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 10),
                  Container(
                    width: 50,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xff464347),
                      borderRadius: BorderRadius.all(
                        Radius.circular(12.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StoreConnector<AppState, BLEState>(
                    converter: (store) => store.state.bluetoothState,
                    builder: (context, state) {
                      return Icon(
                        Icons.bluetooth,
                        color: state.state == BluetoothState.on
                            ? Colors.blue
                            : const Color(0xff464347),
                      );
                    },
                  ),
                  const SizedBox(height: 5),
                  const BluetoothConnection()
                ],
              ),
            ),
            body: const MainPage(),
          ),
        ),
        theme: ThemeData(
          fontFamily: "Quicksand",
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xff2c2a2d),
          primaryColor: Colors.grey,
          colorScheme: const ColorScheme.dark(
            primary: Colors.blue,
            onPrimary: Colors.white,
            secondary: Color(0xff6d686e),
          ),
          sliderTheme: const SliderThemeData(
            activeTrackColor: Colors.grey,
            thumbColor: Colors.grey,
          ),
        ),
      ),
    );
  }
}
