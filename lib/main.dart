// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:peerconnection_client/call.dart';
import 'package:peerconnection_client/conductor.dart';
import 'package:peerconnection_client/login.dart';
import 'package:peerconnection_client/peer_list.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => Conductor(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peer connection sample',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter webrtc peerconnection client'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Conductor conductor = context.watch<Conductor>();
    UiConnectionState state = conductor.getUIConnectionState();
    if (state == UiConnectionState.loginUI) {
      return Login();
    } else if (state == UiConnectionState.peerListUI) {
      return PeerList();
    } else if (state == UiConnectionState.streamingUI) {
      return Call();
    } else {
      return PeerList();
    }
  }
}
