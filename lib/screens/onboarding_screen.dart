
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../model/pagevies.dart';
import 'homeScreenmain.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
   MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<previw> p = [
    previw(
        title: "اقرأ القرآن الكريم وتعلمه ",
        Subtitle: "سُر السعادة به ",
        image: "assets/5.jpg"),
    previw(
        title: "اقرأاحاديث الرسول صلي الله عليه وسلم  ",
        Subtitle: "اتبعها في اتباعها حياة",
        image: "assets/2.jpg"),
    previw(title: "أذكار ليطمئن قلبك ", Subtitle: "فلتحيا بحفظ الله ", image: "assets/4.jpg")
  ];

  PageController pageController = PageController(viewportFraction: 0.8, keepPage: true);

  int pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Scaffold(
            backgroundColor: Colors.blue.shade50,

            appBar: PreferredSize(
              preferredSize: Size(100, 60),
              child: AppBar(
                title: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('طريق الجنة',style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize:40
                  ),),
                ),
                backgroundColor: Colors.pinkAccent,
                centerTitle: true,

              ),
            ),
            body: PageView.builder(
              controller: pageController,
              physics: BouncingScrollPhysics(),
              itemBuilder: (context, index) =>
                  Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Center(
                  widthFactor: double.infinity,
                  child: Column(
                   // mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 500,
                    decoration:BoxDecoration(
                      borderRadius: BorderRadius.circular(100),

                    ),
                        clipBehavior:Clip.antiAliasWithSaveLayer ,
                        child: Image.asset(
                          '${p[index].image}',
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 10,),
                      Container(
                         width: double.infinity,
                        height: 150,
                        decoration:BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: Colors.blue.shade100.withOpacity(0.5)
                        ),
                        clipBehavior:Clip.antiAliasWithSaveLayer ,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            mainAxisAlignment:MainAxisAlignment.center,
                            children: [
                              Text(
                                "${p[index].title}",
                              textAlign:TextAlign.center,
                                style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pink.shade300),
                              ),
                              Text(
                                "${p[index].Subtitle}",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pinkAccent.shade100),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                           // SizedBox(width: 300,),
                            SmoothPageIndicator(
                                effect: SwapEffect(
                                    dotHeight: 10,
                                    dotWidth: 10,
                                    type: SwapType.yRotation,
                                    dotColor: Colors.grey,
                                    activeDotColor: Colors.pinkAccent),
                                controller: pageController,
                                count: 3),
                          ],
                        ),
                      ),
                     Container(
                       decoration:BoxDecoration(
                         borderRadius: BorderRadius.circular(100)
                       ) ,
                       clipBehavior: Clip.antiAliasWithSaveLayer,
                       child: MaterialButton(

                         onPressed: (){
                           Navigator.pushAndRemoveUntil(
                             context,
                             MaterialPageRoute(builder: (context) => MyHomePage()),
                                 (route) => false,);
                         },color: Colors.pinkAccent,child: Icon(Icons.home_rounded,color: Colors.blue.shade100,size: 40,),),
                     )
                    ],
                  ),
                ),
              ),
           itemCount: 3, )),
      ),
    );
  }
}
