import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quranapplication/screens/mainScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin
{@override
  void initState() {
    // TODO: implement initState
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    Future.delayed(Duration(seconds:10),(){
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_)=> MainScreen())
      );
    });
  }
  @override
  void dispose() {
    // TODO: implement dispose
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,overlays: SystemUiOverlay.values);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.pinkAccent,Colors.pinkAccent.shade200],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            CircleAvatar(
              radius: 150,
              backgroundImage: AssetImage("assets/1.jpg"),
            ),
            Text("طريق الجنة",style: TextStyle(
              color: Colors.white,
              fontSize:30,
              fontWeight: FontWeight.bold
            ),)
          ],
        ),
      ),
    );
  }
}
