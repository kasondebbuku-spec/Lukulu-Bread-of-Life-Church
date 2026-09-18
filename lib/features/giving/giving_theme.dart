import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/giving_record.dart';

/// UI colours for giving categories — kept separate from the domain model.
Color categoryColor(GivingCategory category) {
  switch (category) {
    case GivingCategory.tithe:
      return AppColors.secondaryDark;
    case GivingCategory.offering:
      return AppColors.blue;
    case GivingCategory.seed:
      return AppColors.primaryLight;
    case GivingCategory.thanksgiving:
      return AppColors.blueLight;
    case GivingCategory.pledge:
      return AppColors.secondary;
  }
}
