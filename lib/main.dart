import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'goole_map_page.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAz3gkvTVKwX6Yqbr--FEBau1Q7KPiNYE0",
        messagingSenderId: "789013470799",
        projectId: "budgetmemo-64d3c",
        appId: "1:789013470799:web:2c560d1ae8709980ba143a",
      )
  );

  runApp(

       MyApp(),

  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,

      home: const GGGG(),
    );
  }
}


