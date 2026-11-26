import 'package:flutter/material.dart';
import 'package:connect_four_flutter/core/theme/nb_colors.dart';

class NbTheme {
  const NbTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: NbColors.background,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: NbColors.ink,
        displayColor: NbColors.ink,
      ),
    );
  }
}
