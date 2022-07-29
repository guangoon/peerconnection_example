import 'package:flutter/widgets.dart';
import 'package:peerconnection_client/client_socket.dart';

enum PeerconnectionState {
  notConnected,
  resolving,
  sigingIn,
  connected,
  sigingOutWaiting,
  sigingOut,
}

abstract class PeerConnectionClientObserver {
  void onSignedIn();
  void onDisconnected();
  void onPeerConnected(int id, String name);
  void onPeerDisconnected(int peerId);
  void onMessageFromPeer(int peerId, String message);
  void onMessageSent(int err);
  void onServerConnectionFailure();
}

class PeerConnectionClient {
  ClientSocket? _controlScoket;
  ClientSocket? _hangingSocket;
  int myId = -1;
  String? _server;
  int? _port;
  PeerConnectionClientObserver? callback;
  PeerconnectionState state = PeerconnectionState.notConnected;
  Map<int, String> peers = <int, String>{};

  Future<bool> connectControlSocket() async {
    debugPrint('connectControlSocket');
    return await _controlScoket!.connect();
  }

  void registerObserver(
      PeerConnectionClientObserver peerConnectionClientObserver) {
    callback = peerConnectionClientObserver;
  }

  Future<bool> connectHangingScoket() async {
    debugPrint('connectHangingScoket');
    return _hangingSocket!.connect();
  }

  void connect(String server, int port) {
    debugPrint('connect server : $server, port : $port');
    _server = server;
    _port = port;
    doConnect();
  }

  void onControlSocketDone() {
    debugPrint('onControlSocketDone');
  }

  void onControlSocketError(e) {
    debugPrint('onControlSocketError');
  }

  Future<void> onControlData(Iterable<int> data) async {
    String response = String.fromCharCodes(data);
    debugPrint('onControlData----------------------- response begin');
    debugPrint(response);
    debugPrint('onControlData----------------------- response end');

    if (_getResponseConnection(response) == 'close') {
      _controlScoket!.disconnect();
      onClose(_controlScoket!, 0);
    }
    bool ok = _getResponseStatus(response) == 200 ? true : false;
    if (ok) {
      if (myId == -1) {
        if (state != PeerconnectionState.sigingIn) {
          debugPrint(
              'state : $state, it should = PeerconnectionState.sigingIn');
        }
        myId = _getResponsePeerId(response);

        if (myId != -1) {
          debugPrint('myId : $myId, it should not  = -1');
        }
        _getResponsePeers(response);
        debugPrint('isConnected : ${isConnected()}');
        callback!.onSignedIn();
      } else if (state == PeerconnectionState.sigingOut) {
        close();
        callback!.onDisconnected();
      } else if (state == PeerconnectionState.sigingOutWaiting) {
        signOut();
      }
    }
    if (state == PeerconnectionState.sigingIn) {
      state = PeerconnectionState.connected;

      bool ret = await connectHangingScoket();

      if (ret) {
        _hangingSocket!
            .sendMessage('GET /wait?peer_id=$myId HTTP/1.0\r\n\r\n"');
      } else {
        debugPrint('Fail to connect to _hangingSocket scoket');
      }
    }
  }

  int _getResponseStatus(String response) {
    int index = response.indexOf(' ');
    String status = response.substring(index + 1, index + 4);
    return int.parse(status);
  }

  int _getResponsePeerId(String response) {
    int peerId = -1;
    if (_getResponseStatus(response) != 200) {
      return peerId;
    }
    int start = response.indexOf('Pragma: ');
    int end = response.substring(start).indexOf('\r\n');
    return int.parse(
        response.substring(start + 'Pragma: '.length, start + end));
  }

  int _getResponseContentLength(String response) {
    int contentLength = -1;
    if (_getResponseStatus(response) != 200) {
      return contentLength;
    }
    int start = response.indexOf('Content-Length: ');
    int end = response.substring(start).indexOf('\r\n');
    return int.parse(
        response.substring(start + 'Content-Length: '.length, start + end));
  }

  String _getResponseConnection(String response) {
    String connection = "";
    if (_getResponseStatus(response) != 200) {
      return connection;
    }
    int start = response.indexOf('Connection: ');
    int end = response.substring(start).indexOf('\r\n');
    return response.substring(start + 'Connection: '.length, start + end);
  }

  void _getResponsePeers(String response) {
    if (_getResponseStatus(response) != 200) {
      return;
    }
    int contentLength = _getResponseContentLength(response);

    if (contentLength <= 0) {
      debugPrint('contentLength <= 0');
      return;
    }
    int eoh = response.indexOf('\r\n\r\n');
    int pos = eoh + 4;
    while (pos < response.length) {
      int eol = response.indexOf('\n', pos);
      if (eol == -1) {
        break;
      }
      List<String> peerEntry = response.substring(pos, eol).split(',');
      if (int.parse(peerEntry[1]) != myId) {
        peers[int.parse(peerEntry[1])] = peerEntry[0];
        callback!.onPeerConnected(int.parse(peerEntry[1]), peerEntry[0]);
      }
      pos = eol + 1;
    }
  }

