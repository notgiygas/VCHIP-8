section .data

align 16
chip8_fontset:
    db 0xF0, 0x90, 0x90, 0x90, 0xF0   ; 0
    db 0x20, 0x60, 0x20, 0x20, 0x70   ; 1
    db 0xF0, 0x10, 0xF0, 0x80, 0xF0   ; 2
    db 0xF0, 0x10, 0xF0, 0x10, 0xF0   ; 3
    db 0x90, 0x90, 0xF0, 0x10, 0x10   ; 4
    db 0xF0, 0x80, 0xF0, 0x10, 0xF0   ; 5
    db 0xF0, 0x80, 0xF0, 0x90, 0xF0   ; 6
    db 0xF0, 0x10, 0x20, 0x40, 0x40   ; 7
    db 0xF0, 0x90, 0xF0, 0x90, 0xF0   ; 8
    db 0xF0, 0x90, 0xF0, 0x10, 0xF0   ; 9
    db 0xF0, 0x90, 0xF0, 0x90, 0x90   ; A
    db 0xE0, 0x90, 0xE0, 0x90, 0xE0   ; B
    db 0xF0, 0x80, 0x80, 0x80, 0xF0   ; C
    db 0xE0, 0x90, 0x90, 0x90, 0xE0   ; D
    db 0xF0, 0x80, 0xF0, 0x80, 0xF0   ; E
    db 0xF0, 0x80, 0xF0, 0x80, 0x80   ; F

%define CHIP8_FONT_BASE 0x50
%define CHIP8_ROM_BASE  0x200

section .bss

align 16
chip8_mem:          resb 4096   ; 4K addressable RAM
chip8_V:             resb 16    ; V0-VF general purpose registers
chip8_I:             resd 1     ; index register (12-bit value used)
chip8_pc:            resd 1     ; program counter
chip8_sp:            resd 1     ; stack pointer
chip8_stack:         resd 16    ; call stack (16 levels)
chip8_delay:         resd 1     ; delay timer (60Hz)
chip8_sound:         resd 1     ; sound timer (60Hz)
chip8_display:       resb 2048  ; 64x32 monochrome framebuffer, 1 byte/pixel
chip8_keys:          resb 16    ; 16-key hex keypad state
chip8_draw_flag:     resb 1     ; set to 1 whenever the framebuffer changes
chip8_rng_state:     resd 1     ; xorshift32 PRNG state
chip8_last_opcode:   resd 1     ; most recently fetched opcode (debug overlay)

; --- configurable quirks (0 = default behavior, 1 = alternate) ---
quirk_shift_vy:          resd 1   ; 8XY6/8XYE shift VY into VX instead of VX in place
quirk_bnnn_vx:            resd 1   ; BNNN jumps to NNN+VX (X = top nibble) instead of NNN+V0
quirk_fx55_increment_i:   resd 1   ; FX55/FX65 leave I += X+1 instead of unchanged

section .text

chip8_init:
    push rcx
    push rdx
    push r8

    xor ecx, ecx
    lea rdx, [rel chip8_mem]
.clearmem:
    cmp ecx, 4096
    jae .clearmem_done
    mov byte [rdx + rcx], 0
    inc ecx
    jmp .clearmem
.clearmem_done:

    xor ecx, ecx
    lea rdx, [rel chip8_V]
.clearv:
    cmp ecx, 16
    jae .clearv_done
    mov byte [rdx + rcx], 0
    inc ecx
    jmp .clearv
.clearv_done:

    xor ecx, ecx
    lea rdx, [rel chip8_display]
.cleardisp:
    cmp ecx, 2048
    jae .cleardisp_done
    mov byte [rdx + rcx], 0
    inc ecx
    jmp .cleardisp
.cleardisp_done:

    xor ecx, ecx
    lea rdx, [rel chip8_keys]
.clearkeys:
    cmp ecx, 16
    jae .clearkeys_done
    mov byte [rdx + rcx], 0
    inc ecx
    jmp .clearkeys
.clearkeys_done:

    mov dword [chip8_I], 0
    mov dword [chip8_pc], CHIP8_ROM_BASE
    mov dword [chip8_sp], 0
    mov dword [chip8_delay], 0
    mov dword [chip8_sound], 0
    mov byte  [chip8_draw_flag], 0

    xor ecx, ecx
    lea rdx, [rel chip8_fontset]
    lea r8, [rel chip8_mem]
