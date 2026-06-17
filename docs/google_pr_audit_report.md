# Vetro — Pull Request Audit on Google's package:http (PR #1773)

Este reporte detalla el análisis de auditoría estática automatizada realizado con **Vetro** sobre el repositorio oficial del equipo de Dart en Google: **[dart-lang/http](https://github.com/dart-lang/http)**.

Analizamos el **Pull Request #1773** (commit `a4f5a8d`), una contribución robusta que implementa el **soporte para abortar y cancelar peticiones HTTP** (`aborting HTTP requests`) a través de un nuevo componente `lib/src/abortable.dart` e integraciones en los clientes de entrada/salida (IO, Browser, Retry).

---

## 🧪 Ficha Técnica del Experimento

| Variable | Detalle |
| :--- | :--- |
| **Repositorio Objetivo** | [dart-lang/http (Google)](https://github.com/dart-lang/http) |
| **Pull Request Evaluado** | **PR #1773** (feat: support aborting HTTP requests) |
| **Commit Baseline (Antes)** | `7d2d87e` |
| **Commit Target (Después)** | `a4f5a8d` |
| **Métricas Generales** | 27 archivos, 2,697 líneas de código (en Target) |
| **Tiempo de Análisis** | **0.05 segundos** (50 ms en local) |
| **Costo de Tokens** | **$0.00 USD (0 tokens)** |

---

## 📊 Tabla Comparativa de Métricas

La mezcla del PR impactó las métricas globales de la siguiente manera:

| Métrica | Commit Baseline (`7d2d87e`) | Commit Target (`a4f5a8d`) | Variación |
| :--- | :---: | :---: | :---: |
| **Archivos Analizados** | 26 | 27 | **+1** (Adición de `abortable.dart`) |
| **Líneas de Código** | 2,491 | 2,697 | **+206** líneas |
| **AI Debt Score** | **73/100** | **71/100** | 🔴 **-2 puntos** (Ligera degradación) |
| **Warnings de Acoplamiento** | 10 | 11 | **+1** |
| **Warnings de Cohesión** | 1 | 0 | **-1** (Resolución de cohesion) |

---

## 🔍 Hallazgos de la Auditoría A/B

Mediante la comparación normalizada de los reportes JSON generados por Vetro, extrajimos las advertencias estructurales resueltas e introducidas por este Pull Request:

### ✅ Alertas Resueltas por el PR

El refactor resolvió con éxito las siguientes advertencias de mantenibilidad:

1. **Mejora en Cohesión (`low_cohesion`)**:
   - `RetryClient` en [retry.dart](file:///home/dimas/development/Vetro/scratch/http/pkgs/http/lib/retry.dart) (línea 12) tenía una cohesión semántica crítica del **15.0%**. Con el rediseño para soportar cancelación, se introdujeron miembros y dependencias semánticas afines, lo que **aumentó su cohesión por encima del umbral de advertencia**.
2. **Ciclos de Dependencia Simplificados (`circular_dependency`)**:
   - Se disolvió el ciclo directo de 4 archivos: `base_client.dart -> base_request.dart -> base_response.dart -> client.dart -> base_client.dart` gracias a la reorganización de firmas de métodos en la llamada a `send`.

---

### ⚠️ Nuevas Alertas Introducidas por el PR

La adición de la funcionalidad de cancelación introdujo deuda técnica estructural sutil en el diseño de las dependencias:

1. **Introducción de Dependencias Circulares (`circular_dependency`)**:
   Al crear la abstracción [abortable.dart](file:///home/dimas/development/Vetro/scratch/http/pkgs/http/lib/src/abortable.dart), esta se acopló de manera bidireccional con las peticiones y respuestas base, generando **6 nuevos ciclos cerrados**:
   - `abortable.dart -> base_request.dart -> abortable.dart` (Ciclo directo de longitud 2).
   - `abortable.dart -> streamed_response.dart -> base_response.dart -> base_request.dart -> abortable.dart` (Ciclo de longitud 4).
   - `abortable.dart -> streamed_response.dart -> base_response.dart -> client.dart -> base_client.dart -> base_request.dart -> abortable.dart` (Ciclo de longitud 6).

2. **Acoplamiento de la Nueva Abstracción (`tight_coupling`)**:
   - El archivo [abortable.dart](file:///home/dimas/development/Vetro/scratch/http/pkgs/http/lib/src/abortable.dart) nació con una tasa de acoplamiento del **37.0%** (`fan-in: 6, fan-out: 4`), convirtiéndose inmediatamente en un nodo altamente acoplado dentro de la arquitectura interna de la librería.

---

## 💡 Análisis de Arquitectura y Conclusiones

> [!WARNING]
> **Evaluación del Diseño de Cancelación:**
> El soporte para abortar peticiones es una característica fundamental, pero la manera en que se acopla con el ciclo de vida de la petición (`base_request.dart`) y del cliente (`base_client.dart`) ha creado un grafo de dependencias cíclico.
>
> Para solucionar esto en una fase futura de package:http, se recomienda:
> 1. Invertir las dependencias definiendo un canal de cancelación pasivo (ej. un `Stream` o un `ChangeNotifier` simple) en lugar de importar clases concretas directamente en `abortable.dart`.
> 2. Mover la verificación del estado de cancelación fuera de la lógica interna de respuesta del cliente.

### 🚀 Conclusión sobre la Utilidad de Vetro

Este experimento demuestra la **utilidad crítica de Vetro en librerías de infraestructura** como `package:http`:
- **Auditoría instantánea**: Ejecutar el análisis completo sobre el código base de Google tomó solo **50 milisegundos**.
- **Detector de Acoplamiento Cíclico**: Un revisor humano de Pull Requests difícilmente habría notado que la adición de `abortable.dart` generó 6 ciclos de dependencia indirecta a través de los clientes y las respuestas base. Vetro lo detectó al instante, permitiendo a los mantenedores tomar decisiones informadas antes de mezclar código en `master`.