  void onHangingSocketDone() {
    debugPrint('onHangingSocketDone');
  }

  void onHangingSocketError(e) {
    debugPrint('onHangingSocketError');
  }

  void onHangingData(Iterable<int> data) {
    String response = String.fromCharCodes(data);
    debugPrint('onHangingData--------------------------------- response begin');
    debugPrint(response);
    debugPrint('onHangingData--------------------------------- response end');
    if (_getResponseConnection(response) == 'close') {
      _hangingSocket!.disconnect();
      onClose(_hangingSocket!, 0);
    }

    bool ok = _getResponseStatus(response) == 200 ? true : false;

    if (ok) {
      int peerId = _getResponsePeerId(response);
      int contentLength = _getResponseContentLength(response);
      if (contentLength <= 0) {
        debugPrint('contentLength <= 0');
        return;
      }
      int eoh = response.indexOf('\r\n\r\n');
      int pos = eoh + 4;
      if (peerId == myId) {
        int eol = response.indexOf('\n', pos);
        List<String> peerEntry = response.substring(pos, eol).split(',');
        bool connected = peerEntry[2] == '1' ? true : false;
        int id = int.parse(peerEntry[1]);
        String name = peerEntry[0];
        if (connected) {
          peers[id] = name;
          callback!.onPeerConnected(id, name);
        } else {
          peers.remove(id);
          callback!.onPeerDisconnected(id);
        }
      } else {
        onMessageFromPeer(peerId, response.substring(pos));
      }
    }
  }

  void onMessageFromPeer(int peerId, String message) {
    if (message == "BYE") {
      callback!.onPeerDisconnected(peerId);
    } else {
      callback!.onMessageFromPeer(peerId, message);
    }
  }

  void doConnect() async {
    debugPrint('doConnect');
    _controlScoket = ClientSocket(_server!, _port!);
    _hangingSocket = ClientSocket(_server!, _port!);

    _controlScoket!
        .setCallback(onControlData, onControlSocketError, onControlSocketDone);
    _hangingSocket!
        .setCallback(onHangingData, onHangingSocketError, onHangingSocketDone);

    bool ret = await connectControlSocket();

    if (ret) {
      state = PeerconnectionState.sigingIn;
      _controlScoket!.sendMessage("GET /sign_in?root@Tizen HTTP/1.0\r\n\r\n");
    } else {
      debugPrint('Fail to connect to control scoket');
    }
  }

  bool isConnected() {
    return myId != -1;
  }

  void onClose(ClientSocket socket, int err) async {
    await socket.disconnect();
    if (_hangingSocket == socket) {
      if (state == PeerconnectionState.connected) {
        await connectHangingScoket();
      }
    } else {
      callback!.onMessageSent(err);
    }
  }

  void close() {
    _hangingSocket!.disconnect();
    _controlScoket!.disconnect();
    myId = -1;
    state = PeerconnectionState.notConnected;
  }

  bool signOut() {
    if (state == PeerconnectionState.notConnected ||
        state == PeerconnectionState.sigingOut) {
      return true;
    }
    if (_hangingSocket!.isConnected()) {
      _hangingSocket!.disconnect();
    }
    if (_controlScoket!.isConnected()) {
      state = PeerconnectionState.sigingOut;
      if (myId != -1) {
        _controlScoket!
            .sendMessage("GET /sign_out?peer_id=$myId HTTP/1.0\r\n\r\n");
        return true;
      }
    }
    return true;
  }

  Future<bool> sendToPeer(int peerId, String message) async {
    if (state != PeerconnectionState.connected) {
      debugPrint('sendToPeer fail, state : $state');
      return false;
    }
    if (!isConnected() || peerId == -1) {
      debugPrint(
          'sendToPeer fail, isConnected : ${isConnected()}, peerId  : $peerId');
      return false;
    }
    if (_controlScoket!.isConnected()) {
      debugPrint('sendToPeer fail, _controlScoket is connected');
      return false;
    }
    bool ret = await _controlScoket!.connect();
    if (ret) {
      String sendData =
          'POST /message?peer_id=$myId&to=$peerId HTTP/1.0\r\nContent-Length: ${message.length}\r\nContent-Type: text/plain\r\n\r\n';
      sendData += message;
      debugPrint('sendToPeer------------------------------------------begin');
      debugPrint(sendData);
      debugPrint('sendToPeer--------------------------------------------end');
      _controlScoket!.sendMessage(sendData);
      return true;
    } else {
      return false;
    }
  }
}
