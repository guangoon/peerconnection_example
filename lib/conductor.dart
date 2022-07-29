import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerconnection_client/peer_connection_client.dart';

// Names used for a IceCandidate JSON object.
const String kCandidateSdpMidName = "sdpMid";
const String kCandidateSdpMlineIndexName = "sdpMLineIndex";
const String kCandidateSdpName = "candidate";

// Names used for a SessionDescription JSON object.
const String kSessionDescriptionTypeName = 'type';
const String kSessionDescriptionSdpName = 'sdp';

enum UiConnectionState {
  loginUI,
  peerListUI,
  streamingUI,
}

class Peer {
  String name;
  int peerId;
  bool connected;
  Peer(this.name, this.peerId, this.connected);

  @override
  String toString() {
    return 'name : $name, peerId : $peerId, connected : $connected';
  }
}

abstract class PeerConnectionCallback {
  void onSignalingState(RTCSignalingState state);
  void onIceGatheringState(RTCIceGatheringState state);
  void onIceConnectionState(RTCIceConnectionState state);
  void onPeerConnectionState(RTCPeerConnectionState state);
  void onCandidate(RTCIceCandidate candidate);
  void onRenegotiationNeeded();
  void onTrack(RTCTrackEvent event);
  void onAddTrack(MediaStream stream, MediaStreamTrack track);
  void onRemoveTrack(MediaStream stream, MediaStreamTrack track);
  void onLocalStream(MediaStream stream);
}

