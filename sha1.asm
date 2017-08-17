section .data
m_invalid_param db 'You have to pass exactly one argument', 0x0A
m_invalid_param_length equ $ - m_invalid_param
v_h0 dd 0x67452301
v_h1 dd 0xEFCDAB89
v_h2 dd 0x98BADCFE
v_h3 dd 0x10325476
v_h4 dd 0xC3D2E1F0
v_a dd 0x0
v_b dd 0x0
v_c dd 0x0
v_d dd 0x0
v_e dd 0x0
v_tmp dd 0x0
v_block_current dd 0
v_block_count dd 0
v_message_buffer_idx dq 0

section .bss
v_message: resq 1
v_message_length: resq 1
v_message_bit_length: resq 1
v_message_idx: resq 1
v_message_buffer: resb 64
v_w: resd 80

section .text
global _start
_start:
    pop rcx
    cmp rcx, 2
    jne print_invalid_param
    pop rcx     ; program name
    pop rcx
    mov [v_message], rcx
    push rcx
    call strlen
    mov [v_message_length], rax ; strlen in rax after call
    ;; S calculate msg bit length
    mov rbx, 8
    mul rbx
    bswap rax
    mov [v_message_bit_length], rax ; message bit length
    ;;; E calculate msg bit length
    
    ;;; S calculate no of blocks
    mov rax, [v_message_length]
    xor rdx, rdx
    mov rbx, 64
    div rbx
    inc rax
    cmp rdx, 56
    jl no_add
    inc rax
no_add:
    mov [v_block_count], rax 
    ;;; E calculate no of blocks
    
    ;;; main loop start
process_blocks:
    xor rax, rax
    xor rbx, rbx
    mov eax, [v_block_current]
    mov ebx, [v_block_count]
    cmp eax, ebx
    je post_process
    call extract_next_block
    call process_block
    inc dword [v_block_current]
    jmp process_blocks
    ;;; main loop end
post_process:
    jmp exit
    
process_block:
    xor rax, rax
calc_w_loop:
    cmp rax, 15
    jle w_from_mem
    cmp rax, 80
    je calc_w_loop_end
    mov ebx, [v_w + rax * 4 - 12] ; w[i - 3]
    mov ecx, [v_w + rax * 4 - 32] ; w[i - 8]
    mov edx, [v_w + rax * 4 - 56] ; w[i - 14]
    mov esi, [v_w + rax * 4 - 64] ; w[i - 16]
    xor ebx, ecx
    xor ebx, edx
    xor ebx, esi
    rol ebx, 1
    jmp w_ready
w_from_mem:
    mov ebx, dword [v_message_buffer + rax * 4]
    bswap ebx
w_ready:
    mov dword [v_w + rax * 4], ebx
    inc rax
    jmp calc_w_loop
calc_w_loop_end:
    mov r8d,  [v_h0] ; A
    mov r9d,  [v_h1] ; B
    mov r10d, [v_h2] ; C
    mov r11d, [v_h3] ; D
    mov r12d, [v_h4] ; E
    xor rax, rax
block_loop:
    cmp rax, 80
    je block_loop_end
    cmp rax, 20
    jl f1
    cmp rax, 40
    jl f2
    cmp rax, 60
    jl f3
    jmp f4
    
f1:
    mov r13d, r9d  ; B => r13d
    and r13d, r10d ; (B AND C) => r13d
    andn r14d, r9d, r11d ; (!B AND D) => r14d
    or r13d, r14d  ; (B AND C) OR (!B AND D)
    mov r15d, 0x5a827999
    jmp block_post_process
f2:
    mov r13d, r9d  ; B => r13d
    xor r13d, r10d ; r13d => B XOR C
    xor r13d, r11d ; r13d => B XOR C XOR D
    mov r15d, 0x6ED9EBA1
    jmp block_post_process
f3:
    mov r13d, r9d  ; r13d => B
    and r13d, r10d ; r13d => B AND C
    mov r14d, r9d  ; r14d => B
    and r14d, r11d ; r14d => B AND D
    or r13d, r14d  ; r13d => (B AND C) OR (B AND D)
    mov r14d, r10d ; r14d => C
    and r14d, r11d ; r14d => C AND D
    or r13d, r14d  ; r13d => (B AND C) OR (B AND D) OR (C AND D)
    mov r15d, 0x8F1BBCDC
    jmp block_post_process
f4:
    mov r13d, r9d  ; B => r13d
    xor r13d, r10d ; r13d => B XOR C
    xor r13d, r11d ; r13d => B XOR C XOR D
    mov r15d, 0xCA62C1D6
    ;jmp block_post_process
    
block_post_process:
    mov ebx, r8d
    rol ebx, 5     ; ebx => (A rol 5)
    add ebx, r13d  ; ebx => (A rol 5) + f(r13d)
    add ebx, r12d  ; ebx => (A rol 5) + f(r13d) + E
    add ebx, r15d  ; ebx => (A rol 5) + f(r13d) + E + k(r15d)
    add ebx, [v_w + rax * 4] ; ebx => (A rol 5) + f(r13d) + E + k(r15d) + w[i]
    xchg r12d, r11d ; E = D
    xchg r11d, r10d ; D = C
    xchg r10d, r9d  ; C = B
    rol r10d, 30    ; C ROL 30
    xchg r9d,  r8d  ; B = A
    xchg r8d,  ebx  ; A = tmp
    inc rax
    jmp block_loop
block_loop_end:
    add [v_h0], r8d 
    add [v_h1], r9d
    add [v_h2], r10d
    add [v_h3], r11d
    add [v_h4], r12d
    ret
      
print_invalid_param:
    mov rax, m_invalid_param_length
    push rax
    mov rax, m_invalid_param
    push rax
    call print_message
    jmp exit

print_message:
    pop r8
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    pop rsi    ; text
    pop rdx    ; count   
    push r8
    syscall
    ret
    
extract_next_block:
    mov rax, [v_message_buffer_idx]
    mov rbx, [v_message]
    mov rcx, [v_message_idx]
    mov rdx, [v_message_length]
    mov rsi, rbx
extract_loop:
    cmp rcx, rdx 
    je padding
    jg padding_loop_start
    cmp rax, 64
    je extract_loop_end
    mov r8b, byte [rsi + rcx]
    mov byte [v_message_buffer + rax], r8b
    inc rax
    inc rcx
    jmp extract_loop
extract_loop_end:
    mov qword [v_message_idx], rcx
    ret
padding:
    mov byte [v_message_buffer + rax], 0x80
    inc rax
    inc rcx
padding_loop_start:
    cmp rax, 56
    je append_bitlength
    cmp rax, 64
    je padding_loop_end
    mov byte [v_message_buffer + rax], 0x0
    inc rax
    jmp padding_loop_start
append_bitlength:
    mov rax,  [v_message_bit_length]
    mov qword [v_message_buffer + 56], rax
padding_loop_end:
    mov qword [v_message_idx], rcx
    ret

strlen:
    pop r8
    pop rbx
    push r8
    mov rax, 0
strlen_loop:
    cmp byte [rbx + rax], 0
    je strlen_end
    inc rax
    jmp strlen_loop
strlen_end:
    ret 

exit:
    mov rdi, 0d
    mov rax, 60d
    syscall
    