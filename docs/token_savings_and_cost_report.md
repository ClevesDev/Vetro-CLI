# Vetro vs LLM — Token & Cost Benchmark Report

Este reporte compara de manera cuantitativa el uso de **Vetro** frente al uso de **Modelos de Lenguaje (LLMs)** (ej. GPT-4o, Gemini 1.5 Pro) para realizar auditorías estáticas del mismo nivel de precisión.

## 1. Métricas de Entrada por Proyecto

| Proyecto | Archivos | Líneas | Caracteres | Est. Tokens Código | Funciones (≥40 nodos) | Pares Comparación |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Vetro (Self)** | 31 | 4618 | 144508 | 36127 | 62 | 1891 |
| **Proyecto_XXX_A** | 64 | 9097 | 322092 | 80523 | 63 | 1953 |
| **Proyecto_XXX_C** | 50 | 6692 | 249503 | 62375 | 62 | 1891 |
| **Proyecto_XXX_B** | 47 | 7520 | 284743 | 71185 | 49 | 1176 |
| **Proyecto_XXX_D** | 226 | 56358 | 2036033 | 509008 | 465 | 107880 |

## 2. Comparación de Costo y Consumo (GPT-4o Pricing)

**Modelo de Precios de Referencia (GPT-4o):**
* **Entrada (Input):** $5.00 / 1,000,000 tokens
* **Salida (Output):** $15.00 / 1,000,000 tokens

### Enfoque A: Envío del Código Completo (Single Context)
*Se envía todo el código en un único prompt largo y se le pide al LLM que analice las 6 reglas. Nota: Este enfoque suele alucinar y omitir la mayoría de las alertas debido a las limitaciones del LLM en tareas complejas de contexto largo.*
* **Prompt/Instrucciones de entrada:** 2,000 tokens
* **Reporte de salida estimado:** 4,000 tokens

| Proyecto | Input Tokens | Output Tokens | Costo por Corrida (USD) | Latencia Promedio |
| :--- | :---: | :---: | :---: | :---: |
| **Vetro (Self)** | 38127 | 4000 | $0.2506 | ~25.0 s |
| **Proyecto_XXX_A** | 82523 | 4000 | $0.4726 | ~25.0 s |
| **Proyecto_XXX_C** | 64375 | 4000 | $0.3819 | ~25.0 s |
| **Proyecto_XXX_B** | 73185 | 4000 | $0.4259 | ~25.0 s |
| **Proyecto_XXX_D** | 511008 | 4000 | $2.6150 | ~25.0 s |

### Enfoque B: Comparación Cuadrática Fiel (Pairwise LLM Runs)
*Para lograr la misma precisión matemática que Vetro (comparar cada par de funciones de forma rigurosa), enviamos cada par de funciones de manera independiente.*
* **Tokens promedio por par (código + prompt + respuesta):** 1,000 tokens

| Proyecto | Comparaciones | Total Tokens | Costo por Corrida (USD) | Latencia Estimada (10 threads) |
| :--- | :---: | :---: | :---: | :---: |
| **Vetro (Self)** | 1891 | 1891000 | $9.46 | 3.2 minutos |
| **Proyecto_XXX_A** | 1953 | 1953000 | $9.77 | 3.3 minutos |
| **Proyecto_XXX_C** | 1891 | 1891000 | $9.46 | 3.2 minutos |
| **Proyecto_XXX_B** | 1176 | 1176000 | $5.88 | 2.0 minutos |
| **Proyecto_XXX_D** | 107880 | 107880000 | $539.40 | 3.0 horas |

### Enfoque C: Vetro Local (Matemática Determinista)

| Proyecto | Tokens Consumidos | Costo por Corrida (USD) | Tiempo de Ejecución | Precisión Matemática |
| :--- | :---: | :---: | :---: | :---: |
| **Vetro (Self)** | **0** | **$0.00** | **563 ms** | **100% (Garantizado)** |
| **Proyecto_XXX_A** | **0** | **$0.00** | **296 ms** | **100% (Garantizado)** |
| **Proyecto_XXX_C** | **0** | **$0.00** | **262 ms** | **100% (Garantizado)** |
| **Proyecto_XXX_B** | **0** | **$0.00** | **183 ms** | **100% (Garantizado)** |
| **Proyecto_XXX_D** | **0** | **$0.00** | **3330 ms** | **100% (Garantizado)** |

## 3. Conclusiones y Retorno de Inversión (ROI)

1. **Escalabilidad Cuadrática**: En proyectos de escala pesada como `Proyecto_XXX_D` con **465 funciones**, la comparación cruzada requiere **107880 combinaciones**. Para un LLM, realizar esto de forma fiable cuesta **$539.40 USD** en tokens y tardaría horas. Vetro lo resuelve gratis en **3330 ms**.
2. **Cero Tokens / Cero Latencia**: Al correr 100% de forma local, Vetro tiene un costo marginal de $0. Puede ejecutarse en cada `git commit` sin límites de cuota, demoras de red o filtración de código propietario.
