import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:vetro/core/models/config.dart';
import 'package:vetro/analyzers/dart/dart_analyzer.dart';
import 'package:vetro/core/models/finding.dart';
import 'package:vetro/core/rules/rule_registry.dart';
import 'package:vetro/core/rules/rule.dart';

void main() async {
  print('==================================================================');
  print('      VETRO SCIENTIFIC AUDIT: PRECISION, RECALL & F1-SCORE        ');
  print('==================================================================\n');

  // Labeled Corpus: A set of functions with known quality classifications.
  // 1 = True (should trigger a finding of a specific type), 0 = False (should be clean).
  final corpus = [
    // --- CATEGORY: CLEAN (Expected 0 findings) ---
    _CodeSample(
      name: 'Clean Simple Helper (Cohesive & Low Complexity)',
      expectedDebt: false,
      source: '''
        /// Calculates the average value of a list.
        /// Because we need a safe fallback, we return 0.0 if the list is empty.
        double calculateAverage(List<double> values) {
          if (values.isEmpty) return 0.0;
          double sum = 0.0;
          for (final val in values) {
            sum += val;
          }
          return sum / values.length;
        }
      ''',
    ),
    _CodeSample(
      name: 'Cohesive User Class (High Cohesion)',
      expectedDebt: false,
      source: r'''
        /// Represents a user profile with personal details.
        class UserProfile {
          final String firstName;
          final String lastName;
          UserProfile(this.firstName, this.lastName);
          
          String getFullName() {
            return '$firstName $lastName';
          }
          
          String getInitials() {
            return '${firstName[0].toUpperCase()}${lastName[0].toUpperCase()}';
          }
        }
      ''',
    ),

    // --- CATEGORY: AI DEBT / BUGGY (Expected findings) ---
    _CodeSample(
      name: 'Deeply Nested Branching (Cyclomatic/Cognitive Complexity & Intent Gap)',
      expectedDebt: true,
      expectedRuleId: 'cognitive_complexity',
      source: r'''
        void processInvoiceData(int status, int type, List<int> items, bool isTaxable) {
          if (status == 1) {
            if (type == 2) {
              for (final item in items) {
                if (item > 100) {
                  if (item == 999) {
                    if (isTaxable) {
                      print('Applying tax for heavy item');
                    } else {
                      print('Applying discount for heavy item');
                    }
                  }
                }
              }
            } else {
              print('Invalid type');
            }
          }
        }
      ''',
    ),
    _CodeSample(
      name: 'Uncohesive Class (Low Cohesion)',
      expectedDebt: true,
      expectedRuleId: 'low_cohesion',
      source: r'''
        // Class combining unrelated features, violating SRP.
        class UserManager {
          void saveUser(String name) {
            print('Saving user $name');
          }
          
          double calculateSquareRoot(double val) {
            return val * val; // Fake sqrt for simplicity
          }
          
          String formatTime(DateTime time) {
            return time.toIso8601String();
          }
        }
      ''',
    ),
  ];

  var truePositives = 0;
  var falsePositives = 0;
  var trueNegatives = 0;
  var falseNegatives = 0;

  final analyzer = DartAnalyzer();
  final config = VetroConfig.defaults();

  print('| Muestra de Código | Esperado | Vetro Findings | Clasificación |');
  print('| :--- | :---: | :---: | :---: |');

  for (final sample in corpus) {
    // We analyze each sample as a single virtual file
    final unit = parseString(content: sample.source).unit;
    final rules = RuleRegistry.instance.createRules(config);
    final findings = <Finding>[];

    for (final rule in rules) {
      if (rule is! CrossFileRule) {
        findings.addAll(rule.analyze(unit, 'lib/sample.dart', sample.source));
      }
    }

    final hasFindings = findings.isNotEmpty;
    String classification;

    if (sample.expectedDebt) {
      if (hasFindings) {
        truePositives++;
        classification = 'Verdadero Positivo (VP)';
      } else {
        falseNegatives++;
        classification = 'Falso Negativo (FN) ❌';
      }
    } else {
      if (hasFindings) {
        falsePositives++;
        classification = 'Falso Positivo (FP) ❌';
      } else {
        trueNegatives++;
        classification = 'Verdadero Negativo (VN)';
      }
    }

    final findingsSummary = findings.map((f) => f.ruleId).join(', ');
    print('| ${sample.name} | ${sample.expectedDebt ? 'Deuda' : 'Limpio'} | [${findingsSummary.isEmpty ? 'Ninguno' : findingsSummary}] | $classification |');
  }

  // Calculate Precision, Recall, and F1-Score
  final precision = truePositives + falsePositives > 0
      ? truePositives / (truePositives + falsePositives)
      : 1.0;
  final recall = truePositives + falseNegatives > 0
      ? truePositives / (truePositives + falseNegatives)
      : 1.0;
  final f1Score = precision + recall > 0
      ? 2.0 * (precision * recall) / (precision + recall)
      : 0.0;

  print('\n------------------------------------------------------------------');
  print('Resultados de la Matriz de Confusión:');
  print('- Verdaderos Positivos (VP): $truePositives');
  print('- Falsos Positivos (FP): $falsePositives');
  print('- Verdaderos Negativos (VN): $trueNegatives');
  print('- Falsos Negativos (FN): $falseNegatives');
  print('\nMétricas Científicas del Modelo:');
  print('- Precisión (Precision): ${(precision * 100).toStringAsFixed(1)}%');
  print('- Exhaustividad (Recall): ${(recall * 100).toStringAsFixed(1)}%');
  print('- F1-Score: ${(f1Score * 100).toStringAsFixed(1)}%');
  print('------------------------------------------------------------------');
}

class _CodeSample {
  final String name;
  final bool expectedDebt;
  final String? expectedRuleId;
  final String source;

  const _CodeSample({
    required this.name,
    required this.expectedDebt,
    this.expectedRuleId,
    required this.source,
  });
}
