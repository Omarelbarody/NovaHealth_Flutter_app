import 'package:flutter/material.dart';
import 'package:NovaHealth/features/hospitals/presentation/widgets/hospital_page_body.dart';

class HospitalPageView extends StatelessWidget {
  const HospitalPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hospitals',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const HospitalPageBody(),
    );
  }
} 