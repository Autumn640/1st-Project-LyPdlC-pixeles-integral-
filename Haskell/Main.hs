module Main where

import qualified Data.ByteString as BS --  Este bloque declara la parte principal del programa y carga las herramientas que vamos a necesitar. 
import Data.ByteString (ByteString)    --  Nos ayuda a leer la información en binario, procesar el texto de la cabecera del archivo PBM, 
import Data.Char (isSpace, chr)        --  realizar operaciones con los bits y mostrar los resultados de manera ordenada en la pantalla.
import Data.Bits (testBit)
import Text.Printf (printf)
import System.IO (hSetEncoding, stdout, utf8)

-- ============================================================================
-- ESTRUCTURAS DE DATOS Y TIPOS
-- ============================================================================

-- Este bloque define la estructura de datos de la imagen, la cual funciona como un contenedor para almacenar la información esencial de la imagen PBM P4
-- una vez procesada: su ancho y alto en píxeles y el bloque binario con los datos ráster de la imagen (cuadrícula regular de píxeles)

data ImagePBM = ImagePBM
  { imgWidth  :: Int
  , imgHeight :: Int
  , imgRaster :: ByteString
  } deriving (Show)

-- ============================================================================
-- 1. LECTURA Y PARSEO DEL ARCHIVO PBM P4 (Binario)
-- ============================================================================

-- Este bloque se encarga de limpiar y saltar los espacios en blanco y los comentarios dentro de la cabecera del archivo PBM, 
-- su función es avanzar en la lectura del archivo byte por byte hasta encontrar el siguiente dato válido

skipHeaderWhitespace :: ByteString -> ByteString
skipHeaderWhitespace bs
  | BS.null bs = BS.empty
  | isSpace w  = skipHeaderWhitespace (BS.tail bs)
  | w == '#'   = skipHeaderWhitespace (skipLine bs) -- Comparación directa con Char '#'
  | otherwise  = bs
  where
    w = chr (fromIntegral (BS.head bs))
    skipLine b
      | BS.null b = BS.empty
      | BS.head b == 10 || BS.head b == 13 = BS.tail b -- Newline o CR
      | otherwise = skipLine (BS.tail b)

-- Este bloque se encarga de extraer y convertir un número entero escrito en ASCII (representado como texto) a un valor numérico, 
-- lee los caracteres numéricos de la cabecera (como el ancho o el alto de la imagen) y devuelve tanto el número procesado como el resto del archivo sin leer.  

readIntToken :: ByteString -> (Int, ByteString)
readIntToken bs =
  let cleanBs = skipHeaderWhitespace bs
      (digits, rest) = BS.span isDigitByte cleanBs
      val = foldl (\acc w -> acc * 10 + fromIntegral (w - 48)) 0 (BS.unpack digits)
  in (val, rest)
  where
    isDigitByte w = w >= 48 && w <= 57

-- Esta parte del código se encarga de leer la primera parte (la cabecera) de un archivo PBM P4, revisa que el archivo sí sea un "P4" válido, 
-- saca las medidas de ancho y alto de la imagen, separa los datos de los píxeles (el contenido binario) y guarda todo junto en una sola estructura para poder usarlo después.

parsePBM :: ByteString -> ImagePBM
parsePBM bs =
  let bs1 = skipHeaderWhitespace bs
      magic = BS.take 2 bs1
      bs2   = BS.drop 2 bs1
      _     = if magic /= BS.pack [80, 52] then error "El archivo no es formato PBM P4" else ()
      (width, bs3)  = readIntToken bs2
      (height, bs4) = readIntToken bs3
      -- Limpiamos posibles espacios residuales de la cabecera hasta dar con el delimitador
      bs5           = skipHeaderWhitespace bs4
      -- El último token de la cabecera termina y los datos binarios empiezan exactamente
      -- tras dropping el carácter separador único (ej. '\n') o tomando los últimos (width * height) bytes.
      expectedBytes = bytesPerRow width * height
      rasterData    = BS.drop (BS.length bs5 - expectedBytes) bs5
  in ImagePBM width height rasterData

