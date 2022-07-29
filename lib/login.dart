import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'conductor.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() {
    return _LoginPageState();
  }
}

class _LoginPageState extends State<Login> {
  TextEditingController serverController =
      TextEditingController(text: '109.123.123.197');
  TextEditingController portController = TextEditingController(text: '8888');
  Conductor? conductor;
  void _connectOrDisconnect() async {
    debugPrint('IP is ${serverController.text}');
    debugPrint('Port is ${portController.text}');
    conductor!
        .startLogin(serverController.text, int.parse(portController.text));
  }

  @override
  void initState() {
    super.initState();
    serverController.addListener(() {
      debugPrint(serverController.text);
    });
    portController.addListener(() {
      debugPrint(portController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    conductor = context.watch<Conductor>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            TextField(
              autofocus: true,
              controller: serverController,
              decoration: const InputDecoration(
                  labelText: "Server", prefixIcon: Icon(Icons.tv)),
            ),
            TextField(
              autofocus: true,
              controller: portController,
              decoration: const InputDecoration(
                  labelText: "Port", prefixIcon: Icon(Icons.tv)),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _connectOrDisconnect,
        tooltip: 'Connect',
        child: const Icon(Icons.connected_tv),
      ),
    );
  }
}
