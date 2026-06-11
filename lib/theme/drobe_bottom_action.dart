import 'package:flutter/material.dart';

class DrobeBottomAction {
  static const double horizontalInset = 20;
  static const double bottomGap = 14;
  static const double controlHeight = 56;
  static const double contentGap = 8;

  static double _actionBottomOffsetForPadding(double bottomPadding) {
    return bottomPadding > 0 ? (bottomPadding * 0.65).clamp(18.0, 24.0) : 14.0;
  }

  static double absoluteBottomOffset(BuildContext context) {
    return actionBottomOffset(context);
  }

  static double actionBottomOffset(BuildContext context) {
    return _actionBottomOffsetForPadding(
        MediaQuery.viewPaddingOf(context).bottom);
  }

  static double actionContentInset(BuildContext context) {
    return actionBottomOffset(context) + controlHeight + contentGap;
  }

  static double drawerBottomOffset(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return bottomPadding > 0 ? (bottomPadding * 0.35).clamp(8.0, 14.0) : 8.0;
  }

  static double drawerContentInset(BuildContext context) {
    return drawerBottomOffset(context) + controlHeight + contentGap;
  }

  static double lowActionBottomOffset(BuildContext context) {
    return actionBottomOffset(context);
  }

  static double lowActionContentInset(BuildContext context) {
    return actionContentInset(context);
  }

  static double scaffoldContentInset(BuildContext context) {
    return actionContentInset(context);
  }

  static double safeAreaContentInset() {
    return bottomGap + controlHeight + contentGap;
  }

  static EdgeInsets floatingBarPadding(BuildContext context) {
    return EdgeInsets.fromLTRB(
      horizontalInset,
      8,
      horizontalInset,
      actionBottomOffset(context),
    );
  }
}

class DrobeBottomFabLocation extends FloatingActionButtonLocation {
  const DrobeBottomFabLocation._(this._alignment);

  const DrobeBottomFabLocation.center() : this._(Alignment.center);
  const DrobeBottomFabLocation.end() : this._(Alignment.centerRight);

  final Alignment _alignment;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final y = geometry.scaffoldSize.height -
        geometry.floatingActionButtonSize.height -
        DrobeBottomAction._actionBottomOffsetForPadding(
          geometry.minViewPadding.bottom,
        );

    final x = _alignment == Alignment.center
        ? (geometry.scaffoldSize.width -
                geometry.floatingActionButtonSize.width) /
            2
        : geometry.scaffoldSize.width -
            geometry.floatingActionButtonSize.width -
            DrobeBottomAction.horizontalInset;

    return Offset(x, y);
  }
}