-- ============================================================================
-- 2. ACCESO A PÍXELES INDIVIDUALES
-- ============================================================================

-- Este bloque calcula la cantidad exacta de bytes necesaria para almacenar una fila completa de píxeles en memoria, incluyendo el relleno (padding), 
-- como cada byte guarda 8 píxeles, la fórmula (width + 7) ÷ 8 redondea hacia arriba para asegurarse de incluir un byte extra completo si el ancho no es múltiplo de 8.

bytesPerRow :: Int -> Int
bytesPerRow width = (width + 7) `div` 8

-- Este bloque determina si un píxel en las coordenadas (x, y) es negro o blanco, comprobando primero si la coordenada está dentro de la imagen, 
-- calculando la ubicación exacta del byte y bit correspondientes en el bloque binario ráster, y retornando True si el píxel es negro (bit 1) o False si es blanco (bit 0).

getPixel :: ImagePBM -> Int -> Int -> Bool
getPixel img x y
  | x < 0 || x >= imgWidth img || y < 0 || y >= imgHeight img = False
  | otherwise =
      let rowBytes = bytesPerRow (imgWidth img)
          byteIndex = y * rowBytes + (x `div` 8)
          bitIndex  = 7 - (x `mod` 8)
          byte      = BS.index (imgRaster img) byteIndex
      in testBit byte bitIndex

-- ============================================================================
-- 3. CONSTRUCCIÓN DE LA FUNCIÓN f(x)
-- ============================================================================

-- Este bloque calcula la altura f(x) de la curva en una columna x, recorriendo la imagen verticalmente de abajo hacia arriba para contar cuántos 
-- píxeles negros consecutivos existen antes de encontrar el primer píxel blanco o llegar al borde superior.

f :: ImagePBM -> Int -> Int
f img x = countFromBottom (imgHeight img - 1)
  where
    countFromBottom y
      | y < 0                    = 0
      | getPixel img x y == True = 1 + countFromBottom (y - 1)
      | otherwise                = 0

-- ============================================================================
-- 4 & 5. ESTRUCTURA DE ALTURAS M Y CÁLCULO DEL ÁREA (Suma de Riemann)
-- ============================================================================

-- Este bloque genera la lista de alturas de la curva para toda la imagen, aplicando la función f(x) a cada una de las columnas 
-- desde la posición 0 hasta el ancho total menos uno.

buildHeights :: ImagePBM -> [Int]
buildHeights img = map (f img) [0 .. imgWidth img - 1]

-- Este bloque calcula el área total bajo la curva sumando la lista de alturas de todas las columnas 
-- (lo que equivale a aplicar una Suma de Riemann con rectángulos de ancho 1).

calculateArea :: [Int] -> Int
calculateArea heights = sum heights

-- ============================================================================
-- 6 & 7. VISUALIZACIÓN EN CONSOLA 
-- ============================================================================

-- Esta parte se encarga de dibujar la gráfica en la consola con el tamaño deseado (targetWidth y targetHeight), 
-- ajusta la altura de los datos para que quepan en la pantalla, llena la figura usando caracteres █ para el área pintada y espacios para el fondo,
-- y al final le pone un marco con +, - y | alrededor para que se vea ordenada.

drawConsoleView :: ImagePBM -> [Int] -> Int -> Int -> IO ()
drawConsoleView img heights targetWidth targetHeight = do
  let w = imgWidth img
      h = imgHeight img
      xScale = fromIntegral w / fromIntegral targetWidth :: Double
      yScale = fromIntegral h / fromIntegral targetHeight :: Double

      sampledHeights = [ heights !! min (w - 1) (floor (fromIntegral col * xScale)) | col <- [0 .. targetWidth - 1] ]

      renderRow r =
        let rowThreshold = floor (fromIntegral (targetHeight - r) * yScale)
        in [ if alt >= rowThreshold then '█' else ' ' | alt <- sampledHeights ]

  putStrLn $ "+" ++ replicate targetWidth '-' ++ "+"
  mapM_ (\r -> putStrLn $ "|" ++ renderRow r ++ "|") [1 .. targetHeight]
  putStrLn $ "+" ++ replicate targetWidth '-' ++ "+"

