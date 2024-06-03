;===Микроконтроллер ATtiny13A===
.include "tn13Adef.inc"
;===Встроенный RC генератор на 9.8 мегагерца, деление на 8====

;Используемые константы
.equ LEDPIN = 0 ;пин порта с подключенным светодиодом
.equ BUTTONPIN = 3 ;пин порта куда суём ключ
.equ SAVE_TEMP = 0x60
.equ SAVE_COUNTER = 0x61
;=>ШПАРГАЛКА<=
;=> sbi DDRB, BUTTONPIN <= переводит шину в 0 (ПЕРЕДАЁМ 0)
;=> cbi DDRB, BUTTONPIN <= переводит шину в Z (ПЕРЕДАЁМ 1 / СЛУШАЕМ)
;=> ВО ИЗБЕЖАНИЕ КОРОРОТКОГО ЗАМЫКАНИЯ 
;   НЕ ИСПОЛЬЗОВАТЬ ВЫВОД НА BUTTONPIN, ТОЛЬКО РЕГИСТР НАПРАВЛЕНИЯ!!!

;Используемые переменные


.def TEMP = r16
.def POLYNOMorBURNBYTE = r17
.def IDBYTE = r18
.def KEYBYTE0 = r19
.def KEYBYTE1 = r20
.def KEYBYTE2 = r21
.def KEYBYTE3 = r22
.def KEYBYTE4 = r23
.def KEYBYTE5 = r24
.def CRCBYTE = r25

.def BYTE_0 = r2
.def BYTE_1 = r3
.def BYTE_2 = r4
.def BYTE_3 = r5
.def BYTE_4 = r6
.def BYTE_5 = r7
.def BYTE_6 = r8
.def BYTE_7 = r1

.def IDBYTE_INV = r0
.def KEYBYTE0_INV = r9
.def KEYBYTE1_INV = r10
.def KEYBYTE2_INV = r11
.def KEYBYTE3_INV = r12
.def KEYBYTE4_INV = r13
.def KEYBYTE5_INV = r14
.def CRCBYTE_INV = r15

.def EE_D = r26
.def EE_A = r27


.def EECOUNT = r29
.def PUSHandLEDcounter = r31
.def EEPROM_SEL = r30
.def KEYNUMBER = r28


;Порт на вывод
sbi DDRB, LEDPIN

;Инициализация стека
ldi TEMP, RAMEND out SPL, TEMP

;Подстройка частоты встроенного генератора
ldi TEMP, 0x64 out OSCCAL, TEMP

;Детектор подачи питания
in TEMP, MCUSR
sbrs TEMP, PORF
rjmp PC+5
clr TEMP
sts SAVE_TEMP, TEMP
sts SAVE_COUNTER, TEMP
out MCUSR, TEMP
;=======================================================================><
;+----------------+
;|НАЧАЛО ПРОГРАММЫ|
;+----------------+
START:

;+-----------------------+
;|ПРОГРАММА ВЫБОРА РЕЖИМА|
;+-----------------------+
rcall BIGDELAY

lds TEMP, SAVE_TEMP
inc TEMP
sts SAVE_TEMP, TEMP

lds EEPROM_SEL, SAVE_COUNTER
dec EEPROM_SEL
sts SAVE_COUNTER, EEPROM_SEL

ldi PUSHandLEDcounter, 50
rcall BIGDELAY
dec PUSHandLEDcounter
brne PC-2

dec TEMP
sts SAVE_TEMP, TEMP
bst TEMP, 0

lds EEPROM_SEL, SAVE_COUNTER
inc EEPROM_SEL
andi EEPROM_SEL, 0b0000111 ;Маска количества ключей
mov PUSHandLEDcounter, EEPROM_SEL 
mov EECOUNT, EEPROM_SEL
inc EEPROM_SEL
sts SAVE_COUNTER, EEPROM_SEL

lsl EECOUNT lsl EECOUNT lsl EECOUNT



brtc WRITEMODE ;определяет в каком режиме запускается (brts - первым идёт чтение, brtc - первым идет запись)
;+--------------------------------+
;|КОНЕЦ ПОДПРОГРАММЫ ВЫБОРА РЕЖИМА|
;+--------------------------------+
;=======================================================================><
;+------------+
;|Режим чтения|
;+------------+
READMODE:

