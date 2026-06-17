/// Central registry of all available analysis rules.
///
/// The registry is the single source of truth for which rules
/// exist and how to instantiate them with configuration.
library;

import 'package:vetro/core/models/config.dart';
import 'package:vetro/core/rules/rule.dart';

/// Factory function that creates a [Rule] with the given config.
typedef RuleFactory = Rule Function(RuleConfig config);

/// Registry of all available Vetro rules.
///
/// Rules register themselves via [register] at startup.
/// The DartAnalyzer queries this registry to build its
/// active rule set based on [VetroConfig].
final class RuleRegistry {
  RuleRegistry._();

  static final RuleRegistry instance = RuleRegistry._();

  final Map<String, RuleFactory> _factories = {};

  /// Register a rule factory under the given [id].
  ///
  /// Throws if a rule with that ID is already registered.
  void register(String id, RuleFactory factory) {
    if (_factories.containsKey(id)) {
      throw StateError('Rule "$id" is already registered.');
    }
    _factories[id] = factory;
  }

  /// Create all enabled rules from the given config.
  ///
  /// Returns only rules that are both registered AND enabled
  /// in the configuration.
  List<Rule> createRules(VetroConfig config) {
    final rules = <Rule>[];
    for (final entry in _factories.entries) {
      final ruleConfig = config.ruleConfig(entry.key);
      if (ruleConfig.enabled) {
        rules.add(entry.value(ruleConfig));
      }
    }
    return rules;
  }

  /// Get all registered rule IDs.
  List<String> get registeredIds => _factories.keys.toList();

  /// Check if a rule ID is registered.
  bool isRegistered(String id) => _factories.containsKey(id);

  /// Reset the registry (for testing only).
  void reset() => _factories.clear();
}
