class AcceleroDataState {
  int x;
  int y;
  int z;

  AcceleroDataState(this.x, this.y, this.z);

  AcceleroDataState copyWith({int? x, int? y, int? z}) {
    return AcceleroDataState(
      x = x ?? this.x,
      y = y ?? this.y,
      z = z ?? this.z,
    );
  }
}

class SetAcceleroDataAction {
  AcceleroDataState data;

  SetAcceleroDataAction(this.data);
}
