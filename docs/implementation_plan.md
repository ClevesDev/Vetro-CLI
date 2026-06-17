# Plan de Implementación — Mejoras Matemáticas Avanzadas para Vetro (Fases 1-4)

Este plan describe la incorporación de tres grandes mejoras matemáticas en el núcleo de Vetro para potenciar la detección objetiva de deuda técnica de IA y optimizar el rendimiento del análisis cruzado.

---

## User Review Required

> [!IMPORTANT]
> **Planificación por Fases:**
> Proponemos 4 fases de ejecución secuencial para asegurar estabilidad, con suites de pruebas robustas en cada una y validación de dogfooding.

---

## Proposed Changes

### Fase 1: Hashing de Estructura AST (Merkle Trees) para Duplicación Semántica
* **Objetivo**: Evitar comparaciones cruzadas $O(N^2)$ costosas de tokens o LCS cuando las funciones poseen estructuras idénticas, reduciendo el análisis a tiempo constante $O(1)$ en coincidencias exactas.
* **Componentes a Modificar**:
  * #### [MODIFY] [similarity.dart](file:///home/dimas/development/Vetro/lib/core/metrics/similarity.dart)
    * Implementar `String computeAstHash(AstNode node)` que normaliza la estructura del nodo (reemplazando nombres de variables e identificadores por marcadores secuenciales) y genera un hash MD5/SHA-256 de su firma sintáctica.
  * #### [MODIFY] [copy_mutate_rule.dart](file:///home/dimas/development/Vetro/lib/analyzers/dart/rules/copy_mutate_rule.dart) y [semantic_duplication_rule.dart](file:///home/dimas/development/Vetro/lib/analyzers/dart/rules/semantic_duplication_rule.dart)
    * Durante la fase de precomputación en el hilo principal o isolates, generar y almacenar `astHash`.
    * En el bucle de comparación cruzada, si `hashA == hashB`, saltarse el cálculo de distancia de tokens/LCS y reportar de inmediato similitud del `100%`.

---

### Fase 2: Coeficiente de Agrupamiento Local (Clustering Coefficient) en Grafo de Dependencias
* **Objetivo**: Identificar desorganización y parches de importación cruzada caótica (típica de LLMs) mediante la densidad local de aristas vecinas.
* **Componentes a Modificar / Crear**:
  * #### [MODIFY] [dependency_graph.dart](file:///home/dimas/development/Vetro/lib/core/metrics/dependency_graph.dart)
    * Implementar `double localClusteringCoefficient(String node)` que calcula la modularidad local de un nodo midiendo cuántos de sus archivos vecinos (importadores o importados) están conectados entre sí.
  * #### [NEW] [local_clustering_coefficient_rule.dart](file:///home/dimas/development/Vetro/lib/analyzers/dart/rules/local_clustering_coefficient_rule.dart)
    * Crear la regla `LocalClusteringCoefficientRule` que evalúa archivos con alto acoplamiento (fan-in + fan-out) pero bajo agrupamiento local, indicando que el archivo actúa como un puente desordenado de dependencias.
  * #### [MODIFY] [config.dart](file:///home/dimas/development/Vetro/lib/core/models/config.dart) y [dart_analyzer.dart](file:///home/dimas/development/Vetro/lib/analyzers/dart/dart_analyzer.dart)
    * Registrar la regla `local_clustering_coefficient` (umbral por defecto: `< 0.15` para archivos con $\ge 4$ conexiones).

---

### Fase 3: Entropía de Shannon de Identificadores (Low Identifier Entropy)
* **Objetivo**: Detectar código repetitivo e inútil ("boilerplate") o variables redundantes generadas mecánicamente por LLMs evaluando el vocabulario real de identificadores.
* **Componentes a Modificar**:
  * #### [MODIFY] [entropy.dart](file:///home/dimas/development/Vetro/lib/core/metrics/entropy.dart)
    * Implementar `double identifierEntropy(AstNode node)` que extrae todos los identificadores creados por el programador (nombres de variables, clases, métodos), filtra palabras clave de Dart, y calcula la entropía sobre su distribución de frecuencia.
  * #### [MODIFY] [low_entropy_rule.dart](file:///home/dimas/development/Vetro/lib/analyzers/dart/rules/low_entropy_rule.dart)
    * Extender la regla para evaluar tanto la entropía de tipos de nodos AST (estructura) como la entropía de nombres de identificadores (semántica), generando hallazgos cuando el vocabulario es anormalmente repetitivo (por defecto `< 2.0`).

---

### Fase 4: Pruebas Robustas y Verificación Multi-repo
* **Objetivo**: Asegurar la máxima cobertura de testing y evaluar las nuevas reglas contra Vetro y `cupertino_http`.
* **Componentes a Crear**:
  * #### [NEW] [ast_hashing_test.dart](file:///home/dimas/development/Vetro/test/ast_hashing_test.dart)
    * Pruebas para la consistencia del hash AST normalizado (debe dar el mismo hash para funciones idénticas renombradas).
  * #### [NEW] [clustering_coefficient_test.dart](file:///home/dimas/development/Vetro/test/clustering_coefficient_test.dart)
    * Pruebas del cálculo del coeficiente de agrupamiento local en grafos de prueba acoplados vs. modulares.
  * #### [NEW] [identifier_entropy_test.dart](file:///home/dimas/development/Vetro/test/identifier_entropy_test.dart)
    * Pruebas para detectar baja entropía de identificadores en código repetitivo.

---

## Verification Plan

### Automated Tests
* Ejecutar la suite completa para comprobar que todas las pruebas (las existentes y las nuevas) estén en verde:
  ```bash
  dart test
  ```

### Manual Verification
* **Vetro (Self-Analysis)**: Correr Vetro sobre sí mismo para asegurar que mantiene un score de `100/100` y evaluar los nuevos tiempos de ejecución tras optimizar la duplicidad con el hash AST.
* **cupertino_http**: Analizar el paquete externo y reportar la variación en hallazgos (nuevas alertas de baja entropía o coeficiente de agrupamiento local).
