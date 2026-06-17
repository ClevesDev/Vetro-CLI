/// ANSI terminal formatting utilities for Vetro CLI output.
///
/// Provides color and style helpers that respect a global `enabled`
/// flag — when disabled (e.g. via `--no-color`), all methods return
/// their input unmodified.
library;

import 'package:vetro/core/models/finding.dart';

/// Static ANSI escape-code helpers for terminal output.
///
/// Every method is a pure string transformation: wrap `text` in the
/// appropriate escape sequence, or return it unchanged when
/// `enabled` is `false`.
final class Ansi {
  const Ansi._();

  /// Master switch for ANSI output. Set to `false` for plain text
  /// (e.g. when piping to a file or when `--no-color` is passed).
  static bool enabled = true;

  // ── ANSI escape codes ──────────────────────────────────────────

  static const String _reset = '\x1B[0m';
  static const String _redCode = '\x1B[31m';
  static const String _yellowCode = '\x1B[33m';
  static const String _cyanCode = '\x1B[36m';
  static const String _greenCode = '\x1B[32m';
  static const String _boldCode = '\x1B[1m';
  static const String _dimCode = '\x1B[2m';

  // ── Color methods ──────────────────────────────────────────────

  /// Wraps [text] in red ANSI escape codes.
  static String red(String text) =>
      enabled ? '$_redCode$text$_reset' : text;

  /// Wraps [text] in yellow ANSI escape codes.
  static String yellow(String text) =>
      enabled ? '$_yellowCode$text$_reset' : text;

  /// Wraps [text] in cyan ANSI escape codes.
  static String cyan(String text) =>
      enabled ? '$_cyanCode$text$_reset' : text;

  /// Wraps [text] in green ANSI escape codes.
  static String green(String text) =>
      enabled ? '$_greenCode$text$_reset' : text;

  /// Wraps [text] in bold ANSI escape codes.
  static String bold(String text) =>
      enabled ? '$_boldCode$text$_reset' : text;

  /// Wraps [text] in dim ANSI escape codes.
  static String dim(String text) =>
      enabled ? '$_dimCode$text$_reset' : text;

  // ── Semantic helpers ───────────────────────────────────────────

  /// Colors [text] according to [severity]:
  /// - [Severity.error] → red
  /// - [Severity.warning] → yellow
  /// - [Severity.info] → cyan
  static String severityColor(Severity severity, String text) =>
      switch (severity) {
        Severity.error => red(text),
        Severity.warning => yellow(text),
        Severity.info => cyan(text),
      };

  /// Renders a visual progress bar.
  ///
  /// [value] is the current progress, [max] is the upper bound.
  /// [width] controls the total number of bar characters (default 20).
  ///
  /// Example output: `████████░░░░░░░░░░░░`
  static String progressBar(
    int value,
    int max, {
    int width = 20,
  }) {
    if (max <= 0) return '░' * width;

    final filled = ((value / max) * width).clamp(0, width).round();
    final empty = width - filled;
    final bar = '${'█' * filled}${'░' * empty}';
    return bar;
  }
}
