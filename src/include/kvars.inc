; Переменные ядра для модулей .sys: адреса считаются по общему списку kvarlist.inc
%include "src/include/kconst.inc"
%assign KOFF 0
%macro KVD 2
%1 equ KV + KOFF
%assign KOFF KOFF + 4
%endmacro
%macro KVB 2
%1 equ KV + KOFF
%assign KOFF KOFF + 1
%endmacro
%macro KVS 2
%1 equ KV + KOFF
%assign KOFF KOFF + %2
%endmacro
%include "src/include/kvarlist.inc"
