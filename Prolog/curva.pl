% ============================================================
% ST0244 - Practica I: Del pixel a la integral
% Parte II - PROLOG
% Autor: (completar con nombres del equipo)
%
% Enfoque: el problema se expresa como un conjunto de RELACIONES
% (imagen, columna X, altura) y (imagen, area), no como una
% secuencia de instrucciones. Prolog se limita a encontrar los
% valores que satisfacen esas relaciones (findall/3, sum_list/2).
% ============================================================

:- initialization(main).

% ------------------------------------------------------------
% 1. LECTURA DEL ARCHIVO PBM P4
% ------------------------------------------------------------
% leer_pbm(+Archivo, -Ancho, -Alto, -BytesPorFila, -Pixeles)
% Relaciona un nombre de archivo con el ancho, alto, bytes por
% fila y una cadena de bytes (Pixeles) que representa el cuerpo
% binario de la imagen (sin la cabecera de texto).
leer_pbm(Archivo, Ancho, Alto, BytesPorFila, Pixeles) :-
    read_file_to_codes(Archivo, Codigos, [encoding(octet)]),
    parsear_cabecera(Codigos, Ancho, Alto, CodigosPixeles),
    BytesPorFila is (Ancho + 7) // 8,
    string_codes(Pixeles, CodigosPixeles).

% parsear_cabecera(+Codigos, -Ancho, -Alto, -ResPixeles)
% La cabecera P4 tiene la forma:  "P4" <ws> Ancho <ws> Alto <ws> <datos binarios>
% con posibles comentarios "# ..." que se ignoran hasta el fin de linea.
parsear_cabecera(Codigos, Ancho, Alto, ResPixeles) :-
    Codigos = [0'P, 0'4 | Resto0],
    saltar_espacios_comentarios(Resto0, Resto1),
    leer_numero(Resto1, Ancho, Resto2),
    saltar_espacios_comentarios(Resto2, Resto3),
    leer_numero(Resto3, Alto, Resto4),
    Resto4 = [_UnSeparador | ResPixeles].

saltar_espacios_comentarios([C|Cs], R) :-
    code_type(C, space), !,
    saltar_espacios_comentarios(Cs, R).
