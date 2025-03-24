section .text

global my_printf
global my_printf_flush
extern atexit   ; for end-to-end printf buffer
PRINTF_BUFFER_LEN equ 64
NUMBER_BUFFER_LEN equ 32

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
; TODO List:
;   Float implementation:
;       1. Figure out how to push float arguments in stack
;           Made separate stack for float arguments (push them after integer arguments) (original printf does just that)
;          
;           System V says that in rax will be number of float arguments, so you can skip pushing floats
;       2. Add '%f' and corresponding jump in jump table
;
;       3. Conversion function
;           Print sign and clear it x -> |x|
;           a = int(x) print(a)
;           x -= float(a)
;           x *= 10^precision
;           print('.')
;           b = int(x) print(b)
;
;           
;
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; See memncpy
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%macro MACRO_memncpy 0
    mov  rax, rcx
    cld
    rep  movsb

    sub  rdi, rax
    sub  rsi, rax
%endmacro
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; See printf_putc
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%macro MACRO_printf_putc 0
    cmp WORD [printfBufPos], PRINTF_BUFFER_LEN
    jb .skipFlush
    call printf_flushBuffer

    .skipFlush:

    movzx rax, WORD [printfBufPos]
    inc  WORD [printfBufPos]
    mov  BYTE printfBuffer[rax], sil   ; write symbol to buffer
    mov  rax, 1
%endmacro
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; See strlen
; Parameter is number of strlen used in current scope
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%macro MACRO_strlen 1
    mov rax, rdi
    .strlen_loop%1:
        cmp  BYTE [rax], 0
        je  .loop_strlen_end%1

        inc  rax
        jmp .strlen_loop%1
    .loop_strlen_end%1:

    sub rax, rdi ; rax = strlen
%endmacro
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;==========================================================
; Printf trampoline
; Pushes registers on stack to simulate cdecl
;==========================================================
my_printf:
    pop  rax        ; saving return address in rax, this register is preserved by caller

    push r9         ; argument registers in reverse order 
    push r8
    push rcx
    push rdx
    push rsi
    ; push rdi      ; rdi = fmt, so no need no push it

; TODO: make check if  printf has any float arguments (rax = number of xmm registers used)
    sub  rsp, 8*8
    ; Pushing float arguments
    movq [rsp + 7*8], xmm7
    movq [rsp + 6*8], xmm6
    movq [rsp + 5*8], xmm5
    movq [rsp + 4*8], xmm4
    movq [rsp + 3*8], xmm3
    movq [rsp + 2*8], xmm2
    movq [rsp + 1*8], xmm1
    movq [rsp + 0*8], xmm0

    push rax        ; return address is on top of the stack

    jmp  my_printf_cdecl
;-----------------------------------------------------------

