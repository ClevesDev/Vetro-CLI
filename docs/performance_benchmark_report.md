# Vetro — Reporte de Benchmark de Rendimiento

Este reporte detalla los resultados obtenidos al ejecutar el script de benchmark sobre los cinco proyectos en el entorno de desarrollo, midiendo la velocidad, el procesamiento y la escalabilidad del analizador estático en Dart.

---

## 📊 Resultados del Benchmark

El benchmark fue ejecutado promediando **3 iteraciones** consecutivas después de una corrida de calentamiento (warm-up) para mitigar el impacto de la compilación JIT (Just-In-Time) de Dart.

| Proyecto | Archivos | Líneas de Código | Tiempo Promedio | Rendimiento (Líneas/seg) | Clasificación de Carga |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Proyecto_XXX_B** | 46 | 7,462 | **333.0 ms** (0.33 s) | **22,408.4** | Ligera |
| **Vetro (Self)** | 30 | 4,568 | **290.0 ms** (0.29 s) | **15,751.7** | Ligera |
| **Proyecto_XXX_C** | 48 | 6,641 | **417.3 ms** (0.41 s) | **15,912.9** | Ligera |
| **Proyecto_XXX_A** | 63 | 8,933 | **477.0 ms** (0.47 s) | **18,727.5** | Ligera |
| **Proyecto_XXX_D** | 225 | 56,287 | **25,177.0 ms** (25.17 s) | **2,235.7** | Pesada |

---

## ⚙️ Análisis de Escalabilidad Computacional

Al observar la tabla de rendimiento, podemos deducir el comportamiento de los algoritmos del motor matemático de Vetro:

### 1. Comportamiento en Proyectos de Escala Ligera (< 10,000 LOC)
* Para proyectos como `Proyecto_XXX_B`, `Vetro`, `Proyecto_XXX_C` y `Proyecto_XXX_A`, el analizador se ejecuta en **menos de medio segundo** (300 ms - 480 ms).
* El rendimiento alcanza picos de hasta **22,400 líneas analizadas por segundo**.
* **Razón**: A este nivel, las comprobaciones lineales $O(N)$ (como la entropía de Shannon, la complejidad ciclomática de McCabe y Halstead) dominan el tiempo de ejecución. El analizador de sintaxis de Dart (`package:analyzer`) compila las representaciones en memoria de forma instantánea.

### 2. Comportamiento en Proyectos de Escala Pesada (~56,000 LOC)
* Al pasar a `Proyecto_XXX_D` (225 archivos y más de 56,000 líneas), el tiempo promedio se incrementa a **25.17 segundos**, reduciendo el rendimiento a **2,235 líneas/seg**.
* **Razón**: Las métricas de análisis cruzado como **Duplicación Semántica (`semantic_duplication`)** y **Copy-Mutate (`copy_mutate`)** comparan los cuerpos de las funciones *de par en par*. Esto significa que el tiempo de comparación escala de forma cuadrática:
  $$\text{Complejidad} = O(F^2 \times M^2)$$
  donde $F$ es el número de archivos y $M$ la cantidad de métodos por archivo. Comparar cuadráticamente más de mil métodos genera millones de operaciones de similitud coseno de tokens.

---

## 💡 Recomendaciones de Optimización de Rendimiento

Para mantener el tiempo de análisis por debajo de 2 segundos en proyectos grandes como `Proyecto_XXX_D` en el futuro, podemos aplicar las optimizaciones descritas en la Hoja de Ruta para 2026:

1. **Fingerprinting de Subárboles AST (Merkle Trees):**
   * Pre-calcular un hash determinista de la estructura del árbol para cada método.
   * Si dos métodos tienen un hash diferente a nivel de bloque lógico principal, omitir la comparación cuadrática de tokens coseno (tiempo de comparación inmediato $O(1)$).
2. **Filtrado Primitivo (Heurística de Longitud):**
   * Evitar comparar funciones cuya diferencia en cantidad de tokens sea superior al $30\%$, ya que matemáticamente su similitud coseno jamás superará el umbral del $70\%$ - $80\%$.
3. **Paralelización en Isolate Workers:**
   * Distribuir las comparaciones cruzadas del `analyzeProject` en múltiples hilos de Dart (Isolates) para aprovechar todos los núcleos lógicos del procesador.

---

## 📈 Diagnóstico de Hardware: Migración de Hilos (Thread Migration)

Durante nuestras pruebas de estrés (analizando dependencias FFI masivas en `cupertino_http`), pudimos capturar mediante el monitor de sistema el comportamiento de Vetro en hardware multihilo de forma empírica:

![Gráfica de CPU mostrando el patrón de Thread Migration](/home/dimas/development/Vetro/assets/cpu_thread_migration.png)

### Análisis del Comportamiento en Hardware:
* **Uso Monohilo Limitado**: Vetro, ejecutándose en un único Isolate de Dart, satura al $100\%$ un único hilo lógico de ejecución.
* **Comportamiento en la Gráfica (Olas Alternadas)**: Como muestra la captura de pantalla de los recursos de la CPU, las líneas de actividad de los núcleos (`CPU 1`, `CPU 2`, `CPU 3`, `CPU 4`) se alternan en ondas periódicas cruzadas. Esto es evidencia del programador de tareas del kernel de Linux migrando dinámicamente el hilo de ejecución activo entre núcleos físicos para disipar la carga térmica y balancear el sistema.
* **El Desafío**: Aunque el procesador cuenta con 4 núcleos, el $75\%$ de la capacidad de cómputo del hardware se mantiene ocioso durante análisis pesados. Esto justifica la necesidad de evolucionar el motor hacia la paralelización concurrente con **Dart Isolates** en la v0.2.0.