.copyfont:
    cmp ecx, 80
    jae .copyfont_done
    mov al, [rdx + rcx]
    mov [r8 + CHIP8_FONT_BASE + rcx], al
    inc ecx
    jmp .copyfont
.copyfont_done:

    rdtsc
    or eax, 1                      ; PRNG seed must never be zero
    mov [chip8_rng_state], eax

    pop r8
    pop rdx
    pop rcx
    ret

chip8_load_rom:
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    mov ecx, esi
    cmp ecx, 4096 - CHIP8_ROM_BASE
    jbe .sizeok
    mov ecx, 4096 - CHIP8_ROM_BASE
.sizeok:
    xor edx, edx
    lea r8, [rel chip8_mem]
.copyloop:
    cmp edx, ecx
    jae .copydone
    mov al, [rdi + rdx]
    mov [r8 + CHIP8_ROM_BASE + rdx], al
    inc edx
    jmp .copyloop
.copydone:

    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    ret

chip8_rand:
    mov eax, [chip8_rng_state]
    mov edx, eax
    shl edx, 13
    xor eax, edx
    mov edx, eax
    shr edx, 17
    xor eax, edx
    mov edx, eax
    shl edx, 5
    xor eax, edx
    mov [chip8_rng_state], eax
    ret

chip8_timer_tick:
    mov eax, [chip8_delay]
    test eax, eax
    jz .skip_delay
    dec eax
    mov [chip8_delay], eax
.skip_delay:
    mov eax, [chip8_sound]
    test eax, eax
    jz .skip_sound
    dec eax
    mov [chip8_sound], eax
.skip_sound:
    ret

chip8_key_down:
    movzx eax, dil
    lea rdx, [rel chip8_keys]
    mov byte [rdx + rax], 1
    ret

chip8_key_up:
    movzx eax, dil
    lea rdx, [rel chip8_keys]
    mov byte [rdx + rax], 0
    ret

; chip8_cycle - fetch, decode, execute exactly one instruction.
;
; Register map used throughout this function:
;   ecx  = raw 16-bit opcode
;   r10d = nibble 1 (bits 15-12)   -- top-level dispatch
;   r11d = NNN      (bits 11-0)
;   ebx  = X        (bits 11-8)
;   ebp  = Y        (bits 7-4)
;   r12d = N        (bits 3-0)
;   r13d = NN       (bits 7-0)

chip8_cycle:
    push rbx
    push rbp
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15

    lea rdi, [rel chip8_V]
    lea rsi, [rel chip8_mem]

    mov eax, [chip8_pc]
    movzx ecx, byte [rsi + rax]
    movzx edx, byte [rsi + rax + 1]
    shl ecx, 8
    or ecx, edx
    add dword [chip8_pc], 2
    mov [chip8_last_opcode], ecx

    mov r10d, ecx
    shr r10d, 12

    mov r11d, ecx
    and r11d, 0x0FFF

    mov ebx, ecx
    shr ebx, 8
    and ebx, 0xF

    mov ebp, ecx
    shr ebp, 4
    and ebp, 0xF

    mov r12d, ecx
    and r12d, 0xF

    mov r13d, ecx
    and r13d, 0xFF

    cmp r10d, 0x0
    je .op_0
    cmp r10d, 0x1
    je .op_1
    cmp r10d, 0x2
    je .op_2
    cmp r10d, 0x3
    je .op_3
    cmp r10d, 0x4
    je .op_4
    cmp r10d, 0x5
    je .op_5
    cmp r10d, 0x6
    je .op_6
    cmp r10d, 0x7
    je .op_7
    cmp r10d, 0x8
    je .op_8
    cmp r10d, 0x9
    je .op_9
    cmp r10d, 0xA
    je .op_A
    cmp r10d, 0xB
    je .op_B
    cmp r10d, 0xC
    je .op_C
    cmp r10d, 0xD
    je .op_D
    cmp r10d, 0xE
    je .op_E
    cmp r10d, 0xF
    je .op_F
    jmp .cycle_done

