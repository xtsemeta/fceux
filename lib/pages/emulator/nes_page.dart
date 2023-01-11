import 'package:flutter/material.dart';
import 'package:nes/nes.dart';

class NesPage extends StatefulWidget {
  const NesPage({super.key});

  @override
  State<NesPage> createState() => _NesPageState();
}

class _NesPageState extends State<NesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: const <Widget>[
          EmulatorPageWidget(),
        ],
      ),
    );
  }
}
