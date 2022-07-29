import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:peerconnection_client/conductor.dart';
import 'package:provider/provider.dart';

class Call extends StatefulWidget {
  const Call({Key? key}) : super(key: key);
  @override
  State<StatefulWidget> createState() {
    return _CallState();
  }
}

class _CallState extends State<Call> implements PeerConnectionCallback {
  RTCVideoRenderer localRenderer_ = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer_ = RTCVideoRenderer();
  Conductor? conductor_;
  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  initRenderers() async {
    await localRenderer_.initialize();
    await remoteRenderer_.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    conductor_!.unregisterPeerConnectionCallback(this);
    localRenderer_.dispose();
    remoteRenderer_.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (conductor_ == null) {
      conductor_ = context.watch<Conductor>();
      conductor_!.registerPeerConnectionCallback(this);
      conductor_!.createConnection().then((value) {
        debugPrint('createConnection result == $value');
      });
    }
    return Scaffold(
        appBar: AppBar(
          title: const Text('Call'),
        ),
        body: OrientationBuilder(builder: (context, orientation) {
          return Stack(children: <Widget>[
            Positioned(
                left: 0.0,
                right: 0.0,
                top: 0.0,
                bottom: 0.0,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  decoration: const BoxDecoration(color: Colors.black54),
                  child: RTCVideoView(remoteRenderer_),
                )),
            Positioned(
              left: 20.0,
              top: 20.0,
              child: Container(
                width: orientation == Orientation.portrait ? 90.0 : 120.0,
                height: orientation == Orientation.portrait ? 120.0 : 90.0,
                decoration: const BoxDecoration(color: Colors.black54),
                child: RTCVideoView(localRenderer_, mirror: true),
              ),
            ),
          ]);
        }));
  }

  @override
  void onAddTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      remoteRenderer_.srcObject = stream;
    }
    setState(() {});
  }

  @override
  void onCandidate(RTCIceCandidate candidate) {}

  @override
  void onIceConnectionState(RTCIceConnectionState state) {}

  @override
  void onIceGatheringState(RTCIceGatheringState state) {}

  @override
  void onPeerConnectionState(RTCPeerConnectionState state) {}

  @override
  void onRemoveTrack(MediaStream stream, MediaStreamTrack track) {
    if (track.kind == 'video') {
      remoteRenderer_.srcObject = null;
    }
    setState(() {});
  }

  @override
  void onRenegotiationNeeded() {}

  @override
  void onSignalingState(RTCSignalingState state) {}

  @override
  void onTrack(RTCTrackEvent event) {
    if (event.track.kind == 'video') {
      remoteRenderer_.srcObject = event.streams[0];
    }
    setState(() {});
  }

  @override
  void onLocalStream(MediaStream stream) {
    localRenderer_.srcObject = stream;
    setState(() {});
  }
}