saltar_espacios_comentarios([0'#|Cs], R) :-
    !, saltar_hasta_nl(Cs, Cs1), saltar_espacios_comentarios(Cs1, R).
saltar_espacios_comentarios(Cs, Cs).

saltar_hasta_nl([0'\n|Cs], Cs) :- !.
saltar_hasta_nl([_|Cs], R) :- saltar_hasta_nl(Cs, R).

leer_numero(Cs, Numero, Resto) :-
    leer_digitos(Cs, Digitos, Resto),
    number_codes(Numero, Digitos).

leer_digitos([C|Cs], [C|Ds], Resto) :-
    code_type(C, digit), !,
    leer_digitos(Cs, Ds, Resto).
leer_digitos(Cs, [], Cs).

% ------------------------------------------------------------
% 2. ACCESO A PIXELES INDIVIDUALES
% ------------------------------------------------------------
% pixel(+X, +Y, +Pixeles, +BytesPorFila, -Valor)
% Relaciona una coordenada (X,Y) con su valor de bit (0 o 1).
% Cada byte empaqueta 8 pixeles; el bit mas significativo es el
% pixel mas a la izquierda del grupo de 8.
pixel(X, Y, Pixeles, BytesPorFila, Valor) :-
    IndiceByte is Y*BytesPorFila + X//8,
    byte_en(IndiceByte, Pixeles, Byte),
    Bit is 7 - (X mod 8),
    Valor is (Byte >> Bit) /\ 1.

% byte_en(+Indice, +Pixeles, -Byte)  -- indice base 0
byte_en(Indice, Pixeles, Byte) :-
    Indice1 is Indice + 1,
    string_code(Indice1, Pixeles, Byte).

% ------------------------------------------------------------
% 3. LA FUNCION DISCRETA f(X)
% ------------------------------------------------------------
% f(+X, +Pixeles, +Alto, +BytesPorFila, -Altura)
% Relaciona una columna X con su altura: el numero de pixeles
% negros (1) consecutivos contados desde la ULTIMA fila hacia
% arriba, hasta encontrar el primer pixel blanco (0).
f(X, Pixeles, Alto, BytesPorFila, Altura) :-
    YInicial is Alto - 1,
    contar_negros(X, YInicial, Pixeles, BytesPorFila, Altura).

% contar_negros(+X, +Y, +Pixeles, +BytesPorFila, -Altura)
% Relacion recursiva: si Y es negativo ya no hay mas fila que
% revisar. Si el pixel es negro, la altura es 1 mas la altura
% del resto de la columna hacia arriba; si es blanco, se detiene.
contar_negros(_X, Y, _Pixeles, _BytesPorFila, 0) :-
    Y < 0, !.
contar_negros(X, Y, Pixeles, BytesPorFila, Altura) :-
    pixel(X, Y, Pixeles, BytesPorFila, Valor),
    ( Valor =:= 1
    -> Y1 is Y - 1,
       contar_negros(X, Y1, Pixeles, BytesPorFila, RestoAltura),
       Altura is RestoAltura + 1
    ;  Altura = 0
    ).

% ------------------------------------------------------------
% 4. LA ESTRUCTURA DE ALTURAS  M = [f(0), f(1), ..., f(n-1)]
% ------------------------------------------------------------
% alturas(+Pixeles, +Ancho, +Alto, +BytesPorFila, -M)
% M es la lista de TODOS los valores que satisfacen la relacion
% f/5 para X entre 0 y Ancho-1. findall/3 pregunta "que alturas
% existen?" en vez de "ejecuta esto Ancho veces".
alturas(Pixeles, Ancho, Alto, BytesPorFila, M) :-
    MaxX is Ancho - 1,
    findall(Altura,
            ( between(0, MaxX, X), f(X, Pixeles, Alto, BytesPorFila, Altura) ),
            M).

% ------------------------------------------------------------
% 5. SUMA DE RIEMANN -> AREA
% ------------------------------------------------------------
% area(+M, -Area)  ==  Area = sum_{x=0}^{n-1} f(x) * 1
area(M, Area) :- sum_list(M, Area).

% ------------------------------------------------------------
% 6. VISUALIZACION: region bajo la curva, escalada a la consola
% ------------------------------------------------------------
% Estrategia de escalado: se muestrean columnas cada Paso pixeles
% (Paso = Ancho // AnchoVisual) y la altura de cada columna se
% reescala proporcionalmente al numero de filas de la consola,
% preservando la forma general de la curva.
visualizar_region(M, Alto) :-
    AnchoVisual = 100,
    AltoVisual  = 24,
    length(M, N),
    Paso is max(1, N // AnchoVisual),
    muestrear(M, Paso, Muestras),
    maplist(escalar_altura(Alto, AltoVisual), Muestras, MuestrasEsc),
    forall(between(1, AltoVisual, K),
           ( FilaDesdeAbajo is AltoVisual - K + 1,
             forall(member(HE, MuestrasEsc),
                    ( HE >= FilaDesdeAbajo -> write('#') ; write(' ') )),
             nl
           )).

% muestrear(+Lista, +Paso, -Muestras): toma un elemento cada Paso.
muestrear(Lista, Paso, Muestras) :-
    findall(H, ( nth0(I, Lista, H), 0 is I mod Paso ), Muestras).

escalar_altura(AltoOriginal, AltoVisual, H, HE) :-
    HE is min(AltoVisual, round(H * AltoVisual / AltoOriginal)).

% ------------------------------------------------------------
% 7. VISUALIZACION DE M[X] = f(X) como "sparkline" de densidad
% ------------------------------------------------------------
% Se usan caracteres ASCII de densidad creciente (en vez de
% bloques Unicode) para evitar problemas de codificacion en
% distintas terminales/sistemas operativos.
visualizar_funcion_alturas(M) :-
    AnchoVisual = 100,
    length(M, N),
    Paso is max(1, N // AnchoVisual),
    muestrear(M, Paso, Muestras),
    max_list(Muestras, HMax),
    Bloques = [' ','.',':','-','=','+','*','#'],
    length(Bloques, NumBloques),
    forall(member(H, Muestras),
           ( Nivel is min(NumBloques, max(1, round(H * NumBloques / max(HMax,1)))),
             nth1(Nivel, Bloques, Caracter),
             write(Caracter)
           )),
    nl.

% ------------------------------------------------------------
% 8. VALORES DE MUESTRA  x_i -> f(x_i)
% ------------------------------------------------------------
mostrar_muestras(M, Ancho) :-
    NumMuestras = 10,
    Paso is max(1, (Ancho - 1) // (NumMuestras - 1)),
    forall(( between(0, NumMuestras, I), X is I*Paso, X =< Ancho - 1 ),
           ( nth0(X, M, FX),
             format("x_~w = ~w -> f(x_~w) = ~w pixeles~n", [I, X, I, FX])
           )).

% ------------------------------------------------------------
% PROGRAMA PRINCIPAL
% ------------------------------------------------------------
main :-
    ( current_prolog_flag(argv, [Archivo|_]) -> true
    ; Archivo = 'curva_binaria_P4.pbm'
    ),
    leer_pbm(Archivo, Ancho, Alto, BytesPorFila, Pixeles),
    format("Imagen: ~w x ~w pixeles~n", [Ancho, Alto]),
    alturas(Pixeles, Ancho, Alto, BytesPorFila, M),
    area(M, Area),
    format("Area = ~w pixeles cuadrados~n~n", [Area]),
    format("--- Region bajo la curva (escalada) ---~n"),
    visualizar_region(M, Alto),
    nl,
    format("--- Funcion de alturas M[x] = f(x) ---~n"),
    visualizar_funcion_alturas(M),
    nl,
    format("--- Algunos valores x_i -> f(x_i) ---~n"),
    mostrar_muestras(M, Ancho),
    halt.
main :-
    format("Error: no se pudo procesar el archivo PBM.~n"),
    halt(1).
