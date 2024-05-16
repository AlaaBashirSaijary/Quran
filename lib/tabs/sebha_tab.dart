import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/my_provider.dart';

class SebhaTab extends StatefulWidget {
  const SebhaTab({super.key});

  @override
  State<SebhaTab> createState() => _SebhaTabState();
}

class _SebhaTabState extends State<SebhaTab> {
  int counter = 1;
  int index = 0;
  List<String> azkar = [
    'سبحان الله',
    'الحمد لله',
    'لا اله الا الله',
    'الله اكبر',
    'استغفر الله'
  ];

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);

    return Scaffold(

      backgroundColor: Colors.blue.shade50,
      body: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                counter++;
                if (counter == 34) {
                  index++;
                  counter = 1;

                  if (index == azkar.length) {
                    index = 0;
                  }
                }
                setState(() {});
              },
              child: Image.asset(
                  'assets/ic_sebha_top.png'
                  ),
            ),
            const SizedBox(height: 40),
            Text(
              'عدد التسبيحات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 30,
                color: Colors.pinkAccent
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: 69,
              height: 81,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color:   Colors.pinkAccent.shade100,
              ),
              child: Center(
                child: Text(
                  '$counter',
                  style: TextStyle(
                   fontSize: 20,
                   color: Colors.white,
                   fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 137,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color:Colors.pinkAccent
              ),
              child: Center(
                child: Text(
                  azkar[index],
                  style: TextStyle(
                    fontSize: 20,
                    color:
                         Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
