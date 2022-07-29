import 'dart:core';
import 'dart:io';

import 'package:flutter/widgets.dart';

class ClientSocket {
  final String _ip;
  final int _port;
  Socket? _socket;
  ClientSocket(this._ip, this._port);

  Function? onSocketError;
  Function? onSocketDone;
  Function(Iterable<int> data)? onSocketData;

  Future<bool> connect() async {
    await Socket.connect(_ip, _port).then((Socket sock) {
      _socket = sock;
      _socket!.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: false);
    }).catchError((Object e) {
      debugPrint(e.toString());
    });
    return _socket != null;
  }

  void setCallback(void Function(Iterable<int> data)? onData, Function? onError,
      void Function()? onDone) {
    onSocketData = onData;
    onSocketError = onError;
    onSocketDone = onDone;
  }

  bool isConnected() {
    return _socket != null;
  }

  Future<void> disconnect() async {
    if (isConnected()) {
      await _socket!.close();
      _socket = null;
    }
  }

  void onDone() {
    onSocketDone!();
  }

  void onError(e) {
    onSocketError!(e);
  }

  void onData(Iterable<int> data) {
    onSocketData!(data);
  }

  Future<void> sendMessage(String message) async {
    _socket!.write(message);
    await _socket!.flush();
  }
}
