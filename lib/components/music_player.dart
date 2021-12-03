import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:audiotagger/audiotagger.dart';
import 'package:audiotagger/models/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sd5509/components/bluetooth_connection.dart';
import 'package:sd5509/components/music_player_common.dart';
import 'package:sd5509/helper/song_config.dart';
import 'package:sd5509/redux/app_state.dart';
import 'package:sd5509/redux/music_sync_state.dart';

class MusicPlayer extends StatefulWidget {
  @override
  _MusicPlayerState createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> with WidgetsBindingObserver {
  final _player = AudioPlayer();
  Tag? _currentTag;
  Uint8List? _currentArtwork;
  List<SongConfig> _songPlayList = <SongConfig>[];

  int _nextSongIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays speech.
    final tagger = Audiotagger();
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    // Init song list
    List<String> slowSpeedSongList =
        Directory("/storage/emulated/0/Music/sd5509/slow")
            .listSync()
            .whereType<File>()
            .map((e) => e.path)
            .toList();

    List<String> middleSpeedSongList =
        Directory("/storage/emulated/0/Music/sd5509/mid")
            .listSync()
            .whereType<File>()
            .map((e) => e.path)
            .toList();

    List<String> fastSpeedSongList =
        Directory("/storage/emulated/0/Music/sd5509/fast")
            .listSync()
            .whereType<File>()
            .map((e) => e.path)
            .toList();

    log(slowSpeedSongList.toString());

    List<SongConfig> slowConfig = await Future.wait(slowSpeedSongList
        .map((mp3) async =>
            SongConfig(mp3, SpeedMode.Slow, await tagger.readTags(path: mp3)))
        .toList());

    List<SongConfig> midConfig = await Future.wait(middleSpeedSongList
        .map((mp3) async =>
            SongConfig(mp3, SpeedMode.Middle, await tagger.readTags(path: mp3)))
        .toList());

    List<SongConfig> fastConfig = await Future.wait(fastSpeedSongList
        .map((mp3) async =>
            SongConfig(mp3, SpeedMode.Fast, await tagger.readTags(path: mp3)))
        .toList());

    setState(() {
      _songPlayList.addAll(slowConfig);
      _songPlayList.addAll(midConfig);
      _songPlayList.addAll(fastConfig);
    });

    for (var mp3 in _songPlayList) {
      mp3.setIndex(_songPlayList.indexOf(mp3));
    }

    // Listen to streams.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      log('A stream error occurred: $e');
    });

    _player.playerStateStream.listen((event) async {
      if (event.playing) {
        if (event.processingState == ProcessingState.completed) {
          log((_currentTag?.title ?? "Unknown song") + " finished");
          await Future.delayed(const Duration(microseconds: 500));
          await _nextSong(tagger);
          //_player.play();
        }
      }
    });

    _player.currentIndexStream.listen((newIndex) async {
      if (newIndex == null) return;

      Uint8List? bytes =
          await tagger.readArtwork(path: _songPlayList[newIndex].path);

      setState(() {
        _currentTag = _songPlayList[newIndex].tag;
        _currentArtwork = bytes;
      });
    });

    // Try to load audio from a source and catch any errors.
    try {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }

      _player.setAudioSource(_songPlayList[0].getAudioSource());
    } catch (e) {
      log("Error loading audio source: $e");
    }
  }

  Future<int> _nextSong(tagger) async {
    if (StoreProvider.of<AppState>(context).state.musicSyncState.status !=
        MusicSyncStatus.Sync) return -1;

    // Determine speed
    SpeedMode currentSpeedMode =
        StoreProvider.of<AppState>(context).state.speedModeState.mode;

    // Get all songs from current speed list
    List<SongConfig> currentSpeedSongConfig =
        _songPlayList.where((song) => song.speed == currentSpeedMode).toList();

    // Reset the play list if all current speed song is played
    if (currentSpeedSongConfig.where((song) => !song.played).isEmpty) {
      for (var song in currentSpeedSongConfig) {
        song.played = false;
      }
    }

    // Random pick one
    List<SongConfig> randomList =
        currentSpeedSongConfig.where((song) => !song.played).toList();
    randomList.shuffle();
    SongConfig chosenSong = randomList.first;
    chosenSong.played = true;

    setState(() {
      _nextSongIndex = chosenSong.index;
    });

    Uint8List? bytes =
        await tagger.readArtwork(path: _songPlayList[chosenSong.index].path);

    setState(() {
      _currentTag = _songPlayList[chosenSong.index].tag;
      _currentArtwork = bytes;
    });

    await _player.setAudioSource(chosenSong.getAudioSource());
    // log summary
    log("Next song: ${chosenSong.tag?.title ?? "Unknown Song"} | Speed: ${chosenSong.speed}");

    return chosenSong.index;
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // if (state == AppLifecycleState.paused) {
    //   // Release the player's resources when not in use. We use "stop" so that
    //   // if the app resumes later, it will still remember what position to
    //   // resume from.
    //   _player.stop();
    // }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  Widget _renderSongMetadata() => SizedBox(
        height: 550,
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _currentTag?.title ?? "Unknown song",
                style: const TextStyle(
                  fontFamilyFallback: ['Jinxuan'],
                  fontSize: 22,
                ),
              ),
              Text(
                _currentTag?.artist ?? "Unknown artist",
                style: const TextStyle(
                    fontFamilyFallback: ['Jinxuan'],
                    fontSize: 16,
                    color: Colors.grey),
              ),
            ],
          ),
        ),
      );

  Image _renderSongArtwork() => _currentArtwork != null
      ? Image.memory(
          _currentArtwork!,
          width: 300,
          height: 300,
        )
      : Image.asset("assets/imgs/mp3.png");

  Widget _renderArtworkContainer() {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: _renderSongArtwork().image,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _renderArtworkGradient() {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: FractionalOffset.topCenter,
          end: FractionalOffset.bottomCenter,
          colors: [
            Colors.grey.withOpacity(0.0),
            const Color(0xff2c2a2d),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _renderSeeker() {
    return SizedBox(
      width: 320,
      child: StreamBuilder<PositionData>(
        stream: _positionDataStream,
        builder: (context, snapshot) {
          final positionData = snapshot.data;
          return SeekBar(
            duration: positionData?.duration ?? Duration.zero,
            position: positionData?.position ?? Duration.zero,
            bufferedPosition: positionData?.bufferedPosition ?? Duration.zero,
            onChangeEnd: _player.seek,
          );
        },
      ),
    );
  }

  Widget _renderActionSection() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _renderSeeker(),
            ControlButtons(_player),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Stack(children: [
            _renderArtworkContainer(),
            _renderArtworkGradient(),
            _renderSongMetadata(),
          ]),
          _renderActionSection(),
        ],
      ),
    );
  }
}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  ControlButtons(this.player);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opens volume slider dialog
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () {
            showSliderDialog(
              context: context,
              title: "Adjust volume",
              divisions: 10,
              min: 0.0,
              max: 1.0,
              value: player.volume,
              stream: player.volumeStream,
              onChanged: player.setVolume,
            );
          },
        ),

        /// This StreamBuilder rebuilds whenever the player state changes, which
        /// includes the playing/paused state and also the
        /// loading/buffering/ready state. Depending on the state we show the
        /// appropriate button or loading indicator.
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing;
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return Container(
                margin: const EdgeInsets.all(8.0),
                width: 64.0,
                height: 64.0,
                child: const CircularProgressIndicator(),
              );
            } else if (playing != true) {
              return IconButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: player.play,
              );
            } else if (processingState != ProcessingState.completed) {
              return IconButton(
                icon: const Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: player.pause,
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 64.0,
                onPressed: () => player.seek(Duration.zero),
              );
            }
          },
        ),
        // Opens speed slider dialog
        StreamBuilder<double>(
          stream: player.speedStream,
          builder: (context, snapshot) => IconButton(
            icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              showSliderDialog(
                context: context,
                title: "Adjust speed",
                divisions: 10,
                min: 0.5,
                max: 1.5,
                value: player.speed,
                stream: player.speedStream,
                onChanged: player.setSpeed,
              );
            },
          ),
        ),
      ],
    );
  }
}
