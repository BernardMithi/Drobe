import 'package:flutter/material.dart';
import 'contactUs.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _searchController = TextEditingController();
  final List<FAQItem> _faqItems = [
    FAQItem(
      question: 'How do I create a new outfit?',
      answer: 'To create a new outfit, tap the + button at the bottom of the Outfits screen. From there, you can select clothing items from your wardrobe and combine them into a new outfit. When you\'re done, give your outfit a name and save it.',
    ),
    FAQItem(
      question: 'How do I add items to my wardrobe?',
      answer: 'To add items to your wardrobe, go to the Wardrobe tab and tap the + button. You can take a photo of your item, upload an existing photo from your gallery, or manually add details. Fill in the information about your item such as category, color, and brand.',
    ),
    FAQItem(
      question: 'Can I share my outfits on social media?',
      answer: 'Yes! When viewing an outfit, tap the share icon to open sharing options. You can share your outfit to Instagram, Facebook, Pinterest or save it as an image to your device.',
    ),
    FAQItem(
      question: 'How do I plan outfits for future dates?',
      answer: 'On the Outfits screen, select the date navigation at the top to move to a future date. Then add an outfit for that specific day by tapping the + button.',
    ),
    FAQItem(
      question: 'How do I reset my password?',
      answer: 'If you forgot your password, go to the login screen and tap on "Forgot Password". Enter your email address and follow the instructions sent to your email to reset your password.',
    ),
    FAQItem(
      question: 'Is my data backed up?',
      answer: 'Yes, all your wardrobe items and outfits are automatically backed up to the cloud when you\'re connected to the internet. You can access your wardrobe from multiple devices using the same account.',
    ),
  ];

  List<FAQItem> _filteredFaqItems = [];

  @override
  void initState() {
    super.initState();
    _filteredFaqItems = _faqItems;
    _searchController.addListener(_filterFaqs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFaqs() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredFaqItems = _faqItems;
      });
    } else {
      setState(() {
        _filteredFaqItems = _faqItems
            .where((item) => item.question.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            item.answer.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'HELP CENTER',
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
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for help',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),


          // FAQ List
          Expanded(
            child: _filteredFaqItems.isEmpty
                ? const Center(
              child: Text(
                'No results found',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _filteredFaqItems.length,
              itemBuilder: (context, index) {
                return _buildFaqItem(_filteredFaqItems[index]);
              },
            ),
          ),

          // Contact Support
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContactUsPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'CONTACT SUPPORT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, IconData icon) {
    return Container(
      width: 120,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        child: InkWell(
          onTap: () {
            // Filter FAQs by category
          },
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqItem(FAQItem item) {
    return ExpansionTile(
      title: Text(
        item.question,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          item.answer,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            height: 2,
          ),
        ),
      ],
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({required this.question, required this.answer});
}

