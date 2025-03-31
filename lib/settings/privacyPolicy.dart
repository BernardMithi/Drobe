import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'PRIVACY POLICY',
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
            // Last updated card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
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
                  const SizedBox(height: 16),
                  const Text(
                    'At Outfit Planner, we take your privacy seriously. This Privacy Policy explains how we collect, use, and share your personal information when you use our mobile application.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _buildPolicySection(
              title: '1. INFORMATION WE COLLECT',
              content: 'We collect the following types of information:\n\n• Account Information: When you create an account, we collect your email address, name, and password.\n\n• User Content: We collect and store the photos and information about clothing items and outfits that you upload to the App.\n\n• Usage Information: We collect information about how you use the App, including the features you access and the time spent on the App.\n\n• Device Information: We collect information about your device, including device type, operating system, and unique device identifiers.',
            ),

            _buildPolicySection(
              title: '2. HOW WE USE YOUR INFORMATION',
              content: 'We use your information for the following purposes:\n\n• To provide and maintain the App\n• To improve and personalize your experience\n• To communicate with you about the App\n• To develop new features and services\n• To prevent fraud and abuse\n• To comply with legal obligations',
            ),

            _buildPolicySection(
              title: '3. SHARING YOUR INFORMATION',
              content: 'We may share your information with the following parties:\n\n• Service Providers: We share information with third-party service providers that help us operate the App, such as cloud storage providers.\n\n• Business Transfers: If we are involved in a merger, acquisition, or sale of all or a portion of our assets, your information may be transferred as part of that transaction.\n\n• Legal Requirements: We may disclose your information if required to do so by law or in response to valid requests by public authorities.',
            ),

            _buildPolicySection(
              title: '4. DATA SECURITY',
              content: 'We implement appropriate technical and organizational measures to protect your personal information from unauthorized access, use, or disclosure. However, no method of electronic transmission or storage is 100% secure, and we cannot guarantee absolute security.',
            ),

            _buildPolicySection(
              title: '5. YOUR RIGHTS AND CHOICES',
              content: 'Depending on your location, you may have certain rights regarding your personal information, including:\n\n• Access: You can request access to the personal information we hold about you.\n\n• Correction: You can request that we correct inaccurate or incomplete information.\n\n• Deletion: You can request that we delete your personal information.\n\n• Objection: You can object to our processing of your personal information.\n\n• Data Portability: You can request a copy of your personal information in a structured, commonly used, and machine-readable format.',
            ),

            _buildPolicySection(
              title: '6. CHILDREN\'S PRIVACY',
              content: 'The App is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe that your child has provided us with personal information, please contact us.',
            ),

            _buildPolicySection(
              title: '7. CHANGES TO THIS PRIVACY POLICY',
              content: 'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date. You are advised to review this Privacy Policy periodically for any changes.',
            ),

            _buildPolicySection(
              title: '8. CONTACT US',
              content: 'If you have any questions about this Privacy Policy, please contact us at privacy@outfitplanner.com.',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({required String title, required String content}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 12),
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

