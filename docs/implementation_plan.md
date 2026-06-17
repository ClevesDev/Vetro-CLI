# Plan de Implementación — Soporte para TypeScript (Vetro v0.2.0)

Este plan describe la incorporación de soporte para analizar proyectos de TypeScript (.ts y .tsx) en Vetro, permitiendo detectar deuda técnica inducida por IA (duplicación semántica, complejidad cognitiva, baja entropía, acoplamiento estrecho, etc.) mediante un pipeline híbrido.

---

## User Review Required

> [!IMPORTANT]
> **Requisito de Entorno (Runtime):**
> Dado que Dart no posee un compilador nativo de TypeScript, delegaremos el parseo sintáctico a un script auxiliar de Node.js que genera el AST en formato JSON.
> * **Requisito:** El usuario debe tener instalado Node.js (versión 18+) para analizar archivos de TypeScript en producción.
> * **Verificación:** Vetro validará si el comando `node` está disponible en el PATH del sistema; si no, fallará de forma controlada con un mensaje descriptivo.
> * **Pruebas (CI/CD):** Para evitar depender de Node en las pruebas de integración y asegurar portabilidad, los tests unitarios en Dart utilizarán ASTs serializados (JSON mocks).

---

## Proposed Changes

### Componente: Core (Abstracción de AST de TypeScript)

#### [NEW] [ts_node.dart](file:///home/dimas/development/Vetro/lib/core/models/ts_node.dart)
* Implementar la clase `TsNode` que representará un nodo sintáctico de TypeScript deserializado desde JSON.
* Atributos: `type` (ej. `IfStatement`), `raw` (mapa de propiedades), `children` (nodos hijos), `start`, `end`, `line`.
* Métodos:
  * `List<String> extractIdentifiers()`: Obtiene todos los nombres de variables/funciones declarados.
  * `List<String> tokenizeRaw()`: Obtiene el flujo ordenado de tokens sintácticos para similitud del coseno.
  * `int get nodeCount`: Retorna la cantidad total de subnodos.

---

### Componente: Parser Sintáctico (Node.js Helper)

#### [NEW] [ts_parser.js](file:///home/dimas/development/Vetro/lib/analyzers/typescript/parser/ts_parser.js)
* Un script ligero e independiente de JavaScript que lee un archivo `.ts`/`.tsx` y escribe en `stdout` la estructura del AST en formato JSON.
* Utilizaremos `@babel/parser` o el paquete oficial de `typescript` a través de un bundle auto-contenido (empaquetado con `esbuild`) para que no requiera ninguna instalación de `npm` a nivel de usuario (cero dependencias en ejecución).

---

### Componente: Analyzers (Orquestador y Reglas de TypeScript)

#### [NEW] [typescript_analyzer.dart](file:///home/dimas/development/Vetro/lib/analyzers/typescript/typescript_analyzer.dart)
* Orquestador equivalente a `DartAnalyzer` para TypeScript.
* Valida la presencia de `node` en el sistema.
* Ejecuta el proceso secundario `node ts_parser.js <archivo>` para cada archivo, recolecta la salida y reconstruye el árbol `TsNode`.
* Aplica las reglas registradas para TypeScript y consolida los resultados en un `ProjectReport`.

#### [NEW] [lib/analyzers/typescript/rules/](file:///home/dimas/development/Vetro/lib/analyzers/typescript/rules/)
Implementar las reglas homólogas adaptadas a la estructura de nodos de TypeScript (Babel/ESTree AST format):
* **`ts_cyclomatic_complexity_rule.dart`**: Cuenta bifurcaciones (`IfStatement`, `SwitchCase`, `ConditionalExpression`, bucles).
* **`ts_cognitive_complexity_rule.dart`**: Implementa la métrica de Campbell con anidamientos.
* **`ts_low_entropy_rule.dart`**: Calcula la entropía sobre los tipos de nodos AST y los identificadores declarados.
* **`ts_intent_gap_rule.dart`**: Ratio de comentarios explicativos frente a complejidad.
* **`ts_low_cohesion_rule.dart`**: Cohesión de métodos dentro de clases/interfaces.
* **`ts_tight_coupling_rule.dart`**: Grafo de dependencias a través de declaraciones `import`.
* **`ts_circular_dependency_rule.dart`**: Detección de ciclos de importación mediante DFS.
* **`ts_semantic_duplication_rule.dart`**: Similitud del coseno sobre tokens de funciones.

---

### Componente: CLI (bin/vetro.dart)

#### [MODIFY] [vetro.dart](file:///home/dimas/development/Vetro/bin/vetro.dart)
* **Auto-detección**: Analizar el directorio objetivo. Si contiene un archivo `tsconfig.json` o la mayoría de los archivos son `.ts`/`.tsx`, instanciar y ejecutar `TypeScriptAnalyzer`. De lo contrario, usar `DartAnalyzer`.
* **Argumentos de Línea**: Añadir la opción `--language` / `-l` (valores: `dart`, `typescript`, `auto`, por defecto `auto`) para permitir al usuario forzar el motor de análisis.

---

## Verification Plan

### Automated Tests
* #### [NEW] [typescript_analyzer_test.dart](file:///home/dimas/development/Vetro/test/typescript_analyzer_test.dart)
  * Suite de pruebas unitarias que simulan la ejecución de reglas sobre ASTs de TypeScript mockeados en JSON.
* Ejecutar la suite completa para asegurar que no hay regresiones en Dart y que las nuevas reglas de TypeScript funcionan matemáticamente:
  ```bash
  dart test
  ```

### Manual Verification
* **Estudio Piloto TypeScript**: Crear un archivo de prueba `scratch/test_project/index.ts` con duplicación de código e intentar analizarlo con Vetro para certificar que el pipeline del proceso secundario de Node.js funciona correctamente.