rcall BLINK

BEGINREAD:
sbi PORTB, LEDPIN
rcall RESET_PRESENSE_STOP
rcall  RESET_PRESENSE_START

rcall READ_KEY
cbi PORTB, LEDPIN
rcall EE_WRITE

cpi IDBYTE, 0x01
brne BAD_READ

rcall CALCULATE_CRC
brtc BAD_READ

rcall GOOD_BLINK
rjmp BEGINREAD

BAD_READ:
rcall BAD_BLINK
rjmp BEGINREAD

;+------------+
;|Режим записи|
;+------------+
WRITEMODE:
rcall BLINK

;=>Загрузка из EEPROM, создание реверсивных бит, 
rcall EE_READ

mov BYTE_7, CRCBYTE
mov BYTE_6, KEYBYTE5
mov BYTE_5, KEYBYTE4
mov BYTE_4, KEYBYTE3
mov BYTE_3, KEYBYTE2
mov BYTE_2, KEYBYTE1
mov BYTE_1, KEYBYTE0
mov BYTE_0, IDBYTE
rcall REVERSE_BYTE

BEGINWRITE:
rcall STROBE_ON

rcall RESET_PRESENSE_STOP


rcall  RESET_PRESENSE_START
rcall STROBE_OFF ;выключить строб
sbi PORTB, LEDPIN ;зажечь светодиод


rcall WRITE_KEY
rcall READ_KEY

rcall BIGDELAY

cp BYTE_7, CRCBYTE
brne BAD_WRITE
cp BYTE_6, KEYBYTE5
brne BAD_WRITE
cp BYTE_5, KEYBYTE4
brne BAD_WRITE
cp BYTE_4, KEYBYTE3
brne BAD_WRITE
cp BYTE_3, KEYBYTE2
brne BAD_WRITE
cp BYTE_2, KEYBYTE1
brne BAD_WRITE
cp BYTE_1, KEYBYTE0
brne BAD_WRITE
cp BYTE_0, IDBYTE
brne BAD_WRITE

rcall STROBE_OFF
rcall GOOD_BLINK
rjmp BEGINWRITE

BAD_WRITE:
rcall STROBE_OFF
rcall BAD_BLINK
rjmp BEGINWRITE
;+---------------+
;|КОНЕЦ ПРОГРАММЫ|
;+---------------+
;=======================================================================><

READ_KEY:
rcall RESET_PRESENSE
ldi TEMP, 0x33
rcall BYTE_WRITE
rcall BYTE_READ
mov IDBYTE, TEMP
rcall BYTE_READ
mov KEYBYTE0, TEMP
rcall BYTE_READ
mov KEYBYTE1, TEMP
rcall BYTE_READ
mov KEYBYTE2, TEMP
rcall BYTE_READ
mov KEYBYTE3, TEMP
rcall BYTE_READ
mov KEYBYTE4, TEMP
rcall BYTE_READ
mov KEYBYTE5, TEMP
rcall BYTE_READ
mov CRCBYTE, TEMP
ret


WRITE_KEY:
ldi POLYNOMorBURNBYTE, 0xD5

ldi TEMP, 0xD1
rcall BYTE_WRITE
clt
rcall BIT_IO

rcall RESET_PRESENSE
ldi TEMP, 0xD5
rcall BYTE_WRITE

mov TEMP, IDBYTE_INV
rcall BYTE_WRITE

mov TEMP, KEYBYTE0_INV
rcall BYTE_WRITE
mov TEMP, KEYBYTE1_INV
rcall BYTE_WRITE
mov TEMP, KEYBYTE2_INV
rcall BYTE_WRITE
mov TEMP, KEYBYTE3_INV
rcall BYTE_WRITE
mov TEMP, KEYBYTE4_INV
rcall BYTE_WRITE
mov TEMP, KEYBYTE5_INV
rcall BYTE_WRITE
mov TEMP, CRCBYTE_INV
rcall BYTE_WRITE

rcall RESET_PRESENSE
ldi TEMP, 0xD1
rcall BYTE_WRITE
set
rcall BIT_IO

clr POLYNOMorBURNBYTE
ret

