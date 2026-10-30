import 'package:flutter/widgets.dart';

import '../widgets/phosphor.g.dart';

/// Subject icons from the prototype (screens-onboard.js SUBJECTS), keyed by subject code.
IconData subjectIcon(String code, [PhosphorIconsStyle s = PhosphorIconsStyle.regular]) => switch (code) {
  'eng' => PhosphorIcons.bookOpenText(s),
  'mth' => PhosphorIcons.function(s),
  'phy' => PhosphorIcons.atom(s),
  'chm' => PhosphorIcons.flask(s),
  'bio' => PhosphorIcons.dna(s),
  'eco' => PhosphorIcons.chartLineUp(s),
  'gov' => PhosphorIcons.bank(s),
  'lit' => PhosphorIcons.bookBookmark(s),
  'geo' => PhosphorIcons.globeHemisphereWest(s),
  'com' => PhosphorIcons.storefront(s),
  'acc' => PhosphorIcons.calculator(s),
  'agr' => PhosphorIcons.plant(s),
  'fmt' => PhosphorIcons.sigma(s),
  'his' => PhosphorIcons.scroll(s),
  _ => PhosphorIcons.bookOpen(s),
};
