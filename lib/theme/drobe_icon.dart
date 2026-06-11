import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum DrobeIconName {
  account,
  add,
  addImage,
  arrowBack,
  arrowForward,
  camera,
  check,
  chevronLeft,
  chevronRight,
  close,
  delete,
  edit,
  email,
  fabricTips,
  image,
  info,
  laundry,
  link,
  lock,
  lookbook,
  outfit,
  palette,
  search,
  settings,
  sparkle,
  wardrobe,
}

const Map<DrobeIconName, String> _streamlineIconAssets = {
  DrobeIconName.account: 'account-circle',
  DrobeIconName.add: 'add',
  DrobeIconName.addImage: 'image-add',
  DrobeIconName.arrowBack: 'arrow-left',
  DrobeIconName.arrowForward: 'arrow-right',
  DrobeIconName.camera: 'camera',
  DrobeIconName.check: 'check',
  DrobeIconName.chevronLeft: 'chevron-left',
  DrobeIconName.chevronRight: 'chevron-right',
  DrobeIconName.close: 'close',
  DrobeIconName.delete: 'delete',
  DrobeIconName.edit: 'pencil',
  DrobeIconName.email: 'mail',
  DrobeIconName.image: 'image',
  DrobeIconName.info: 'information-circle',
  DrobeIconName.laundry: 'laundry-machine',
  DrobeIconName.link: 'link',
  DrobeIconName.lock: 'lock',
  DrobeIconName.lookbook: 'bookmarks-2',
  DrobeIconName.outfit: 'clothes-hanger',
  DrobeIconName.palette: 'color-palette',
  DrobeIconName.search: 'search',
  DrobeIconName.settings: 'settings',
  DrobeIconName.sparkle: 'sparkles',
  DrobeIconName.wardrobe: 'wardrobe',
};

const Map<DrobeIconName, String> _streamlinePngIconAssets = {
  DrobeIconName.add: 'assets/icons/streamline/Add--Streamline-Ultimate.png',
  DrobeIconName.edit: 'assets/icons/streamline/Pencil--Streamline-Ultimate.png',
  DrobeIconName.fabricTips: 'assets/icons/streamline/Fabric Tipa.png',
  DrobeIconName.laundry: 'assets/icons/streamline/Laundry.png',
  DrobeIconName.lookbook: 'assets/icons/streamline/lookbook.png',
  DrobeIconName.outfit: 'assets/icons/streamline/outfits.png',
  DrobeIconName.wardrobe: 'assets/icons/streamline/wardrobe.png',
};

class DrobeIcon extends StatelessWidget {
  final DrobeIconName name;
  final IconData fallback;
  final double size;
  final Color? color;
  final double? strokeWidth;

  const DrobeIcon({
    super.key,
    required this.name,
    required this.fallback,
    this.size = 24,
    this.color,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color;
    final pngAsset = _streamlinePngIconAssets[name];
    final assetName = _streamlineIconAssets[name];

    if (pngAsset != null) {
      final image = Image.asset(
        pngAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, size: size, color: iconColor),
      );

      if (iconColor == null) {
        return image;
      }

      return ColorFiltered(
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        child: image,
      );
    }

    if (assetName == null) {
      return Icon(fallback, size: size, color: iconColor);
    }

    return SvgPicture.asset(
      'assets/icons/streamline/$assetName.svg',
      width: size,
      height: size,
      colorFilter: iconColor == null
          ? null
          : ColorFilter.mode(iconColor, BlendMode.srcIn),
      placeholderBuilder: (_) => Icon(fallback, size: size, color: iconColor),
    );
  }
}
