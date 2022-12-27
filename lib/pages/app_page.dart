import 'package:fc_flutter/config/application.dart';
import 'package:fluro/fluro.dart';
import 'package:flutter/material.dart';

import '../config/routes.dart';

class AppPage extends StatefulWidget {
  const AppPage({super.key});

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  _AppPageState() {
    final router = FluroRouter();
    Routes.configureRoutes(router);
    Application.router = router;
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'EmulatorDemo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      onGenerateRoute: Application.router.generator,
      initialRoute: '/',
    );
    return app;
  }
}
