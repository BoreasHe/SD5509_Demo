import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:sd5509/components/music_player.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key key = const Key("main_page")}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    log("Start Init.");
    super.initState();

    //_asyncScan();
  }

  Widget _render() {
    return MusicPlayer();
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: _render());
}
