import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/hadith_model.dart';
import '../widgets/hadith_details.dart';
import '../providers/ahadith_details_provider.dart';
import '../providers/my_provider.dart';

class AhadithTab extends StatefulWidget {
  const AhadithTab({super.key});

  @override
  State<AhadithTab> createState() => _AhadithTabState();
}

class _AhadithTabState extends State<AhadithTab> {
  @override
  Widget build(BuildContext context) {

    return ChangeNotifierProvider<AhadithDetailsProvider>(
      create: (context) => AhadithDetailsProvider()..loadHadithFile(),
      builder: (context, child) {
        var provider = Provider.of<AhadithDetailsProvider>(context);
        var providerC = Provider.of<MyProvider>(context);

        return Scaffold(
          backgroundColor: Colors.blue.shade50,
          body: Column(
            children: [
              Image.asset('assets/ic_hadith_top.png'),
              Divider(
                thickness: 3,
                color: Colors.pinkAccent
              ),
              Text(
               "الأحاديث النبوية الشريفة",
                style:TextStyle(
                  color: Colors.pink,
                  fontSize: 20,
                  fontWeight: FontWeight.bold
                ),
                textAlign: TextAlign.center,
              ),
              Divider(
                thickness: 3,
                color: Colors.pinkAccent
              ),
              Expanded(
                  child: ListView.separated(
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HadithDetails(arghadith: HadithModel(title: provider.ahadithData[index].title,content: provider.ahadithData[index].content)),
                            ),

                          );
                          print(provider.ahadithData[index].title);
                          print(provider.ahadithData[index].content);
                          print(provider.ahadithData[3].title);
                          print(provider.ahadithData[3].content);
                        },
                        child: Text(provider.ahadithData[index].title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium),
                      );
                    },
                    itemCount: provider.ahadithData.length,
                  ))
            ],
          ),
        );
      },
    );
  }
}