; ---- 0x0NNN / 00E0 / 00EE ----
.op_0:
    cmp ecx, 0x00E0
    je .op_00E0
    cmp ecx, 0x00EE
    je .op_00EE
    jmp .cycle_done
.op_00E0:
    lea rdx, [rel chip8_display]
    xor eax, eax
.clr_loop:
    cmp eax, 2048
    jae .clr_done
    mov byte [rdx + rax], 0
    inc eax
    jmp .clr_loop
.clr_done:
    mov byte [chip8_draw_flag], 1
    jmp .cycle_done
.op_00EE:
    mov eax, [chip8_sp]
    dec eax
    mov [chip8_sp], eax
    lea rcx, [rel chip8_stack]
    mov edx, [rcx + rax*4]
    mov [chip8_pc], edx
    jmp .cycle_done

; 1NNN: jump
.op_1:
    mov [chip8_pc], r11d
    jmp .cycle_done

; 2NNN: call
.op_2:
    mov eax, [chip8_sp]
    mov edx, [chip8_pc]
    lea rcx, [rel chip8_stack]
    mov [rcx + rax*4], edx
    inc eax
    mov [chip8_sp], eax
    mov [chip8_pc], r11d
    jmp .cycle_done

; 3XNN: skip if VX == NN
.op_3:
    movzx eax, byte [rdi + rbx]
    cmp eax, r13d
    jne .cycle_done
    add dword [chip8_pc], 2
    jmp .cycle_done

; 4XNN: skip if VX != NN
.op_4:
    movzx eax, byte [rdi + rbx]
    cmp eax, r13d
    je .cycle_done
    add dword [chip8_pc], 2
    jmp .cycle_done

; 5XY0: skip if VX == VY
.op_5:
    test r12d, r12d
    jnz .cycle_done
    movzx eax, byte [rdi + rbx]
    movzx edx, byte [rdi + rbp]
    cmp eax, edx
    jne .cycle_done
    add dword [chip8_pc], 2
    jmp .cycle_done

; 6XNN: VX = NN
.op_6:
    mov [rdi + rbx], r13b
    jmp .cycle_done

; 7XNN: VX += NN (no carry flag)
.op_7:
    add [rdi + rbx], r13b
    jmp .cycle_done

; 8XY?: ALU group
.op_8:
    cmp r12d, 0
    je .op_8xy0
    cmp r12d, 1
    je .op_8xy1
    cmp r12d, 2
    je .op_8xy2
    cmp r12d, 3
    je .op_8xy3
    cmp r12d, 4
    je .op_8xy4
    cmp r12d, 5
    je .op_8xy5
    cmp r12d, 6
    je .op_8xy6
    cmp r12d, 7
    je .op_8xy7
    cmp r12d, 0xE
    je .op_8xyE
    jmp .cycle_done
.op_8xy0:
    mov al, [rdi + rbp]
    mov [rdi + rbx], al
    jmp .cycle_done
.op_8xy1:
    mov al, [rdi + rbp]
    or [rdi + rbx], al
    jmp .cycle_done
.op_8xy2:
    mov al, [rdi + rbp]
    and [rdi + rbx], al
    jmp .cycle_done
.op_8xy3:
    mov al, [rdi + rbp]
    xor [rdi + rbx], al
    jmp .cycle_done
.op_8xy4:
    movzx eax, byte [rdi + rbx]
    movzx edx, byte [rdi + rbp]
    add eax, edx
    mov r9d, eax
    shr r9d, 8
    and r9d, 1
    mov [rdi + rbx], al
    mov [rdi + 15], r9b
    jmp .cycle_done
.op_8xy5:
    movzx eax, byte [rdi + rbx]
    movzx edx, byte [rdi + rbp]
    mov r9d, eax
    cmp r9d, edx
    setae r9b
    sub al, dl
    mov [rdi + rbx], al
    mov [rdi + 15], r9b
    jmp .cycle_done
.op_8xy6:
    cmp dword [quirk_shift_vy], 0
    jne .op_8xy6_vy
    movzx eax, byte [rdi + rbx]
    mov r9b, al
    and r9b, 1
    shr al, 1
    mov [rdi + rbx], al
    mov [rdi + 15], r9b
    jmp .cycle_done
