import 'package:fc_flutter/pages/home_page.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';

var roothandler = Handler(
    handlerFunc: (BuildContext? context, Map<String, List<String>> parameters) {
  return HomePage();
});
