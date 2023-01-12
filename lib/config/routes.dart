import 'dart:developer';

import 'package:fluro/fluro.dart';
import 'package:flutter/cupertino.dart';
import './route_handlers.dart';

class Routes {
  static String root = '/';
  static String emulatorNes = '/emulator/nes';

  static void configureRoutes(FluroRouter router) {
    router.notFoundHandler = Handler(
        handlerFunc: (BuildContext? context, Map<String, List<String>> params) {
      log('$params ROUTE WAS NOT FOUND !!!');
      return;
    });
    router.define(root, handler: rootHandler);
    router.define(emulatorNes, handler: emulatorNesHandler);
  }
}