;+--------+
;|Задержки|
;+--------+
DELAY12:
nop
rjmp PC+1
rjmp PC+1
rjmp PC+1
rjmp PC+1
ret
DELAY98:
push TEMP
ldi TEMP, 29
dec TEMP
brne PC-1
pop TEMP
ret
BIGDELAY:
push TEMP
ldi TEMP, 119
rcall DELAY98
dec TEMP
brne PC-2
pop TEMP
ret
VERYBIGDELAY:
push TEMP
ldi TEMP, 50
rcall BIGDELAY
dec TEMP
brne PC-2
pop TEMP
ret
VERYBIGDELAY3X:
rcall VERYBIGDELAY
rcall VERYBIGDELAY
rcall VERYBIGDELAY
ret

;+--------------------------------------------+
;|Различные варианты работы с RESET и PRESENSE|
;+--------------------------------------------+
RESET_PRESENSE:
clt
sbi DDRB, BUTTONPIN
ldi TEMP, 200
dec TEMP
brne PC-1
cbi DDRB, BUTTONPIN
ldi TEMP, 33
dec TEMP
brne PC-1
sbis PINB, BUTTONPIN
set
ldi TEMP, 165
dec TEMP
brne PC-1
ret

RESET_PRESENSE_STOP:
ldi TEMP, 255
push TEMP
rcall RESET_PRESENSE
pop TEMP
rcall DELAY98
brts PC-5
dec TEMP
brne PC-6
ret

RESET_PRESENSE_START:
ldi TEMP, 127
push TEMP
rcall RESET_PRESENSE
pop TEMP
rcall DELAY98
sbis PINB, BUTTONPIN
rjmp PC-6
brtc PC-7
rcall DELAY98
dec TEMP
brne PC-9
ret
;+------------------------+
;|Операции чтения и записи|
;+------------------------+
BIT_IO:
sbi DDRB, BUTTONPIN
rcall DELAY12
brtc PC+2
cbi DDRB, BUTTONPIN
brtc PC+1
rjmp PC+1
rjmp PC+1
sbis PINB, BUTTONPIN
clt
rcall DELAY98
cbi DDRB, BUTTONPIN
rcall DELAY12
rcall DELAY12
cpi POLYNOMorBURNBYTE, 0xD5
brne PC+2
rcall BIGDELAY
ret

BYTE_WRITE:
bst TEMP, 0
rcall BIT_IO
bst TEMP, 1
rcall BIT_IO
bst TEMP, 2
rcall BIT_IO
bst TEMP, 3
rcall BIT_IO
bst TEMP, 4
rcall BIT_IO
bst TEMP, 5
rcall BIT_IO
bst TEMP, 6
rcall BIT_IO
bst TEMP, 7
rcall BIT_IO
ret

BYTE_READ:
clr POLYNOMorBURNBYTE
set
rcall BIT_IO
bld TEMP, 0 
set
rcall BIT_IO
bld TEMP, 1
set
rcall BIT_IO
bld TEMP, 2 
set
rcall BIT_IO
bld TEMP, 3 
set
rcall BIT_IO
bld TEMP, 4 
set
rcall BIT_IO
bld TEMP, 5 
set
rcall BIT_IO
bld TEMP, 6
set
rcall BIT_IO
bld TEMP, 7
set
ret

;+---------------+
;|Калькулятор CRC|
;+---------------+
CALCULATE_CRC:
mov BYTE_0, IDBYTE
mov BYTE_1, KEYBYTE0
mov BYTE_2, KEYBYTE1
mov BYTE_3, KEYBYTE2
mov BYTE_4, KEYBYTE3
mov BYTE_5, KEYBYTE4
mov BYTE_6, KEYBYTE5
ldi POLYNOMorBURNBYTE, 0x8C
clt
ldi TEMP, 56
LOOPCRCSHIFT:
lsr BYTE_6
ror BYTE_5
ror BYTE_4
ror BYTE_3
ror BYTE_2
ror BYTE_1
ror BYTE_0
brcc PC+2
eor BYTE_0, POLYNOMorBURNBYTE
dec TEMP
brne LOOPCRCSHIFT
cp CRCBYTE, BYTE_0
brne PC+2
set
ret

;+-------------------+
;|Реверсирование байт|
;+-------------------+
REVERSE_BYTE:
ser TEMP
sub TEMP, IDBYTE
mov IDBYTE_INV, TEMP

