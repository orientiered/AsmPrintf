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
    push r12 ; we will store total number of written symbols in r12
    push r15 
    push r14

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
        cmp  BYTE [rdi], 0
        je   .loop_end      ; if c == 0 -> stop
        cmp  BYTE [rdi], '%'
        je   .argument  
        call printf_putc
        inc  rdi            ; c is not %
        inc  r12            
        jmp  .print_loop

        .argument:
            inc rdi
            cmp BYTE [rdi], '%'
            je .spec_percent
            cmp BYTE [rdi], 's'
            je .spec_string
            cmp BYTE [rdi], 'c'
            je .spec_char
            
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
                mov  r15, rdi

                add  rbp, 8         ; getting new argument
                lea  rdi, 8[rbp]    ; pointer to char
                call printf_putc    ; writing it to the buffer

                mov  rdi, r15
                inc  r12
                jmp  .print_loop
            .spec_none:
                cmp BYTE [rdi], 0
                je  .loop_end       ; no specificator after %

                inc rdi             ; skipping character

                jmp .print_loop


    .loop_end:

    call printf_flushBuffer

    mov rax, r12    ; number of symbols written
    

    pop r14
    pop r15
    pop r12
    pop rbp
    ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Print string from rdi
; Arg: rdi - string addr
; Ret: rax - string len
; Destr: rax, rcx, rsi, rdx
;============================================================
printf_string:
    call printf_flushBuffer ; unoptimal implementation

    call strlen   ; rax = strlen(rdi)
    mov  r14, rax

    mov  rsi, rdi ; string ptr
    mov  rdx, rax ; length
    mov  rax, 1   ; syscall write
    mov  rdi, 1   ; stdout

    syscall

    mov  rdi, rsi ; restoring rdi
    mov  rax, r14 ; restoring length in rax
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


;============================================================
; Puts character in printf buffer and flushes buffer it is full
; Arg:  rdi - ptr to char
; Destr: rax, rcx, r10, rsi, rdx
;============================================================
printf_putc:
    cmp WORD [printfBufPos], PRINTF_BUFFER_LEN
    jne .skipFlush

    call printf_flushBuffer

    .skipFlush:

    movzx rax, WORD [printfBufPos]
    inc  WORD [printfBufPos]
    mov  r10b, BYTE [rdi]
    mov  BYTE printfBuffer[rax], r10b   ; write symbol to buffer
    
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;============================================================
; Flush printf buffer
; Arg: none
; Destr: rax, rcx, rsi, rdx
;============================================================
printf_flushBuffer:
    push rdi    ;saving rdi

    mov rax, 1
    mov rdi, 1
    lea rsi, printfBuffer
    mov rdx, [printfBufPos]
    syscall   ; flushing buffer
    mov WORD [printfBufPos], 0 

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
    printfBuffer: resb PRINTF_BUFFER_LEN      ; printf buffer
    printfBufPos: resw 1                      ; position in buffer 
