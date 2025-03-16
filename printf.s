section .text

global my_printf
PRINTF_BUFFER_LEN equ 64

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
    push rdi
    push rax

    ; push rax ; return address is on top of the stack
    ;TODO: turn call into jump
    call my_printf_cdecl
    pop  rdi        ; caller ret address
    add  rsp, 6*8   ;fixing stack
    jmp  rdi        ; returning back to caller
;-----------------------------------------------------------

;===========================================================
; Small printf implementation
; Currently supports: fmt string printing
;===========================================================
my_printf_cdecl:
    push rbp
    lea  rbp, 16[rsp]   ; caller ret address
    push rbx
    push r12 ; we will store total number of written symbols in r12
    push r15 
    push r14
    push r13

    ; for (const char *c = fmt; c; c++) {
    ;     if (*c != '%')
    ;         putc(*c);

    ;     // *c = '%'
    ;     c++;
    ;     switch(c) {
    ;         case 's':
    ;             puts([rsp+16]);
    ;             break;
    ;         default:
    ;             break;

    ;     }
    ;     c++;
    ; }
    mov rdi, [rbp+8] ;rdi = fmt
    xor r12, r12     ; r12 = 0
    .print_loop:
        mov  sil, BYTE [rdi] ; reading current char    
        
        cmp  sil, 0
        je   .loop_end      ; if c == 0 -> stop
        
        cmp  sil, '%'
        je   .argument  
        
        call printf_putc
        inc  rdi            ; c is not %
        inc  r12            
        jmp  .print_loop

        .argument:
            inc rdi
            mov sil, BYTE [rdi]

            cmp sil, '%'
            je .spec_percent

            cmp sil, 's'
            je .spec_string

            cmp sil, 'c'
            je .spec_char

            cmp sil, 'x'
            je .spec_hex

            cmp sil, 'o'
            je .spec_octal

            cmp sil, 'b'
            je .spec_binary

            jmp .spec_none

            .spec_percent:          ; %%
                call printf_putc    ; writing %
                inc  r12
                inc  rdi        
                
                jmp  .print_loop

            .spec_string:           ; %s
                inc  rdi
                mov  r15, rdi       ; saving rdi

                add  rbp, 8         ; getting new argument from stack
                mov  rdi, [rbp+8]   ; string ptr
                call printf_string  ; printing string

                mov  rdi, r15       ; restoring rdi
                add  r12, rax       ; adding rax printed characters to rcx
                jmp  .print_loop

            .spec_char:             ; %c
                inc  rdi

                add  rbp, 8         ; getting new argument
                mov  sil, [rbp + 8] ; char
                call printf_putc    ; writing it to the buffer

                inc  r12
                jmp  .print_loop

            ;--------
            .spec_hex:
                mov  rcx, 4             ; 1 digit = 4 bits
                jmp  .spec_base2n_number

            .spec_octal:
                mov  rcx, 3             ; 1 digit = 3 bits
                jmp  .spec_base2n_number

            .spec_binary:
                mov  rcx, 1             ; 1 digit = 1 bit
                jmp  .spec_base2n_number

            .spec_base2n_number:
                mov  r15, rdi

                add  rbp, 8
                mov  rdi, [rbp+8]
                call printf_base2n

                mov  rdi, r15
                inc  rdi
                add  r12, rax

                jmp  .print_loop 
            ;--------

            .spec_none:
                cmp  sil, 0
                je   .loop_end       ; no specificator after %

                inc rdi             ; skipping character

                jmp .print_loop


    .loop_end:

    call printf_flushBuffer

    mov rax, r12    ; number of symbols written
    
    pop r13
    pop r14
    pop r15
    pop r12
    pop rbx
    pop rbp
    ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Print string from rdi
; Arg: rdi - string addr
; Ret: rax - string len
; Destr: syscall + r14 + r13 + rbx
;============================================================
printf_string:

    call strlen   ; rax = strlen(rdi)
    movzx rcx, WORD [printfBufPos]

    mov rbx, PRINTF_BUFFER_LEN
    sub rbx, rcx    ; rbx = PRINTF_BUFFER_LEN - printfBufPos = free space

    cmp  rax, rbx
    ja   .NOT_ENOUGH_SPACE
        ; copying string to buffer
        
        lea  rsi, printfBuffer[rcx] 
        xchg rsi, rdi   ; rsi = string addr(source), rdi = printfBuffer + printBufPos (destination)
        mov  rcx, rax   ; length = rax

        call memncpy    ; it destroys rax by doing mov rax, rcx; but rcx = rax
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
        call memncpy
        add  WORD [printfBufPos], bx

        call printf_flushBuffer 

        add  rsi, rbx  ; first rbx characters are copied  
        lea  rdi, printfBuffer
        mov  rcx, r14
        sub  rcx, rbx  ; rcx = length - rbx
        call memncpy
        add  WORD [printfBufPos], ax

        jmp .end

        .LONG_STRING:
        ; flushing buffer and printing all string with one syscall

        call printf_flushBuffer ; 
        
        mov  rsi, rdi   ; string addr
        mov  rdx, r14   ; length
        mov  rax, 1     ; write
        mov  rdi, 1     ; to stdout

        syscall

        .end:
        mov  rax, r14 ; restoring length in rax
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
; Ret: rax - number of printed chars 
; Destr: syscall, rbx, r14
;============================================================
printf_base2n:
    mov  rdx, 1
    shl  rdx, cl     
    dec  rdx     ; mask for digit: (1 << cl ) - 1

    xor  rax, rax    ; rax = 0

    .convert_loop:

        mov  ebx, edi
        and  ebx, edx    ; ebx = edi & (1 << cl)
    
        cmp  ebx, 9      ; if digit <= 9
        jbe   .mov_digit    ; digit is ready to print
        
        add  ebx, 'A' - '0' - 10 ; hex digit

        .mov_digit:

        add  ebx, '0'   
        mov  numberBuffer[rax], bl
        inc  rax

        shr  edi, cl     ; edi >> cl
        test edi, edi    ; if edi != 0 jmp loop start
        jnz  .convert_loop


    mov rcx, rax    ; loop index
    mov rdi, rax    ; saving rax
    ; rcx > 0 
    .print_loop:
        mov  sil, BYTE numberBuffer[rcx-1]
        mov  r14, rcx 
        call printf_putc
        mov  rcx, r14

        loop .print_loop

    mov rax, rdi   ; return value = number of chars
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



;============================================================
; Puts character in printf buffer and flushes buffer if it is full
; Arg: sil - char  
; Destr: syscall \ {rdi, rsi}
;============================================================
printf_putc:
    cmp WORD [printfBufPos], PRINTF_BUFFER_LEN
    jb .skipFlush
    call printf_flushBuffer

    .skipFlush:

    movzx rax, WORD [printfBufPos]
    inc  WORD [printfBufPos]
    mov  BYTE printfBuffer[rax], sil   ; write symbol to buffer
    
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Flush printf buffer
; Arg: none
; Destr: sycacll \ {rsi, rdi}
;============================================================
printf_flushBuffer:
    push rdi    ;saving rdi
    push rsi 

    mov  rax, 1
    mov  rdi, 1
    lea  rsi, printfBuffer
    movzx rdx, WORD [printfBufPos]
    syscall   ; flushing buffer
    mov  WORD [printfBufPos], 0 

    pop rsi
    pop rdi     ; restoring rdi

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


section .bss
    numberBuffer: resb 32                     ; buffer for creating numbers
    printfBuffer: resb PRINTF_BUFFER_LEN      ; printf buffer
    printfBufPos: resw 1                      ; position in buffer 
