section .text

global my_printf
PRINTF_BUFFER_LEN equ 64

;==========================================================
; Printf trampoline
; Pushes registers on stack to simulate cdecl
;==========================================================
my_printf:
    pop  rbx        ; saving return address in rbx, this register is preserved by callee
    push r9         ; argument registers in reverse order 
    push r8
    push rcx
    push rdx
    push rsi
    push rdi

    ; push rax ; return address is on top of the stack
    ;TODO: turn call into jump
    call my_printf_cdecl
    add  rsp, 6*8   ;fixing stack
    jmp  rbx        ; returning back to caller
;-----------------------------------------------------------

;===========================================================
; Small printf implementation
; Currently supports: fmt string printing
;===========================================================
my_printf_cdecl:    
    mov rdi, [rsp+8]
    call strlen

    mov rdi, 1 ; stdout
    mov rsi, [rsp+8] ; string
    mov rdx, rax     ; strlen

    mov rax, 1       ; write
    syscall

    mov rax, rdx    ; number of symbols written
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
        jz  .loop_end

        inc  rax
        jmp .str_loop
    .loop_end:

    sub rax, rdi ; rax = strlen
    ret
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


section .bss

printfBuffer resb PRINTF_BUFFER_LEN      ; printf buffer
printfBufPos resw 1                      ; position in buffer 
