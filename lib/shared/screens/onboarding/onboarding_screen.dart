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
                padding: const EdgeInsets.symmetric(horizontal:3),
                child: SpinningVideoCard(),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.0001),
       

     
        SizedBox(height: 20,),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 1, vertical: 7),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Color(0xFF15161C),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                 Text('YOUR WALLET.\nYOUR KINGDOM.', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0,letterSpacing: 1.9), textAlign: TextAlign.center,),
                    SizedBox(height: 15,),
             Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFFF147),
                 padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onPressed: () => context.push(AppRoutes.createWallet), 
                child: Text(
                  'Create a wallet', 
                  style: TextStyle(
                    color: Colors.black, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w600)
                    ,)
                    ),          
            ),
            
                    ),
                    SizedBox(height: 7,),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF25262C),
                         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onPressed: () => context.push(AppRoutes.importWallet),
                        child: Text(
                          'I already have a Wallet', 
                          style: TextStyle(
                            color: Colors.white, 
                            fontSize: 16, 
                            fontWeight: FontWeight.w600)
                            ,)
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