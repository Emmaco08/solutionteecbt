import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'router.dart';
import 'theme/theme.dart';

class SolutionTeeApp extends ConsumerStatefulWidget {
  const SolutionTeeApp({super.key, required this.initialSettings});
  final AppSettings initialSettings;
  @override
  ConsumerState<SolutionTeeApp> createState() => _SolutionTeeAppState();
}

class _SolutionTeeAppState extends ConsumerState<SolutionTeeApp> {
  @override
  void initState() {
    super.initState();
    ref.read(settingsProvider.notifier).hydrate(widget.initialSettings);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SolutionTee CBT',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.theme,
      routerConfig: router,
      // In-app "reduce motion" switch adds to the phone's own setting.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(disableAnimations: mq.disableAnimations || settings.reduceMotion, textScaler: mq.textScaler.clamp(maxScaleFactor: 1.4)),
          child: child!,
        );
      },
    );
  }
}
