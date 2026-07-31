import 'package:flutter/widgets.dart';

abstract final class ResponsiveLayout {
  static const compactBreakpoint = 720.0;
  static const contentMaxWidth = 960.0;

  static bool isCompact(BoxConstraints constraints) {
    return constraints.maxWidth < compactBreakpoint;
  }

  static Widget constrainContent({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, contentMaxWidth).toDouble()
            : contentMaxWidth;
        return Center(
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}
