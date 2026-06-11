String canonicalItemCategory(String value) {
  final category = value.trim().toLowerCase();

  if (category.contains('bottom') ||
      category.contains('pant') ||
      category.contains('trouser') ||
      category.contains('short')) {
    return 'bottoms';
  }

  if (category.contains('shirt') ||
      category.contains('tee') ||
      category.contains('top') ||
      category.contains('polo')) {
    return 'shirts';
  }

  if (category.contains('shoe') ||
      category.contains('trainer') ||
      category.contains('sneaker') ||
      category.contains('boot') ||
      category.contains('clog') ||
      category.contains('loafer')) {
    return 'shoes';
  }

  if (category.contains('accessor') ||
      category.contains('watch') ||
      category.contains('cap') ||
      category.contains('hat') ||
      category.contains('sock')) {
    return 'accessories';
  }

  if (category.contains('layer') ||
      category.contains('jacket') ||
      category.contains('coat') ||
      category.contains('outer') ||
      category.contains('knit')) {
    return 'layers';
  }

  switch (category) {
    case 'layer':
      return 'layers';
    case 'shirt':
      return 'shirts';
    case 'bottom':
      return 'bottoms';
    case 'shoe':
      return 'shoes';
    case 'accessory':
      return 'accessories';
    default:
      return category;
  }
}

String wardrobeCategoryKey(String value) {
  switch (canonicalItemCategory(value)) {
    case 'layers':
      return 'LAYERS';
    case 'shirts':
      return 'SHIRTS';
    case 'bottoms':
      return 'BOTTOMS';
    case 'shoes':
      return 'SHOES';
    case 'accessories':
      return 'ACCESSORIES';
    default:
      return value.trim().toUpperCase();
  }
}

String? outfitSlotKey(String value) {
  switch (canonicalItemCategory(value)) {
    case 'layers':
      return 'LAYER';
    case 'shirts':
      return 'SHIRT';
    case 'bottoms':
      return 'BOTTOMS';
    case 'shoes':
      return 'SHOES';
    default:
      return null;
  }
}

bool categoriesMatch(String slotOrCategory, String itemCategory) {
  return canonicalItemCategory(slotOrCategory) ==
      canonicalItemCategory(itemCategory);
}

String? getOutfitClothingBySlot(
  Map<String, String?> clothes,
  String slot,
) {
  final direct = clothes[slot];
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }

  final target = canonicalItemCategory(slot);
  for (final entry in clothes.entries) {
    final value = entry.value;
    if (value != null &&
        value.isNotEmpty &&
        canonicalItemCategory(entry.key) == target) {
      return value;
    }
  }

  return null;
}

Map<String, String?> normalizeOutfitClothes(Map<String, String?> clothes) {
  final normalized = <String, String?>{
    'LAYER': null,
    'SHIRT': null,
    'BOTTOMS': null,
    'SHOES': null,
  };

  for (final entry in clothes.entries) {
    final key = outfitSlotKey(entry.key);
    if (key != null && entry.value != null && entry.value!.isNotEmpty) {
      normalized[key] = entry.value;
    }
  }

  return normalized;
}