class Conductor extends ChangeNotifier
    implements PeerConnectionClientObserver, PeerConnectionCallback {
  PeerConnectionClient peerConnectionClient = PeerConnectionClient();
  UiConnectionState uiConnectionState = UiConnectionState.loginUI;
  int peerId_ = -1;
  List<Peer> peers = [];
  RTCPeerConnection? peerConnection_;
  MediaStream? localStream_;
  List<PeerConnectionCallback> peerConnectionCallbacks = [];
  JsonEncoder encoder_ = const JsonEncoder();
  JsonDecoder decoder_ = const JsonDecoder();

  Conductor() {
    peerConnectionClient.registerObserver(this);
  }

  void registerPeerConnectionCallback(PeerConnectionCallback callback) {
    peerConnectionCallbacks.add(callback);
  }

  void unregisterPeerConnectionCallback(PeerConnectionCallback callback) {
    peerConnectionCallbacks.remove(callback);
  }

  void startLogin(String server, int port) {
    debugPrint('startLogin server : $server, port : $port');
    peerConnectionClient.connect(server, port);
  }

  Future<void> connectToPeer(int peerId) async {
    debugPrint('connectToPeer, peerId : $peerId, peerId_ : $peerId_');
    if (peerId_ != -1) {
      debugPrint('peerId_ not -1, peerId_ : $peerId_');
      return;
    }

    if (peerId == -1) {
      debugPrint('peerId != -1, peerId : $peerId');
      return;
    }

    if (peerConnection_ != null) {
      debugPrint('We only support connecting to one peer at a time');
      return;
    }
    peerId_ = peerId;
    setUIConnectionState(UiConnectionState.streamingUI);
  }

  Future<bool> createConnection() async {
    bool ret = await initializePeerConnection();
    if (!ret) {
      debugPrint('initializePeerConnection fail');
      return false;
    }
    _createOffer();
    return true;
  }

  Future<bool> initializePeerConnection() async {
    Map<String, dynamic> iceServers = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };
    await createStream();
    peerConnection_ = await createPeerConnection({
      ...iceServers,
      ...{'sdpSemantics': 'unified-plan'}
    });

    if (peerConnection_ == null) {
      debugPrint('Create peer connection failed');
      return false;
    }
    localStream_!.getTracks().forEach((track) {
      peerConnection_!.addTrack(track, localStream_!);
    });
    peerConnection_!.onSignalingState = onSignalingState;
    peerConnection_!.onIceGatheringState = onIceGatheringState;
    peerConnection_!.onIceConnectionState = onIceConnectionState;
    peerConnection_!.onConnectionState = onPeerConnectionState;
    peerConnection_!.onIceCandidate = onCandidate;
    peerConnection_!.onRenegotiationNeeded = onRenegotiationNeeded;
    peerConnection_!.onTrack = onTrack;
    peerConnection_!.onAddTrack = onAddTrack;
    peerConnection_!.onRemoveTrack = onRemoveTrack;
    return true;
  }

  Future<void> _createOffer() async {
    try {
      RTCSessionDescription description =
          await peerConnection_!.createOffer({});
      await peerConnection_!.setLocalDescription(description);
      debugPrint('_createOffer::sdp-----begin');
      debugPrint(description.sdp);
      debugPrint('_createOffer::sdp-----end');
      var request = {};
      request[kSessionDescriptionTypeName] = description.type;
      request[kSessionDescriptionSdpName] = description.sdp;
      peerConnectionClient.sendToPeer(peerId_, encoder_.convert(request));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> createStream() async {
    Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };
    localStream_ = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream(localStream_!);
  }

  setUIConnectionState(UiConnectionState state) {
    uiConnectionState = state;
    notifyListeners();
  }

  UiConnectionState getUIConnectionState() {
    return uiConnectionState;
  }

  List<Peer> getPeers() {
    return peers;
  }

  @override
  void onDisconnected() {
    debugPrint('onDisconnected');
  }

  @override
  void onMessageFromPeer(int peerId, String message) {
    debugPrint('onMessageFromPeer---------------------------------begin');
    debugPrint(message);
    debugPrint('onMessageFromPeer-----------------------------------end');
    if (peerConnection_ == null) {
      peerId_ = peerId;
      initializePeerConnection().then((value) => {
            if (!value) {peerConnectionClient.signOut()}
          });
    } else if (peerId_ != peerId) {
      debugPrint(
          'Received a message from unknown peer while already in a conversation with a different peer.');
      return;
    }
    Map<String, dynamic> output = decoder_.convert(message);
    if (output.containsKey(kSessionDescriptionTypeName)) {
      String typeValue = output[kSessionDescriptionTypeName];
      debugPrint('typeValue == $typeValue');
      switch (typeValue) {
        case 'answer':
          peerConnection_!.setRemoteDescription(RTCSessionDescription(
              output[kSessionDescriptionSdpName],
              output[kSessionDescriptionTypeName]));
          break;
        case 'offer':
          break;
        default:
          break;
      }
    }
  }

  @override
  void onMessageSent(int err) {
    debugPrint('onMessageSent');
  }

  @override
  void onPeerConnected(int id, String name) {
    debugPrint('onPeerConnected id : $id, name : $name');
    peers.add(Peer(name, id, true));
    setUIConnectionState(UiConnectionState.peerListUI);
  }

  @override
  void onPeerDisconnected(int peerId) {
    debugPrint('onPeerDisconnected');
    peers.removeWhere((peer) => peer.peerId == peerId);
    setUIConnectionState(UiConnectionState.peerListUI);
  }

  @override
  void onServerConnectionFailure() {
    debugPrint('onServerConnectionFailure');
  }

  @override
  void onSignedIn() {
    debugPrint('onSignedIn');
    setUIConnectionState(UiConnectionState.peerListUI);
  }

  @override
  void onAddTrack(MediaStream stream, MediaStreamTrack track) {
    debugPrint('_onAddTrack');
    for (var element in peerConnectionCallbacks) {
      element.onAddTrack(stream, track);
    }
  }

  @override
  void onCandidate(RTCIceCandidate candidate) {
    debugPrint('onCandidate: ${candidate.candidate}');
    for (var element in peerConnectionCallbacks) {
      element.onCandidate(candidate);
    }
    //peerConnection_!.addCandidate(candidate);
    var request = {};
    request[kCandidateSdpMidName] = candidate.sdpMid;
    request[kCandidateSdpMlineIndexName] = candidate.sdpMLineIndex;
    request[kCandidateSdpName] = candidate.candidate;
    peerConnectionClient.sendToPeer(peerId_, jsonEncode(request));
  }

  @override
  void onIceConnectionState(RTCIceConnectionState state) {
    debugPrint('onIceConnectionState : $state');
    for (var element in peerConnectionCallbacks) {
      element.onIceConnectionState(state);
    }
  }

  @override
  void onIceGatheringState(RTCIceGatheringState state) {
    debugPrint('onIceGatheringState : $state');
    for (var element in peerConnectionCallbacks) {
      element.onIceGatheringState(state);
    }
  }

  @override
  void onPeerConnectionState(RTCPeerConnectionState state) {
    debugPrint('onPeerConnectionState : $state');
    for (var element in peerConnectionCallbacks) {
      element.onPeerConnectionState(state);
    }
  }

  @override
  void onRemoveTrack(MediaStream stream, MediaStreamTrack track) {
    debugPrint('onRemoveTrack');
    for (var element in peerConnectionCallbacks) {
      element.onRemoveTrack(stream, track);
    }
  }

  @override
  void onRenegotiationNeeded() {
    debugPrint('onRenegotiationNeeded');
    for (var element in peerConnectionCallbacks) {
      element.onRenegotiationNeeded();
    }
  }

  @override
  void onSignalingState(RTCSignalingState state) {
    debugPrint('onSignalingState : $state');
    for (var element in peerConnectionCallbacks) {
      element.onSignalingState(state);
    }
  }

  @override
  void onTrack(RTCTrackEvent event) {
    debugPrint('onTrack');
    for (var element in peerConnectionCallbacks) {
      element.onTrack(event);
    }
  }

  @override
  void onLocalStream(MediaStream stream) {
    debugPrint('onLocalStream');
    for (var element in peerConnectionCallbacks) {
      element.onLocalStream(stream);
    }
  }
}