;===========================================================
; Small printf implementation
; Currently supports: fmt string printing
;===========================================================
my_printf_cdecl:
    push rbp
    lea  rbp, 8*8+16[rsp]   ; first integer argument in stack

    push rbx
    push r12 ; we will store total number of written symbols in r12
    push r15 ; this register is often used to save rdi
    push r14
    push r13


    ; registering printf_flushBuffer to execute at exit
        cmp  BYTE [printfHasRegisteredAtexit], 0
        jne  .skipRegistering

        mov  r15, rdi

        mov  rdi, printf_flushBuffer
        call atexit

        mov  rdi, r15

        dec BYTE [printfHasRegisteredAtexit]
    .skipRegistering:

    lea  r10, 16+5*8[rsp]       ; first float register in stack
    
    
    xor r12, r12     ; r12 = 0
    .print_loop:
        mov  sil, BYTE [rdi] ; reading current char    
        
        cmp  sil, 0
        je   .loop_end      ; if c == 0 -> stop
        
        cmp  sil, '%'
        je   .argument  
        
        MACRO_printf_putc

        inc  rdi            ; *rdi is not %
        inc  r12            
        jmp  .print_loop

        .argument:
            inc rdi
            movzx rsi, BYTE [rdi]

            cmp sil, '%'
            je .spec_percent

            sub sil, 'b'   ; sil -= 'b'
            jb .spec_none  ; spec < 'b'

            cmp sil, 'x' - 'a'
            ja .spec_none  ; spec > 'x'

        ; preambule
            inc rdi
            mov r15, rdi    ; skipping specifier symbol and saving rdi

            mov rdi, [rbp]
            add rbp, 8      ; getting new argument from stack

            push .epilogue  ; return address

            jmp printfSwitchJmpTable[rsi*8]    ; switch

            ;---------------------------------------------------------------
            ; this case is handled separately (not presented in jmp table) 
            .spec_percent:          ; %%
                call printf_putc   ; writing %
                inc  r12
                inc  rdi        
                
                jmp  .print_loop

            ;---------------------------------------------------------------

            ; .spec_string:           ; %s      <-- redundant jump
                ; jmp printf_string  ; printing string

            ; .spec_decimal:           %d, redundant jump
                ; jmp printf_decimal

            ; .spec_unsigned:          %u, redunadant jump
                ; jmp printf_unsigned

            .spec_char:             ; %c
                mov  sil, dil       ; char
                inc  r12
                jmp  printf_putc    ; writing it to the buffer


            .spec_hex:
                mov  rcx, 4             ; 1 digit = 4 bits
                mov  rdx, 0xF           ; mask = 0b1111
                jmp  printf_base2n

            .spec_octal:
                mov  rcx, 3             ; 1 digit = 3 bits
                mov  rdx, 0x7           ; mask = 0b111
                jmp  printf_base2n

            .spec_binary:
                mov  rcx, 1             ; 1 digit = 1 bit
                mov  rdx, 0x1
                jmp  printf_base2n

            .spec_float:
                sub  rbp, 8       ; register from different stack
                movq xmm0, [r10]  ; argument in xmm0   
                add  r10, 8       ; shifting pointer
                jmp printf_float

        ;epilogue
            .epilogue:
            mov   rdi, r15   ; restoring rdi
            jmp  .print_loop

    .spec_none:     ; unsupported specifier = end of printing
    .loop_end:

    ; call  printf_flushBuffer

    mov  rax, r12    ; number of symbols written
    
    pop  r13
    pop  r14
    pop  r15
    pop  r12
    pop  rbx
    pop  rbp


    pop  rdi        ; caller ret address
    add  rsp, 5*8 + 8*8  ;fixing stack
    jmp  rdi        ; returning back to caller

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Print string from rdi
; Arg: rdi - string addr
; Ret: r12 += number of chars written
; Destr: caller-saved \ {r10, r11} + r14 + rbx
;============================================================
printf_string:

    MACRO_strlen 1  ; rax = strlen(rdi)
    add  r12, rax 
    movzx rcx, WORD [printfBufPos]

    mov rbx, PRINTF_BUFFER_LEN
    sub rbx, rcx    ; rbx = PRINTF_BUFFER_LEN - printfBufPos = free space

    cmp  rax, rbx
    ja   .NOT_ENOUGH_SPACE
        ; copying string to buffer
        
        lea  rsi, printfBuffer[rcx] 
        xchg rsi, rdi   ; rsi = string addr(source), rdi = printfBuffer + printBufPos (destination)
        mov  rcx, rax   ; length = rax

        MACRO_memncpy    ; it destroys rax by doing mov rax, rcx; but rcx = rax
        add  WORD [printfBufPos], ax

        ret

    .NOT_ENOUGH_SPACE:
        
        mov  r14, rax
        cmp  rax, PRINTF_BUFFER_LEN
        ja   .LONG_STRING
        ; copying part of string to the buffer, flushing it and copying left part

        lea  rsi, printfBuffer[rcx]
        xchg rsi, rdi
        mov  rcx, rbx
        MACRO_memncpy
        add  WORD [printfBufPos], bx

        call printf_flushBuffer 

        add  rsi, rbx  ; first rbx characters are copied  
        lea  rdi, printfBuffer
        mov  rcx, r14
        sub  rcx, rbx  ; rcx = length - rbx
        MACRO_memncpy
        add  WORD [printfBufPos], ax

        ret

        .LONG_STRING:
        ; flushing buffer and printing all string with one syscall

        call printf_flushBuffer ; 
        
        mov  rsi, rdi   ; string addr
        mov  rdx, r14   ; length
        mov  rax, 1     ; write
        mov  rdi, 1     ; to stdout

        syscall

        .end:
        ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Print decimal 32bit number from edi