.op_8xy6_vy:
    movzx eax, byte [rdi + rbp]
    mov r9b, al
    and r9b, 1
    shr al, 1
    mov [rdi + rbx], al
    mov [rdi + 15], r9b
    jmp .cycle_done
.op_8xy7:
    movzx eax, byte [rdi + rbx]
    movzx edx, byte [rdi + rbp]
    mov r9d, edx
    cmp r9d, eax
    setae r9b
    mov al, dl
    sub al, [rdi + rbx]
    mov [rdi + rbx], al
    mov [rdi + 15], r9b
    jmp .cycle_done
.op_8xyE:
    cmp dword [quirk_shift_vy], 0
    jne .op_8xyE_vy
    movzx eax, byte [rdi + rbx]
    mov r9b, al
    shr r9b, 7
    and r9b, 1
    shl al, 1
    mov [rdi + rbx], al
    mov [rdi + 15], r9b
    jmp .cycle_done
.op_8xyE_vy:
    movzx eax, byte [rdi + rbp]
    mov r9b, al
    shr r9b, 7
    and r9b, 1
    shl al, 1
    mov [rdi + rbx], al
    mov [rdi + 15], r9b
    jmp .cycle_done

; 9XY0: skip if VX != VY
.op_9:
    test r12d, r12d
    jnz .cycle_done
    movzx eax, byte [rdi + rbx]
    movzx edx, byte [rdi + rbp]
    cmp eax, edx
    je .cycle_done
    add dword [chip8_pc], 2
    jmp .cycle_done

; ANNN: I = NNN
.op_A:
    mov [chip8_I], r11d
    jmp .cycle_done

; BNNN: jump V0+NNN
.op_B:
    cmp dword [quirk_bnnn_vx], 0
    jne .op_B_vx
    movzx eax, byte [rdi + 0]
    add eax, r11d
    mov [chip8_pc], eax
    jmp .cycle_done
.op_B_vx:
    movzx eax, byte [rdi + rbx]
    add eax, r11d
    mov [chip8_pc], eax
    jmp .cycle_done

; CXNN: VX = rand & NN
.op_C:
    call chip8_rand
    and eax, r13d
    mov [rdi + rbx], al
    jmp .cycle_done

; DXYN: draw sprite
.op_D:
    movzx eax, byte [rdi + rbx]
    and eax, 63
    mov r8d, eax                    ; x0
    movzx eax, byte [rdi + rbp]
    and eax, 31
    mov r9d, eax                    ; y0
    mov byte [rdi + 15], 0
    lea rbx, [rel chip8_display]
    xor r14d, r14d                  ; row
.d_rowloop:
    cmp r14d, r12d
    jae .d_done
    mov eax, r9d
    add eax, r14d                   ; yy
    cmp eax, 32
    jae .d_done
    mov r15d, eax                   ; yy
    mov eax, [chip8_I]
    add eax, r14d
    movzx edx, byte [rsi + rax]     ; sprite byte (rsi = chip8_mem)
    xor ecx, ecx                    ; col
.d_colloop:
    cmp ecx, 8
    jae .d_rownext
    mov eax, r8d
    add eax, ecx                    ; xx
    cmp eax, 64
    jae .d_rownext
    mov r10d, 7
    sub r10d, ecx
    mov r11d, edx
    push rcx
    mov ecx, r10d
    shr r11d, cl
    pop rcx
    and r11d, 1
    test r11d, r11d
    jz .d_nextcol
    mov r13d, r15d
    imul r13d, 64
    add r13d, eax
    cmp byte [rbx + r13], 1
    jne .d_setpix
    mov byte [rdi + 15], 1
.d_setpix:
    xor byte [rbx + r13], 1
.d_nextcol:
    inc ecx
    jmp .d_colloop
.d_rownext:
    inc r14d
    jmp .d_rowloop
.d_done:
    mov byte [chip8_draw_flag], 1
    jmp .cycle_done

; EX9E / EXA1: key skip
.op_E:
    cmp r13d, 0x9E
    je .op_Ex9E
    cmp r13d, 0xA1
    je .op_ExA1
    jmp .cycle_done
