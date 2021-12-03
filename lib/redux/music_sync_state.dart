class MusicSyncState {
  MusicSyncStatus status;

  MusicSyncState(this.status);
}

class SetMusicSyncAction {
  MusicSyncState data;

  SetMusicSyncAction(this.data);
}

enum MusicSyncStatus { Desync, Calibrate, Sync }
