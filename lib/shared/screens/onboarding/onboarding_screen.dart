import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/shared/widgets/onboarding_video_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          //mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SpinningVideoCard(),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.03),
       

     
        SizedBox(height: 10,),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[900]?.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                 Text('YOUR WALLET.\nYOUR KINGDOM.', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0,letterSpacing: 1.9), textAlign: TextAlign.center,),
                    SizedBox(height: 15,),
             Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                 padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () => context.push(AppRoutes.createWallet), 
                child: Text(
                  'Get Started', 
                  style: TextStyle(
                    color: Colors.black, 
                    fontSize: 18, 
                    fontWeight: FontWeight.w600)
                    ,)
                    ),          
            ),
            
                    ),
                    SizedBox(height: 7,),
                    Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                 padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: (){}, 
                child: Text(
                  'I already have a Wallet', 
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 18, 
                    fontWeight: FontWeight.w600)
                    ,)
                    ),
                  ),
                    ),
            
              ],
            ),
          ),
        ),
         
          ],
        ),
      ),
    );
  }
}