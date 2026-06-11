import 'package:flutter/material.dart';
import 'package:drobe/models/fabricModel.dart';

class FabricTipDetailPage extends StatelessWidget {
  final FabricTip tip;

  const FabricTipDetailPage({Key? key, required this.tip}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF242424),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const BackButton(color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              title: Text(
                tip.title,
                style: const TextStyle(
                  fontFamily: 'BarlowCondensed',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(offset: Offset(0, 1), blurRadius: 6, color: Colors.black54),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    tip.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF2EEE8),
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 64, color: Color(0xFFBDB5AB)),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.72),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category tags
                  Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 6,
                    runSpacing: 6,
                    children: tip.categories.map((cat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDDDDD)),
                        ),
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontFamily: 'BarlowCondensed',
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  // Pull-quote description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      border: Border(
                        left: BorderSide(color: Color(0xFFAAAAAA), width: 3),
                      ),
                    ),
                    child: Text(
                      tip.description,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontFamily: 'BarlowCondensed',
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                        color: Color(0xFF555555),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Main article content
                  _buildFormattedContent(tip.content),

                  // Care instructions
                  if (tip.careInstructions.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('Care Guide'),
                    const SizedBox(height: 14),
                    ...tip.careInstructions.map(_buildCareItem),
                  ],

                  // Pro tips
                  if (tip.tips.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('Pro Tips'),
                    const SizedBox(height: 14),
                    ...tip.tips.asMap().entries.map((e) => _buildTipItem(e.value, e.key + 1)),
                  ],

                  // Related fabrics
                  if (tip.relatedFabrics.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _buildSectionHeader('Related Fabrics'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tip.relatedFabrics.map((fabric) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2EEE8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE4DDD5)),
                          ),
                          child: Text(
                            fabric,
                            style: const TextStyle(
                              fontFamily: 'BarlowCondensed',
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF5F5A54),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 28, height: 1.5, color: const Color(0xFFAD8B72)),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 1.8,
            color: Color(0xFF8A847D),
          ),
        ),
      ],
    );
  }

  Widget _buildCareItem(String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              color: Color(0xFFF2E8D8),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check, size: 13, color: Color(0xFF8A5E3C)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF4A4540)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String tipText, int number) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Color(0xFFF2E8D8),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF8A5E3C),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tipText,
                style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF4A4540)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedContent(String content) {
    final paragraphs = content.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        if (paragraph.trim().startsWith('###')) {
          return Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 10),
            child: Text(
              paragraph.trim().replaceAll('###', '').trim(),
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.4,
                color: Color(0xFF242424),
              ),
            ),
          );
        } else if (paragraph.trim().startsWith('**') && paragraph.trim().endsWith('**')) {
          return Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              paragraph.trim().replaceAll('**', '').trim(),
              style: const TextStyle(
                fontFamily: 'BarlowCondensed',
                fontSize: 19,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.3,
                color: Color(0xFF2C2626),
              ),
            ),
          );
        } else if (paragraph.trim().startsWith('-')) {
          final listItems = paragraph.split('\n').where((l) => l.trim().isNotEmpty).toList();
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: listItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 8, right: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFAD8B72),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.replaceFirst('-', '').trim(),
                          style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF4A4540)),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              paragraph.trim(),
              style: const TextStyle(fontSize: 15, height: 1.8, color: Color(0xFF4A4540)),
            ),
          );
        }
      }).toList(),
    );
  }
}
