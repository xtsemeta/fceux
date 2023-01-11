import 'package:fc_flutter/pages/emulator/nes_page.dart';
import 'package:fc_flutter/pages/home_page.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';

var rootHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, List<String>> parameters) {
  return const HomePage();
});
var emulatorNesHandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, List<String>> parameters) {
  return const NesPage();
});