; Arg: edi - number 
; Ret: r12 += numbers of characters written
; Destr: caller-saved \ {r10, r11}, rbx, r14
;============================================================
printf_decimal:

    test edi, 0x80000000 ; checking sign bit 
    jz   printf_unsigned
    
    neg  edi
    mov  sil, '-'
    call printf_putc    ; printing '-'
    inc  r12


    jmp printf_unsigned

    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;============================================================
; Print unsigned 32-bit integer
;   edi - number
; Ret:
;   r12 += number of chars written
; Destr: caller-saved \ {r10, r11}, rbx, r14
;============================================================
printf_unsigned:
    mov  eax, edi
    mov  rbx, 10
    xor  r14, r14    ; r14 = 0 -> number of written symbols
    xor  rdx, rdx

    sub  rsp, NUMBER_BUFFER_LEN ; buffer for digits

    .unsigned_loop: 
        div  rbx

        ; rdx = rax % 10
        ; rax = rax / 10
        lea  rsi, [rdx+'0']
        mov  BYTE [rsp + r14], sil
        xor  rdx, rdx
        inc  r14

        test rax, rax
        jnz .unsigned_loop
    
    mov  rcx, r14
    add  r12, r14
    .print_loop:
        mov  sil, BYTE [rsp + rcx-1]
        mov  rdi, rcx
        MACRO_printf_putc
        mov  rcx, rdi

        loop .print_loop 


    add  rsp, NUMBER_BUFFER_LEN ; fixing stack

    ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;============================================================
; Memncpy
; Arg: rdi - destination
;      rsi - source
;      rcx - number of bytes to copy
; Destr: rax, rcx (actually rax = rcx )
;============================================================
memncpy:
    mov  rax, rcx

    cld
    rep movsb ;<-- may be SLOW on small data, but it looks nice

    sub  rdi, rax
    sub  rsi, rax
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Print unsigned number in hex, octal and binary
; Arg: edi - number
;      cl  - number of bits per digit
;      dl  - mask for digit
; Ret: r12 += number of printed chars 
; Destr: caller-saved \ {r10, r11}, rbx, r14
;============================================================
printf_base2n:
    xor  rax, rax    ; rax = 0
    sub  rsp, NUMBER_BUFFER_LEN  ; creating buffer for symbols

    ; Converting number to array of digits in the numberBuffer in reverse order
    .convert_loop:

        mov  ebx, edi
        ; Getting digit from number
        and  ebx, edx    ; ebx = edi & (1 << cl)
        ; Converting it to the symbol
        mov  bl, BYTE digitsTable[ebx]
        ; Storing symbol in buffer
        mov  [rsp + rax], bl
        inc  rax

        ; Removing digit from number
        shr  edi, cl     ; edi >> cl
        test edi, edi    ; if edi != 0 jmp loop start
        jnz  .convert_loop


    add  r12, rax
    mov  rcx, rax    ; loop index
    ; rcx > 0 

    ; Printing digits from numberBuffer in reverse order
    .print_loop:
        mov  sil, BYTE [rsp + rcx-1]
        mov  r14, rcx 
        MACRO_printf_putc
        mov  rcx, r14

        loop .print_loop

    add  rsp, NUMBER_BUFFER_LEN ; fixing stack
 
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