.op_Ex9E:
    movzx eax, byte [rdi + rbx]
    lea rdx, [rel chip8_keys]
    cmp byte [rdx + rax], 1
    jne .cycle_done
    add dword [chip8_pc], 2
    jmp .cycle_done
.op_ExA1:
    movzx eax, byte [rdi + rbx]
    lea rdx, [rel chip8_keys]
    cmp byte [rdx + rax], 1
    je .cycle_done
    add dword [chip8_pc], 2
    jmp .cycle_done

; FX??: misc group
.op_F:
    cmp r13d, 0x07
    je .op_Fx07
    cmp r13d, 0x0A
    je .op_Fx0A
    cmp r13d, 0x15
    je .op_Fx15
    cmp r13d, 0x18
    je .op_Fx18
    cmp r13d, 0x1E
    je .op_Fx1E
    cmp r13d, 0x29
    je .op_Fx29
    cmp r13d, 0x33
    je .op_Fx33
    cmp r13d, 0x55
    je .op_Fx55
    cmp r13d, 0x65
    je .op_Fx65
    jmp .cycle_done
.op_Fx07:
    mov eax, [chip8_delay]
    mov [rdi + rbx], al
    jmp .cycle_done
.op_Fx0A:
    xor eax, eax
    lea rdx, [rel chip8_keys]
.fx0a_scan:
    cmp eax, 16
    jae .fx0a_none
    cmp byte [rdx + rax], 1
    je .fx0a_found
    inc eax
    jmp .fx0a_scan
.fx0a_found:
    mov [rdi + rbx], al
    jmp .cycle_done
.fx0a_none:
    sub dword [chip8_pc], 2         ; re-execute this instruction next cycle
    jmp .cycle_done
.op_Fx15:
    movzx eax, byte [rdi + rbx]
    mov [chip8_delay], eax
    jmp .cycle_done
.op_Fx18:
    movzx eax, byte [rdi + rbx]
    mov [chip8_sound], eax
    jmp .cycle_done
.op_Fx1E:
    mov eax, [chip8_I]
    movzx edx, byte [rdi + rbx]
    add eax, edx
    mov ecx, 0
    cmp eax, 0x1000
    jb .fx1e_nocarry
    mov ecx, 1
.fx1e_nocarry:
    mov [chip8_I], eax
    mov [rdi + 15], cl
    jmp .cycle_done
.op_Fx29:
    movzx eax, byte [rdi + rbx]
    imul eax, eax, 5
    add eax, CHIP8_FONT_BASE
    mov [chip8_I], eax
    jmp .cycle_done
.op_Fx33:
    movzx eax, byte [rdi + rbx]
    xor edx, edx
    mov ecx, 100
    div ecx
    mov r8d, edx                    ; remainder 0-99
    mov r9b, al                     ; hundreds digit
    xor edx, edx
    mov eax, r8d
    mov ecx, 10
    div ecx                         ; eax=tens digit, edx=ones digit
    mov r10d, [chip8_I]
    mov [rsi + r10], r9b
    mov [rsi + r10 + 1], al
    mov [rsi + r10 + 2], dl
    jmp .cycle_done
.op_Fx55:
    mov r10d, [chip8_I]
    xor ecx, ecx
.fx55_loop:
    cmp ecx, ebx
    jg .fx55_done
    mov al, [rdi + rcx]
    mov edx, r10d
    add edx, ecx
    mov [rsi + rdx], al
    inc ecx
    jmp .fx55_loop
.fx55_done:
    cmp dword [quirk_fx55_increment_i], 0
    je .cycle_done
    lea eax, [r10d + ebx + 1]
    mov [chip8_I], eax
    jmp .cycle_done
.op_Fx65:
    mov r10d, [chip8_I]
    xor ecx, ecx
.fx65_loop:
    cmp ecx, ebx
    jg .fx65_done
    mov edx, r10d
    add edx, ecx
    mov al, [rsi + rdx]
    mov [rdi + rcx], al
    inc ecx
    jmp .fx65_loop
.fx65_done:
    cmp dword [quirk_fx55_increment_i], 0
    je .cycle_done
    lea eax, [r10d + ebx + 1]
    mov [chip8_I], eax
    jmp .cycle_done

.cycle_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbp
    pop rbx
    ret
