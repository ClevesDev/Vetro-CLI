# Hoja de Ruta de Validación Científica de Vetro

> **La IA opina. La matemática demuestra.**

Este documento presenta la metodología experimental y los resultados de las fases de validación científica diseñadas para demostrar que Vetro es un analizador de deuda técnica 100% viable, robusto y confiable.

---

## Metodología General de Validación

Para validar una herramienta de análisis estático basada en métricas algebraicas y topología de grafos, se aplica el método científico clásico estructurado en cuatro fases progresivas:

```mermaid
graph TD
    F1[Fase 1: Verificación de Invariantes Algebraicos] --> F2[Fase 2: Robustez Adversaria y Mutación]
    F2 --> F3[Fase 3: Precisión, Cobertura y Matriz de Confusión]
    F3 --> F4[Fase 4: Correlación con Juicio de Expertos Humanos]
```

---

## Fase 1: Verificación de Invariantes Algebraicos (Completado)

**Objetivo:** Demostrar que los algoritmos matemáticos del núcleo de Vetro son estables y correctos bajo cualquier entrada de código, respetando los límites y teoremas algebraicos de las métricas.

### Experimento y Metodología
Se ejecuta un análisis sistemático sobre una base de código real grande (33 archivos de Vetro, 5,348 líneas de código) utilizando una suite de pruebas basada en propiedades (`test/mathematical_properties_test.dart`). Se verifican los siguientes teoremas:

1. **Simetría y Límites del Coseno:**
   * Teorema: $Sim(A, B) \equiv Sim(B, A)$ y $0.0 \le Sim(A, B) \le 1.0$.
   * Identidad: $Sim(A, A) \equiv 1.0$.
2. **Límites de la Entropía de Shannon:**
   * Teorema: La entropía de distribución de nodos AST ($H(X)$) debe ser $\ge 0.0$ y $\le \log_2(N)$ para cualquier secuencia de longitud $N$.
   * Repetitividad extrema: Una secuencia homogénea de tokens idénticos debe arrojar exactamente $0.0$ de entropía.
3. **Normalización L2 del Autovector (PageRank):**
   * Teorema: Los valores de centralidad de autovector del grafo de dependencias de importación deben converger y su norma Euclidiana (L2) debe ser idénticamente $1.0$:
     $$\sum_{i=1}^{V} val_i^2 \equiv 1.0$$
4. **Límites de Cohesión de Clases:**
   * Teorema: La cohesión por similitud de identificadores de métodos ($Cohesion(C)$) debe situarse estrictamente en el intervalo $[0.0, 1.0]$.

### Resultados Obtenidos
* **Suite de Pruebas:** `test/mathematical_properties_test.dart` y `test/advanced_math_rules_test.dart` ejecutadas mediante `dart test`.
* **Resultados:** **29 pruebas de invariantes aprobadas**. Se comprobó la convergencia del algoritmo de PageRank con una tolerancia $\epsilon = 10^{-6}$ en menos de 10 iteraciones y la simetría absoluta de la similitud del coseno en todos los pares de funciones.

---

## Fase 2: Robustez Adversaria y Pruebas de Mutación (En Desarrollo)

**Objetivo:** Demostrar que Vetro es inmune a cambios estéticos y técnicas de ofuscación de código comúnmente aplicadas por las LLMs (como el renombrado de variables y reordenamiento menor).

### Diseño del Experimento
1. **Mutación Sistemática:** Tomar un corpus de funciones del proyecto y generar automáticamente versiones mutadas de las mismas aplicando:
   * Cambios en la nomenclatura de variables locales y parámetros (renombrado aleatorio).
   * Conversión de literales duros a variables constantes.
   * Modificaciones cosméticas del tipo de bucle (por ejemplo, convertir `for` clásico a `for-in` o `forEach`).
2. **Evaluación de Resistencia:** Medir la similitud estructural de AST calculada por Vetro entre la función original y cada una de sus 10 mutaciones adversarias.
3. **Criterio de Aceptación:** La similitud semántica reportada por Vetro debe mantenerse en $\ge 80\%$ a pesar del renombrado de variables y las alteraciones estructurales menores.

---

## Fase 3: Precisión, Cobertura y Matriz de Confusión (Planificado)

**Objetivo:** Demostrar la viabilidad comercial midiendo la tasa de falsos positivos (falsas alarmas que molestan a los desarrolladores) y falsos negativos (deuda técnica real de IA que Vetro no detecta).

### Diseño del Experimento
* **Dataset de Control:** Se compilará un dataset con 200 funciones escritas bajo condiciones de laboratorio:
  * 50 funciones escritas por desarrolladores senior calificados (código de alta calidad).
  * 50 funciones con deuda técnica tradicional severa (anidamiento humano extremo).
  * 50 funciones generadas por asistentes de IA (limpias y documentadas).
  * 50 funciones generadas por asistentes de IA con deuda técnica inducida (abstracciones vacías, duplicación encubierta, lógica redundante).
* **Medición:** Ejecución de Vetro en el dataset de control y clasificación en una matriz de confusión para calcular:
  * **Precision (Confiabilidad de alertas):** Objetivo $\ge 92\%$.
  * **Recall (Capacidad de detección):** Objetivo $\ge 88\%$.
  * **F1-Score:** Objetivo $\ge 90\%$.

---

## Fase 4: Correlación con el Juicio de Expertos Humanos (Planificado)

**Objetivo:** Validar que el algoritmo compuesto del **AI Debt Score** mide de forma cuantitativa la misma percepción de calidad que tienen los desarrolladores experimentados.

### Diseño del Experimento
* **Evaluación Doble Ciego:**
  * Un panel de 3 ingenieros de software senior independientes evaluará y calificará de forma manual la mantenibilidad y legibilidad de 50 archivos de código en una escala de 0 a 100.
  * De forma paralela y a ciegas, se correrá Vetro sobre los mismos 50 archivos para calcular el *AI Debt Score*.
* **Cálculo de Correlación:**
  * Se calculará el coeficiente de correlación de Spearman ($r_s$) entre las calificaciones promedio de los expertos y el AI Debt Score.
  * **Criterio de Validación:** Se considerará validado científicamente si $r_s \ge 0.80$ con un valor de significancia estadística $p < 0.01$, demostrando que Vetro es un estimador estadísticamente significativo y fiable del juicio de ingeniería humana.
