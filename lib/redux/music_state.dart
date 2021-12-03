import 'package:audiotagger/models/tag.dart';

class MusicState {
  Tag? tag;

  MusicState(this.tag);
}

class SetMusicAction {
  MusicState data;

  SetMusicAction(this.data);
}
