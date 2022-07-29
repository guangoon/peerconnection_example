import 'package:flutter/material.dart';
import 'package:peerconnection_client/conductor.dart';
import 'package:provider/provider.dart';

class PeerList extends StatefulWidget {
  const PeerList({Key? key}) : super(key: key);

  @override
  State<PeerList> createState() {
    return _PeerListState();
  }
}

class _PeerListState extends State<PeerList> {
  @override
  Widget build(BuildContext context) {
    Conductor conductor = context.watch<Conductor>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Peer list'),
      ),
      body: ListView.builder(
          itemCount: conductor.getPeers().length,
          itemBuilder: (context, index) {
            return Card(
              child: ListTile(
                title: Text(conductor.getPeers()[index].name),
                onTap: () {
                  debugPrint('onTap  index : $index');
                  conductor.connectToPeer(conductor.getPeers()[index].peerId);
                },
              ),
            );
          }),
    );
  }
}
