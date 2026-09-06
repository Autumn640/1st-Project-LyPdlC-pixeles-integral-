# Practice I — From Pixels to the Integral (Haskell & Prolog)

**Curso:** ST0244 - Programming Languages Programming
**Universidad:** EAFIT
**Profesor:** Alexander Narváez Berrío

## Integrantes del equipo

- Nombre 1
- Nombre 2
- (agregar los nombres completos de todo el equipo)

## Entorno de desarrollo

- **Haskell:** GHC 9.4.x (probado también con `runghc`). Sin dependencias externas más allá de las que vienen con GHC (`bytestring`, `Text.Printf`, `System.IO`).
- **Prolog:** SWI-Prolog 9.x.
- **Sistema operativo de prueba:** Linux (Ubuntu). También debería funcionar en Windows/macOS con GHC y SWI-Prolog instalados.

## Cómo ejecutar la solución en Haskell

Desde la carpeta `Haskell/` (el archivo `curva_binaria_P4.pbm` debe estar en el mismo directorio desde el que se ejecuta el programa, o se debe copiar ahí):

```bash
cd Haskell
cp ../curva_binaria_P4.pbm .
ghc -O2 -o programa Main.hs
./programa
```

También se puede ejecutar sin compilar, con:

```bash
runghc Main.hs
```

## Cómo ejecutar la solución en Prolog

Desde la carpeta `Prolog/` (copiando también el `.pbm` junto al script, o pasando la ruta como argumento):

```bash
cd Prolog
cp ../curva_binaria_P4.pbm .
swipl curva.pl
```

Si el archivo `.pbm` está en otra ubicación:

```bash
swipl curva.pl -- /ruta/al/curva_binaria_P4.pbm
```

## Estrategia para mostrar la imagen en consola

La imagen original (567×319 píxeles) es mucho más grande que una terminal típica, así que ambas soluciones **muestrean columnas** en lugar de recorrer pixel por pixel:

- Se toma una columna cada `ancho / ancho_visual` posiciones (por ejemplo, cada ~8 columnas para reducir 567 a ~70-100 columnas de terminal).
- La altura `f(x)` de cada columna muestreada se **reescala proporcionalmente** al número de filas disponibles en la terminal (`altura_escalada = f(x) * filas_terminal / alto_original`).
- Se dibuja de arriba hacia abajo: en cada fila visual se pinta el carácter de "relleno" si la altura escalada de esa columna alcanza esa fila, y espacio en caso contrario.

Esto preserva la forma general de la curva sin necesitar imprimir los 567×319 píxeles reales. Adicionalmente, la solución en Prolog incluye una segunda visualización tipo "sparkline" de `M[x]` usando caracteres ASCII de densidad creciente (` .:-=+*#`).

## Área obtenida

Con el archivo `curva_binaria_P4.pbm` suministrado (567 × 319 píxeles):

```
ÁREA = 108660 píxeles cuadrados
```

Este valor coincide exactamente entre la implementación en Haskell y la implementación en Prolog, y también coincide con el ejemplo de referencia en C++ del enunciado — la validación cruzada que pide la práctica.

## Comparación de paradigmas (resumen)

- **Haskell (funcional):** el problema se expresa como una cadena de transformaciones sobre datos: `M = map f [0..ancho-1]` y `área = sum M`. El énfasis está en funciones puras que transforman una lista de entrada en una de salida.
- **Prolog (lógico/declarativo):** el problema se expresa como relaciones: `f(X, ..., Altura)` describe qué relación debe cumplirse entre una columna y su altura, y `findall/3` le pide al motor de Prolog que encuentre todos los valores que la satisfacen (`M`), para luego sumarlos con `sum_list/2`. El énfasis está en **qué debe cumplirse**, no en el orden de ejecución.