;============================================================
; Puts character in printf buffer and flushes buffer if it is full
; Arg: sil - char
; Ret: rax - number of written chars (1)  
; Destr: caller-saved \ {rsi, rdi, r10, r11}
;============================================================
printf_putc:
    cmp WORD [printfBufPos], PRINTF_BUFFER_LEN
    jb .skipFlush
    call printf_flushBuffer

    .skipFlush:

    movzx rax, WORD [printfBufPos]
    inc  WORD [printfBufPos]
    mov  BYTE printfBuffer[rax], sil   ; write symbol to buffer
    mov  rax, 1
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Flush printf buffer
; Arg: none
; Destr: caller-saved \ {rsi, rdi, r10, r11}
;============================================================
; synonym for use in C program
my_printf_flush:
printf_flushBuffer:
    push rdi    ;saving rdi
    push rsi 
    push r10
    push r11

    mov  rax, 1
    mov  rdi, 1
    lea  rsi, printfBuffer
    movzx rdx, WORD [printfBufPos]
    syscall   ; flushing buffer
    mov  WORD [printfBufPos], 0 

    pop r11
    pop r10
    pop rsi
    pop rdi     ; restoring rdi

    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;============================================================
; Print float number
; Arg: 
;   xmm0 - arg
; Ret:
;   r12 += number of written chars
; Destr: caller-saved \ {r10, r11}, xmm0, xmm1
;============================================================
printf_float:
; Checking sign of given number
    
    pextrb eax, xmm0, 7 ; extracting high byte with sign bit
    test   ax,  0x80    ; checking sign bit
    jz   .skipMinus

        mov  sil, '-'
        call printf_putc
        inc  r12

        pand xmm0, [FLOAT_REMOVE_SIGN_MASK]
    .skipMinus:

    ; Printing integer part
    cvttsd2si rdi,  xmm0 ; rdi = int(x) with rounding towards zero
    cvtsi2sd  xmm1, rdi  ; xmm1  = double(int(x)) 
    
    call printf_decimal

    mov  sil, '.'
    call printf_putc
    inc  r12

    sub  rsp, 8 
    xor  rcx, rcx

    .convert_loop:
    ; TODO: this loop could be removed: multiply xmm0 by 10^6 and print number with leading zeros 
        inc  rcx
        subsd    xmm0, xmm1 ; x -= int(x)
        mulsd    xmm0, [FLOAT_10]
        cvttsd2si rdi, xmm0  
        cvtsi2sd xmm1, rdi

        mov  dil, BYTE digitsTable[rdi] ; rdi = ascii digit
        mov  BYTE [rsp + rcx - 1], dil
        cmp  rcx, 7
        jb   .convert_loop

    mov  BYTE [rsp + rcx], 0 ; end of string   
    mov  rdi, rsp
    call printf_string

    add  rsp, 8

    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;============================================================
; Strlen for c strings
; Args: rdi - string address
; Ret:  rax - length of string
; Destr: rax
;============================================================
strlen:
    mov rax, rdi
    .str_loop:
        cmp  BYTE [rax], 0
        je  .loop_end

        inc  rax
        jmp .str_loop
    .loop_end:

    sub rax, rdi ; rax = strlen
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



section .rodata
    align 8
    ; Printf jump table
    ;-------------------------------------------------
    printfSwitchJmpTable:
    dq my_printf_cdecl.spec_binary  ; b - binary
    dq my_printf_cdecl.spec_char    ; c - char
    dq printf_decimal               ; d - decimal
    dq my_printf_cdecl.spec_none    ; e - none
    dq my_printf_cdecl.spec_float    ; f - float
    ;g h i j k l m n
    dq 'o'-'f' - 1 dup my_printf_cdecl.spec_none   ; default
    dq my_printf_cdecl.spec_octal   ; o - octal
    ; p q r
    dq 's'-'o' - 1  dup my_printf_cdecl.spec_none   ; default
    dq printf_string                ; s - string
    ; t  
    dq my_printf_cdecl.spec_none   ; default
    dq printf_unsigned             ; u - unsigned
    ; v w
    dq 'x'-'u' - 1  dup my_printf_cdecl.spec_none   ; default

    dq my_printf_cdecl.spec_hex     ; x - hexadecimal
    ;---------------------------------------------------

    digitsTable db '0123456789ABCDEF'
    FLOAT_REMOVE_SIGN_MASK db 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F
    FLOAT_10    dq 10.0 

section .bss
    printfBuffer: resb PRINTF_BUFFER_LEN      ; printf buffer
    printfBufPos: resw 1                      ; position in buffer

    printfHasRegisteredAtexit: resb 1         ; flag that is set after calling atexit
