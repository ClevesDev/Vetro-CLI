# 🚀 Notas de Lanzamiento y Documentación de Commits — Vetro v0.4.0

Este documento describe detalladamente los cambios realizados en los últimos commits del repositorio de **Vetro** y sirve de base para la documentación de Pull Requests o Releases en GitHub.

---

## 📌 Resumen de Commits Recientes

### 1. `6d43b4d` — Implementación de Análisis de Git Diff e Inyección de Prompts
> **Mensaje de Commit**: `feat: implement git diff analysis (vetro diff) and AI prompt remedies format`
* **Descripción**: Introducción de la característica de análisis incremental y del formateador de remedios de IA.
* **Componentes Afectados**:
  * [git_diff_parser.dart](file:///home/dimas/development/Vetro/lib/cli/git_diff_parser.dart): Procesa e identifica líneas añadidas/modificadas mediante `git diff -U0`.
  * [prompt_reporter.dart](file:///home/dimas/development/Vetro/lib/core/report/prompt_reporter.dart): Formatea hallazgos agregando código de contexto (±5 líneas con marcador `👉`) y directrices de refactorización para el LLM.
  * [bin/vetro.dart](file:///home/dimas/development/Vetro/bin/vetro.dart): Registra el comando `diff` y filtra hallazgos.
  * [config.dart](file:///home/dimas/development/Vetro/lib/core/models/config.dart): Añade soporte para el formato `prompt` en CLI y archivo YAML.

### 2. `6ef3c32` — Unificación de Halstead, Inicialización y Optimización de Python
> **Mensaje de Commit**: `feat: implement unified Halstead complexity, parallel Python processing, vetro init command, and fix nested functions rule crashes`
* **Descripción**: Mejoras de modularidad, paralelismo y el comando de inicialización.
* **Componentes Afectados**:
  * [halstead_complexity_rule.dart](file:///home/dimas/development/Vetro/lib/core/rules/halstead_complexity_rule.dart): Regla unificada en el core.
  * [python_analyzer.dart](file:///home/dimas/development/Vetro/lib/analyzers/python/python_analyzer.dart): Ejecución en paralelo de análisis Python mediante `Isolate.run`.
  * [py_cognitive_complexity_rule.dart](file:///home/dimas/development/Vetro/lib/analyzers/python/rules/py_cognitive_complexity_rule.dart): Corrección de error crítico de parada `Bad state: No element` al procesar funciones anidadas.
  * [bin/vetro.dart](file:///home/dimas/development/Vetro/bin/vetro.dart): Comando `vetro init` con autodetección de lenguaje.

### 3. `4d605ea` — Fusión de Configuraciones de Reglas
> **Mensaje de Commit**: `fix(config): merge parsed rules with default configs to prevent silences`
* **Descripción**: Asegura que las reglas no declaradas explícitamente en el archivo YAML mantengan su comportamiento por defecto en lugar de desactivarse silenciosamente.

### 4. `0b21591` — Corrección de Expansión de Glob
> **Mensaje de Commit**: `fix(glob): avoid invalid brace expansion for single-extension languages`
* **Descripción**: Corrige errores al expandir globs para lenguajes con una sola extensión (evita fallos de sintaxis al expandir expresiones vacías).

### 5. `8d3b351` — Analizador Completo de Python (v0.3.0)
> **Mensaje de Commit**: `feat(python): implement complete Python (v0.3.0) analyzer and adapters with parities`
* **Descripción**: Soporte inicial para analizar código Python (.py) traduciendo su AST a los modelos del Core de Vetro.

---

## 📋 Plantilla de Pull Request (para copiar y pegar en GitHub)

```markdown
## Descripción
Este PR introduce dos grandes características orientadas a la productividad diaria en equipos de desarrollo: el análisis incremental de cambios (`vetro diff`) y un reportero de remediación automática mediante prompts de IA (`--format prompt`). Además, consolida las optimizaciones de procesamiento paralelo en Python, unifica la regla de complejidad de Halstead en el Core y corrige caídas al analizar funciones anidadas.

### Cambios Clave
1. **Comando `vetro diff [base_ref]`**:
   - Parseador de diff unificado (`git diff -U0`) en `GitDiffParser`.
   - Permite escanear deuda técnica únicamente sobre las líneas modificadas localmente, recalculando el score de deuda del diff.
2. **Reportero de Prompts (`PromptReporter`)**:
   - Genera prompts contextuales listos para enviar a un LLM (Claude, ChatGPT).
   - Inyecta fragmentos de código del archivo con un margen de ±5 líneas y resalta la línea exacta con `👉`.
3. **Optimización y Estabilidad en Python**:
   - Análisis de Python en múltiples hilos con `Isolate.run`.
   - Corrección de caídas en la regla de complejidad cognitiva de Python por funciones anidadas.
4. **Comando `vetro init`**:
   - Inicializa el archivo `vetro.yaml` con autodetección automática del lenguaje predominante.

### Verificación y Calidad
- **Pruebas Unitarias**: Suite de pruebas ampliada a **113 pruebas unitarias y algebraicas** (pasando exitosamente al 100% mediante `dart test`).
- **Auto-Análisis (Dogfooding)**: El repositorio se analiza a sí mismo con éxito arrojando un **AI Debt Score de 100/100**.
```

---

## 🛠️ Instrucciones para Subir los Cambios a GitHub

Ejecuta los siguientes comandos en tu terminal para publicar la rama y sus commits en GitHub:

1. **Asegurar la conexión con el repositorio remoto**:
   ```bash
   git remote -v
   ```
2. **Subir los cambios a la rama principal (master)**:
   ```bash
   git push origin master
   ```
   *(Si estás trabajando en una rama específica, reemplaza `master` por el nombre de tu rama, por ejemplo: `git push origin feat/git-diff-analysis`)*.
