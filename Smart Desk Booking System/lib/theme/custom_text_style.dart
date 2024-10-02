import 'package:flutter/material.dart';
import '../core/app_export.dart';

/// A collection of pre-defined text styles for customizing text appearance,
/// categorized by different font families and weights.
/// Additionally, this class includes extensions on [TextStyle] to easily apply specific font families to text.

class CustomTextStyles {
  // Body text style
  static get bodySmallInterBlack900 =>
      theme.textTheme.bodySmall!.inter.copyWith(
        color: appTheme.black900.withOpacity(0.55),
        fontSize: 12.fSize,
      );
  // Headline text style
  static get headlineSmallOnPrimaryContainer =>
      theme.textTheme.headlineSmall!.copyWith(
        color: theme.colorScheme.onPrimaryContainer.withOpacity(1),
        fontWeight: FontWeight.w600,
      );
  // Label text style
  static get labelMediumInterGray400 =>
      theme.textTheme.labelMedium!.inter.copyWith(
        color: appTheme.gray400,
      );
  // Title text style
  static get titleLargeFontAwesome6Free =>
      theme.textTheme.titleLarge!.fontAwesome6Free.copyWith(
        fontWeight: FontWeight.w900,
      );
  static get titleLargeGowunDodum =>
      theme.textTheme.titleLarge!.gowunDodum.copyWith(
        fontWeight: FontWeight.w400,
      );
  static get titleLargeInter => theme.textTheme.titleLarge!.inter.copyWith(
        fontWeight: FontWeight.w700,
      );
  static get titleMediumMontserratOnPrimaryContainer =>
      theme.textTheme.titleMedium!.montserrat.copyWith(
        color: theme.colorScheme.onPrimaryContainer.withOpacity(1),
        fontWeight: FontWeight.w600,
      );
  static get titleMediumOnPrimaryContainer =>
      theme.textTheme.titleMedium!.copyWith(
        color: theme.colorScheme.onPrimaryContainer.withOpacity(1),
      );
}

extension on TextStyle {
  TextStyle get fontAwesome6Free {
    return copyWith(
      fontFamily: 'Font Awesome 6 Free',
    );
  }

  TextStyle get inter {
    return copyWith(
      fontFamily: 'Inter',
    );
  }

  TextStyle get montserrat {
    return copyWith(
      fontFamily: 'Montserrat',
    );
  }

  TextStyle get gowunDodum {
    return copyWith(
      fontFamily: 'Gowun Dodum',
    );
  }
}
