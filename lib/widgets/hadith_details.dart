import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/hadith_model.dart';
import '../providers/ahadith_details_provider.dart';
import '../providers/my_provider.dart';



class HadithDetails extends StatelessWidget {
  const HadithDetails({super.key, required this.arghadith});
  static const String routeName = 'HadithDetails';
  final HadithModel arghadith;
  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<MyProvider>(context);

    return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage(provider.getBackgroundImage()),
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.pinkAccent,

            title: Text('الأحاديث النبوية الشريفة',style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 25,
              color: Colors.white
            ),),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.mode == ThemeMode.light
                    ? const Color(0xFFF8F8F8).withOpacity(.8)
                    : const Color(0xFF141A2E),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    arghadith.title,
                    style:TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w400,
                        color: Colors.black
                    ),
                  ),
                  Divider(
                    indent: 50,
                    endIndent: 50,
                      color: Colors.black

                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text( arghadith.content[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.black
                              ),),
                        );
                      },
                      itemCount:arghadith.content.length,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),

    );
  }
}
