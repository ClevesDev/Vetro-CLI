# Vetro — Reporte de Análisis de Proyectos Locales

Este documento presenta los resultados de los análisis estáticos realizados por **Vetro** sobre los codebases locales del usuario y su propio autodiagnóstico.

---

## 📊 Tabla Comparativa de Resultados

| Proyecto | Archivos Analizados | Líneas de Código | AI Debt Score | Diagnóstico de Calidad |
| :--- | :---: | :---: | :---: | :---: |
| **Vetro** (Google Agent) | 30 | 4,568 | **100/100** | ✅ Excelente (Código Impecable) |
| **Proyecto_XXX_A** | 63 | 8,933 | **79/100** | ⚠️ Advertencia (Deuda Moderada) |
| **Proyecto_XXX_B** | 46 | 7,462 | **79/100** | ⚠️ Advertencia (Deuda Moderada) |
| **Proyecto_XXX_C** | 48 | 6,641 | **76/100** | ⚠️ Advertencia (Deuda Moderada) |
| **Proyecto_XXX_D** | 225 | 56,287 | **33/100** | 🔴 Crítico (Deuda Extrema / Zombie) |

---

## 🔍 Detalles por Proyecto

### 1. 🛡️ Vetro (Autodiagnóstico)
* **Score**: `100/100`
* **Estado**: Completamente limpio de advertencias y violaciones.
* **Aspectos Destacados**:
  * Cumple estrictamente con la ley de simetría e identidad de similitud coseno.
  * La distribución de tipos de nodos AST se mantiene en niveles de entropía saludables, demostrando una variabilidad y estructuración ideal (evitando la chatarra reiterativa típica de las IAs).
  * La regla de **Circular Dependency** y la nueva de **Boundary Violation** de Clean Architecture verifican que el grafo de dependencias de Vetro fluye limpiamente sin ciclos ni fugas entre lib/core, lib/analyzers y lib/cli.

---

### 2. 📖 Proyecto_XXX_A
* **Score**: `79/100`
* **Métricas Principales**:
  * **Circular Dependency**: 4 advertencias.
  * **Tight Coupling**: 2 advertencias.
  * **Low Cohesion**: 8 advertencias.
  * **Halstead Complexity**: 27 funciones excedidas.
  * **Copy-Mutate / Semantic Duplication**: 22 patrones de similitud.
* **Focos de Deuda**:
  * Ciclos de dependencia directa bidireccional entre la base de datos central y los DAOs individuales (ej. `app_database.dart` $\leftrightarrow$ `bible_dao.dart` / `notes_dao.dart` / `cosmetics_dao.dart`).
  * Alto acoplamiento en `app_skin.dart` ($44.4\%$) y centralidad PageRank de $0.743$, convirtiéndolo en un cuello de botella global del diseño del tema.
  * Duplicaciones estructurales de hasta $98\%$ en los métodos reactivos de `bible_dao.dart` y en los diálogos de `purchase_dialogs.dart`.

---

### 3. 🏫 Proyecto_XXX_B
* **Score**: `79/100`
* **Métricas Principales**:
  * **Low Cohesion**: 11 advertencias.
  * **Tight Coupling**: 6 advertencias.
  * **Copy-Mutate Pattern**: 20 advertencias.
  * **Halstead Complexity**: 24 funciones excedidas.
  * **Semantic Duplication**: 5 advertencias.
* **Focos de Deuda**:
  * Clases como `AppDatabase` y formateadores de tickets (`TicketFormatter`) tienen cohesión semántica crítica (menor al $12\%$).
  * Duplicación semántica muy alta en la pantalla de ajustes (`ajustes_view.dart`) con un $98.0\%$ de similitud entre métodos de creación de modelos (`_crearTorneo` vs `_crearCategoria`).
  * Estructuras de widgets sumamente pesadas en `registrar_atleta_form.dart` y `ajustes_view.dart` (esfuerzo Halstead sobrepasando $400,000$).

---

### 4. 🗺️ Proyecto_XXX_C
* **Score**: `76/100`
* **Métricas Principales**:
  * **Tight Coupling**: 2 advertencias.
  * **Circular Dependency**: 1 advertencia.
  * **Low Cohesion**: 7 clases críticas.
  * **Copy-Mutate**: 22 advertencias.
  * **Semantic Duplication**: 17 advertencias.
  * **Syntax Error**: 1 archivo con error de compilación.
* **Focos de Deuda**:
  * **Error de Análisis Estático Crítico:** El archivo `lib/features/packages/presentation/screens/store_wallet_screen.dart` posee un error sintáctico por falta de un cierre de paréntesis `)` en la línea 422, impidiendo su parsing correcto.
  * **Acoplamiento de Vista:** `routes_dashboard_screen.dart` tiene una tasa de acoplamiento del $27.7\%$ (depende directamente de 12 clases/servicios).
  * **Complejidad Cognitiva:** Métodos de visualización de mapas y rendering (`_buildRoutesMonitoringCard`) acumulan una complejidad ciclomática de $16$ y un esfuerzo Halstead gigante de $729,295.5$.

---

### 🧟 5. Proyecto_XXX_D
* **Score**: `33/100`
* **Métricas Principales**:
  * **Copy-Mutate / Semantic Duplication**: Más de 1500 alertas combinadas de clonado.
  * **Halstead Complexity**: 185 funciones con esfuerzo masivo.
  * **Intent Gap**: 324 métodos complejos sin documentación de intención.
  * **Circular Dependency**: 3 ciclos de dependencia global.
* **Focos de Deuda**:
  * Duplicación masiva en proveedores de negocio (ej. `FinanceService.addCustomer` y `RetailManager.addProduct` son idénticos al $100\%$).
  * La base de datos central `database.dart` posee un acoplamiento estrecho del $36.0\%$ y una centralidad de PageRank del $0.482$, lo que significa que un cambio en este archivo impacta en cascada a casi todo el software de la empresa.

---

> [!TIP]
> **Recomendación General**:
> 1. Para **Proyecto_XXX_C**, resolver prioritariamente el error sintáctico de `store_wallet_screen.dart`.
> 2. Para **Proyecto_XXX_A** y **Proyecto_XXX_B**, implementar una inyección de dependencias modular o interfaces intermedias para romper las referencias circulares bidireccionales con la base de datos central (`app_database.dart`).
> 3. Para **Proyecto_XXX_D**, se sugiere una refactorización masiva por fases (comenzando por modularizar la lógica de negocio y eliminar duplicaciones de raíz en los `providers`).