-- ============================================================================
-- 8. MOSTRAR VALORES DE MUESTRA x_i -> f(x_i)
-- ============================================================================
-- Este bloque imprime en pantalla una muestra de 10 puntos de la curva: calcula 10 posiciones x_i distribuidas equitativamente a lo largo del ancho de la imagen y 
-- muestra en formato legible cada coordenada junto a su respectiva altura calculada f(x_i).

showSampleValues :: ImagePBM -> [Int] -> IO ()
showSampleValues img heights = do
  let w = imgWidth img
      indices = [ floor (fromIntegral i * fromIntegral (w - 1) / 9.0) | i <- [0 .. 9] :: [Int] ]
      sampleIndices = [0 .. 9] :: [Int]
  putStrLn "\nALGUNOS VALORES x_i -> f(x_i):"
  mapM_ (\(i, idx) -> printf "  x_%d = %4d  ->  f(x_%d) = %3d píxeles\n" (i :: Int) idx (i :: Int) (heights !! idx)) (zip sampleIndices indices)

-- ============================================================================
-- FUNCIÓN PRINCIPAL MAIN
-- ============================================================================
-- Este bloque guarda la ruta de la imagen (curva_binaria_P4.pbm) en la variable filePath para que después la función BS.readFile pueda abrir el archivo.

main :: IO ()
main = do
  hSetEncoding stdout utf8
  let filePath = "curva_binaria_P4.pbm"
  
  -- 1. Este bloque lee el archivo de imagen en formato binario (ByteString) desde la ruta especificada, lo procesa llamando a parsePBM para construir el objeto ImagePBM
  -- e imprime en la consola un encabezado de presentación junto con las dimensiones (ancho y alto) de la imagen cargada.

  contents <- BS.readFile filePath
  let img = parsePBM contents

  putStrLn "================================================="
  putStrLn "   PRÁCTICA I: DE LOS PÍXELES A LA INTEGRAL     "
  putStrLn "          Solución Funcional en Haskell         "
  putStrLn "================================================="
  printf "Imagen cargada: %d x %d píxeles\n\n" (imgWidth img) (imgHeight img)

  -- 4. Esta línea calcula la altura de todas las columnas de la imagen, llama a la función buildHeights con los datos de la imagen (img) 
  -- y guarda la lista de alturas resultante en la variable m.

  let m = buildHeights img

  -- 5. Esta línea calcula el área total sombreada bajo la curva, llamando a la función calculateArea con la lista de alturas m previamente obtenida 
  -- y asignando el valor entero resultante a la variable area.

  let area = calculateArea m

  -- 6 & 7. Esta parte imprime el título de la gráfica en la pantalla y llama a drawConsoleView pasándole la imagen, 
  -- las alturas m y una cuadrícula de 70 columnas por 20 filas para dibujar la figura en ASCII.

  putStrLn "REPRESENTACIÓN DE LA CURVA EN CONSOLA (Escalada):"
  drawConsoleView img m 70 20

  -- 8. Mostrar valores de muestra

  showSampleValues img m

-- Este bloque muestra en la consola el resumen del área calculada: imprime unas líneas separadoras, 
-- explica que cada columna mide 1 píxel de ancho (por lo que el área es solo sumar las alturas) y muestra el resultado final en píxeles cuadrados.

  putStrLn "\n-------------------------------------------------"
  printf "Cada columna tiene base dx = 1 píxel\n"
  printf "Área = suma de f(x_i)\n"
  printf "ÁREA TOTAL CALCULADA: %d píxeles cuadrados\n" area
  putStrLn "-------------------------------------------------"