ser TEMP
sub TEMP, KEYBYTE0
mov KEYBYTE0_INV, TEMP
ser TEMP
sub TEMP, KEYBYTE1
mov KEYBYTE1_INV, TEMP
ser TEMP
sub TEMP, KEYBYTE2
mov KEYBYTE2_INV, TEMP
ser TEMP
sub TEMP, KEYBYTE3
mov KEYBYTE3_INV, TEMP
ser TEMP
sub TEMP, KEYBYTE4
mov KEYBYTE4_INV, TEMP
ser TEMP
sub TEMP, KEYBYTE5
mov KEYBYTE5_INV, TEMP

ser TEMP
sub TEMP, CRCBYTE
mov CRCBYTE_INV, TEMP
ret

;+----------------+
;|Мигания и стробы|
;+----------------+
BLINK:
inc PUSHandLEDcounter
breq PC+8
rcall VERYBIGDELAY
sbi PORTB, LEDPIN
rcall VERYBIGDELAY
cbi PORTB, LEDPIN
dec PUSHandLEDcounter
brne BLINK+1
rcall VERYBIGDELAY3X
ret

STROBE_ON:
ldi TEMP, 0b01000000 out TCCR0A, TEMP
ldi TEMP, 0b00000100 out TCCR0B, TEMP
ret
STROBE_OFF:
ldi TEMP, 0b00000000 out TCCR0A, TEMP
ldi TEMP, 0b00000000 out TCCR0B, TEMP
cbi PORTB, LEDPIN
ret

GOOD_BLINK:
rcall VERYBIGDELAY
sbi PORTB, LEDPIN
rcall VERYBIGDELAY
cbi PORTB, LEDPIN
rcall VERYBIGDELAY
sbi PORTB, LEDPIN
rcall VERYBIGDELAY
cbi PORTB, LEDPIN
rcall VERYBIGDELAY
sbi PORTB, LEDPIN
ret

BAD_BLINK:
rcall VERYBIGDELAY
cbi PORTB, LEDPIN
rcall VERYBIGDELAY3X
sbi PORTB, LEDPIN
rcall VERYBIGDELAY
ret

;+---------------+
;|Работа с EEPROM|
;+---------------+

;+-------------+
;|Запись EEPROM|
;+-------------+
EE_WRITE:
mov EE_A, EECOUNT

mov EE_D, CRCBYTE
rcall EE_WRITE_DYTE

mov EE_D, KEYBYTE5
rcall EE_WRITE_DYTE
mov EE_D, KEYBYTE4
rcall EE_WRITE_DYTE
mov EE_D, KEYBYTE3
rcall EE_WRITE_DYTE
mov EE_D, KEYBYTE2
rcall EE_WRITE_DYTE
mov EE_D, KEYBYTE1
rcall EE_WRITE_DYTE
mov EE_D, KEYBYTE0
rcall EE_WRITE_DYTE

mov EE_D, IDBYTE
rcall EE_WRITE_DYTE
ret

EE_WRITE_DYTE:
sbic EECR, EEPE
rjmp PC-1
ldi TEMP, 0b11000000
out EECR, TEMP
out EEAR, EE_A
out EEDR, EE_D
sbi EECR, EEMPE
sbi EECR, EEPE
inc EE_A
ret

;+-------------+
;|Чтение EEPROM|
;+-------------+
EE_READ:
mov EE_A, EECOUNT

rcall EE_READ_DYTE
mov CRCBYTE, EE_D

rcall EE_READ_DYTE
mov KEYBYTE5, EE_D
rcall EE_READ_DYTE
mov KEYBYTE4, EE_D
rcall EE_READ_DYTE
mov KEYBYTE3, EE_D
rcall EE_READ_DYTE
mov KEYBYTE2, EE_D
rcall EE_READ_DYTE
mov KEYBYTE1, EE_D
rcall EE_READ_DYTE
mov KEYBYTE0, EE_D

rcall EE_READ_DYTE
mov IDBYTE, EE_D

ret

EE_READ_DYTE:
sbic EECR, EEPE
rjmp PC-1
out EEAR, EE_A
sbi EECR, EERE
in EE_D, EEDR
inc EE_A
ret


