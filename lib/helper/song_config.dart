import 'package:audiotagger/models/tag.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:sd5509/components/bluetooth_connection.dart';

class SongConfig {
  int index = -1;
  String path;
  SpeedMode speed;
  Tag? tag;
  bool played = false;

  setIndex(index) {
    this.index = index;
  }

  AudioSource getAudioSource() {
    return AudioSource.uri(
      Uri.file(path),
      tag: MediaItem(
        id: index.toString(),
        title: tag?.title ?? "Unknown song",
        artist: tag?.artist ?? "Unknown artist",
        album: tag?.album ?? "Unknown album",
      ),
    );
  }

  SongConfig(this.path, this.speed, this.tag);
}
