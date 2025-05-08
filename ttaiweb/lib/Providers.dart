import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'LanguageNotifier.dart';



final localeProvider = StateNotifierProvider<LanguageNotifier, Locale>(
        (ref) => LanguageNotifier());







