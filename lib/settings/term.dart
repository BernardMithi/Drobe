import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'TERMS OF SERVICE',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Updated: March 24, 2024',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 24),

            _buildTermsSection(
              title: '1. ACCEPTANCE OF TERMS',
              content: 'By accessing or using the Outfit Planner application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.\n\nOutfit Planner reserves the right to modify these Terms at any time. Your continued use of the App after any such changes constitutes your acceptance of the new Terms.',
            ),

            _buildTermsSection(
              title: '2. USER ACCOUNTS',
              content: 'To use certain features of the App, you must register for an account. You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.\n\nYou agree to provide accurate and complete information when creating an account and to update your information to keep it accurate and complete. Outfit Planner reserves the right to suspend or terminate your account if any information provided is found to be inaccurate or incomplete.',
            ),

            _buildTermsSection(
              title: '3. USER CONTENT',
              content: 'The App allows you to upload, store, and share content, including images of clothing items and outfits ("User Content"). You retain all rights to your User Content, but you grant Outfit Planner a non-exclusive, transferable, sub-licensable, royalty-free, worldwide license to use, copy, modify, and display your User Content in connection with the operation of the App.\n\nYou represent and warrant that your User Content does not violate any third-party rights, including intellectual property rights and privacy rights, and that it complies with these Terms and all applicable laws.',
            ),

            _buildTermsSection(
              title: '4. PROHIBITED CONDUCT',
              content: 'You agree not to:\n• Use the App for any illegal purpose or in violation of any laws\n• Infringe on the rights of others, including privacy and intellectual property rights\n• Upload or share content that is harmful, abusive, or offensive\n• Attempt to gain unauthorized access to the App or its systems\n• Use the App to distribute malware or other harmful code\n• Interfere with or disrupt the operation of the App\n• Impersonate any person or entity',
            ),

            _buildTermsSection(
              title: '5. INTELLECTUAL PROPERTY',
              content: 'The App, including its design, features, content, and functionality, is owned by Outfit Planner and is protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, distribute, sell, or lease any part of the App without our prior written consent.',
            ),

            _buildTermsSection(
              title: '6. PRIVACY',
              content: 'Our Privacy Policy, available in the App, explains how we collect, use, and share your personal information. By using the App, you consent to our collection and use of your information as described in the Privacy Policy.',
            ),

            _buildTermsSection(
              title: '7. DISCLAIMER OF WARRANTIES',
              content: 'THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.',
            ),

            _buildTermsSection(
              title: '8. LIMITATION OF LIABILITY',
              content: 'TO THE MAXIMUM EXTENT PERMITTED BY LAW, OUTFIT PLANNER SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, GOODWILL, OR OTHER INTANGIBLE LOSSES, RESULTING FROM (A) YOUR ACCESS TO OR USE OF OR INABILITY TO ACCESS OR USE THE APP; (B) ANY CONDUCT OR CONTENT OF ANY THIRD PARTY ON THE APP; OR (C) UNAUTHORIZED ACCESS, USE, OR ALTERATION OF YOUR TRANSMISSIONS OR CONTENT.',
            ),

            _buildTermsSection(
              title: '9. TERMINATION',
              content: 'We may terminate or suspend your access to the App immediately, without prior notice or liability, for any reason whatsoever, including if you breach these Terms.\n\nUpon termination, your right to use the App will immediately cease. All provisions of these Terms which by their nature should survive termination shall survive termination, including, without limitation, ownership provisions, warranty disclaimers, indemnity, and limitations of liability.',
            ),

            _buildTermsSection(
              title: '10. CONTACT INFORMATION',
              content: 'If you have any questions about these Terms, please contact us at legal@outfitplanner.com.',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

