; entry points:
;   chip8_init        reset machine state, load font, seed RNG
;   chip8_load_rom    rdi = buffer, esi = size in bytes
;   chip8_cycle       execute one instruction
;   chip8_timer_tick  call at 60Hz
;   chip8_key_down    dil = key 0-F
;   chip8_key_up      dil = key 0-F

; ---------------------------------------------------------------------------
; data
; ---------------------------------------------------------------------------

section .data

align 16
chip8_fontset:
    db 0xF0, 0x90, 0x90, 0x90, 0xF0     ; 0
    db 0x20, 0x60, 0x20, 0x20, 0x70     ; 1
    db 0xF0, 0x10, 0xF0, 0x80, 0xF0     ; 2
    db 0xF0, 0x10, 0xF0, 0x10, 0xF0     ; 3
    db 0x90, 0x90, 0xF0, 0x10, 0x10     ; 4
    db 0xF0, 0x80, 0xF0, 0x10, 0xF0     ; 5
    db 0xF0, 0x80, 0xF0, 0x90, 0xF0     ; 6
    db 0xF0, 0x10, 0x20, 0x40, 0x40     ; 7
    db 0xF0, 0x90, 0xF0, 0x90, 0xF0     ; 8
    db 0xF0, 0x90, 0xF0, 0x10, 0xF0     ; 9
    db 0xF0, 0x90, 0xF0, 0x90, 0x90     ; A
    db 0xE0, 0x90, 0xE0, 0x90, 0xE0     ; B
    db 0xF0, 0x80, 0x80, 0x80, 0xF0     ; C
    db 0xE0, 0x90, 0x90, 0x90, 0xE0     ; D
    db 0xF0, 0x80, 0xF0, 0x80, 0xF0     ; E
    db 0xF0, 0x80, 0xF0, 0x80, 0x80     ; F

%define CHIP8_FONT_BASE 0x50
%define CHIP8_ROM_BASE  0x200

section .bss

align 16
chip8_mem:              resb 4096   ; 4K RAM
chip8_V:                resb 16     ; V0-VF
chip8_I:                resd 1      ; index register (12 bits used)
chip8_pc:               resd 1
chip8_sp:               resd 1
chip8_stack:            resd 16
chip8_delay:            resd 1      ; delay timer, counts down at 60Hz
chip8_sound:            resd 1      ; sound timer, counts down at 60Hz
chip8_display:          resb 2048   ; 64x32, one byte per pixel (0 or 1)
chip8_keys:             resb 16     ; 1 = held
chip8_draw_flag:        resb 1      ; set whenever the framebuffer changes
chip8_rng_state:        resd 1
chip8_last_opcode:      resd 1      ; for the debug overlay

; quirks. All default to 0 (modern behaviour), 1 selects the COSMAC VIP one.
quirk_shift_vy:         resd 1      ; 8XY6/8XYE shift VY into VX
quirk_bnnn_vx:          resd 1      ; BNNN jumps to NNN + VX instead of NNN + V0
quirk_fx55_increment_i: resd 1      ; FX55/FX65 leave I += X + 1

; ---------------------------------------------------------------------------
; code
; ---------------------------------------------------------------------------

section .text

; zero `count` bytes at `label`. Needs al = 0; clobbers rdi, rcx.
%macro zero_bytes 2
    lea     rdi, [rel %1]
    mov     ecx, %2
    rep stosb
%endmacro

chip8_init:
    push    rdi
    push    rsi
    push    rcx
    push    rdx

    xor     eax, eax
    zero_bytes chip8_mem,     4096
    zero_bytes chip8_V,       16
    zero_bytes chip8_display, 2048
    zero_bytes chip8_keys,    16

    mov     dword [chip8_I], 0
    mov     dword [chip8_pc], CHIP8_ROM_BASE
    mov     dword [chip8_sp], 0
    mov     dword [chip8_delay], 0
    mov     dword [chip8_sound], 0
    mov     byte  [chip8_draw_flag], 0

    lea     rsi, [rel chip8_fontset]
    lea     rdi, [rel chip8_mem + CHIP8_FONT_BASE]
    mov     ecx, 80
    rep movsb

    rdtsc
    or      eax, 1                      ; xorshift gets stuck at 0
    mov     [chip8_rng_state], eax

    pop     rdx
    pop     rcx
    pop     rsi
    pop     rdi
    ret


; rdi = source buffer, esi = size. Anything past the end of RAM is dropped.
chip8_load_rom:
    push    rcx
    push    rsi
    push    rdi

    mov     ecx, esi
    mov     eax, 4096 - CHIP8_ROM_BASE
    cmp     ecx, eax
    cmova   ecx, eax

    mov     rsi, rdi
    lea     rdi, [rel chip8_mem + CHIP8_ROM_BASE]
    rep movsb

    pop     rdi
    pop     rsi
    pop     rcx
    ret


; xorshift32 (13, 17, 5). Returns the new value in eax.
chip8_rand:
    mov     eax, [chip8_rng_state]
    mov     edx, eax
    shl     edx, 13
    xor     eax, edx
    mov     edx, eax
    shr     edx, 17
    xor     eax, edx
    mov     edx, eax
    shl     edx, 5
    xor     eax, edx
    mov     [chip8_rng_state], eax
    ret


chip8_timer_tick:
    cmp     dword [chip8_delay], 0
    je      .sound
    dec     dword [chip8_delay]
.sound:
    cmp     dword [chip8_sound], 0
    je      .done
    dec     dword [chip8_sound]
.done:
    ret


chip8_key_down:
    movzx   eax, dil
    and     eax, 0xF
    lea     rdx, [rel chip8_keys]
    mov     byte [rdx + rax], 1
    ret

chip8_key_up:
    movzx   eax, dil
    and     eax, 0xF
    lea     rdx, [rel chip8_keys]
    mov     byte [rdx + rax], 0
    ret


; ---------------------------------------------------------------------------
; chip8_cycle: fetch, decode and execute one instruction.
;
; decoded fields live in registers for the whole function:
;
;   ecx   full opcode            r11d  NNN  (low 12 bits)
;   r10d  top nibble             r12d  N    (low nibble)
;   rbx   X  (bits 11-8)         r13d  NN   (low byte)
;   rbp   Y  (bits 7-4)
;
;   rdi   -> chip8_V             rsi   -> chip8_mem
; ---------------------------------------------------------------------------

%define V       rdi
%define RAM     rsi
%define X       rbx
%define Y       rbp
%define N       r12d
%define N64     r12
%define NN      r13d
%define NN8     r13b
%define NNN     r11d
%define VF      15

chip8_cycle:
    push    rbx
    push    rbp
    push    rdi
    push    rsi
    push    r12
    push    r13
    push    r14
    push    r15

    lea     V,   [rel chip8_V]
    lea     RAM, [rel chip8_mem]

    ; fetch (opcodes are big-endian in memory)
    mov     eax, [chip8_pc]
    movzx   ecx, word [RAM + rax]
    rol     cx, 8
    add     dword [chip8_pc], 2
    mov     [chip8_last_opcode], ecx

    ; decode
    mov     r10d, ecx
    shr     r10d, 12
    mov     NNN, ecx
    and     NNN, 0x0FFF
    mov     ebx, ecx
    shr     ebx, 8
    and     ebx, 0xF
    mov     ebp, ecx
    shr     ebp, 4
    and     ebp, 0xF
    mov     N, ecx
    and     N, 0xF
    movzx   NN, cl

    ; dispatch on the top nibble
    lea     rdx, [rel chip8_op_table]
    movsxd  rax, dword [rdx + r10*4]
    add     rax, rdx
    jmp     rax

; --- 0NNN: 00E0 clear, 00EE return ------------------------------------------
.op_0:
    cmp     ecx, 0x00E0
    je      .op_00E0
    cmp     ecx, 0x00EE
    je      .op_00EE
    jmp     .cycle_done

.op_00E0:
    lea     rdx, [rel chip8_display]
    mov     ecx, 2048 / 8
.clear:
    mov     qword [rdx + rcx*8 - 8], 0
    dec     ecx
    jnz     .clear
    mov     byte [chip8_draw_flag], 1
    jmp     .cycle_done

.op_00EE:
    mov     eax, [chip8_sp]
    dec     eax
    mov     [chip8_sp], eax
    lea     rdx, [rel chip8_stack]
    mov     eax, [rdx + rax*4]
    mov     [chip8_pc], eax
    jmp     .cycle_done

; --- 1NNN: jump -------------------------------------------------------------
.op_1:
    mov     [chip8_pc], NNN
    jmp     .cycle_done

; --- 2NNN: call -------------------------------------------------------------
.op_2:
    mov     eax, [chip8_sp]
    lea     rdx, [rel chip8_stack]
    mov     r8d, [chip8_pc]
    mov     [rdx + rax*4], r8d
    inc     dword [chip8_sp]
    mov     [chip8_pc], NNN
    jmp     .cycle_done

; --- 3XNN / 4XNN / 5XY0 / 9XY0: conditional skips ---------------------------
.op_3:                                  ; skip if VX == NN
    cmp     byte [V + X], NN8
    je      .skip_next
    jmp     .cycle_done

.op_4:                                  ; skip if VX != NN
    cmp     byte [V + X], NN8
    jne     .skip_next
    jmp     .cycle_done

.op_5:                                  ; skip if VX == VY
    test    N, N
    jnz     .cycle_done
    mov     al, [V + X]
    cmp     al, [V + Y]
    je      .skip_next
    jmp     .cycle_done

.op_9:                                  ; skip if VX != VY
    test    N, N
    jnz     .cycle_done
    mov     al, [V + X]
    cmp     al, [V + Y]
    jne     .skip_next
    jmp     .cycle_done

; --- 6XNN / 7XNN ------------------------------------------------------------
.op_6:
    mov     [V + X], NN8
    jmp     .cycle_done

.op_7:                                  ; no carry flag on this one
    add     [V + X], NN8
    jmp     .cycle_done

; --- 8XYN: ALU --------------------------------------------------------------
.op_8:
    lea     rdx, [rel chip8_alu_table]
    movsxd  rax, dword [rdx + N64*4]
    add     rax, rdx
    jmp     rax

.op_8xy0:                               ; VX = VY
    mov     al, [V + Y]
    mov     [V + X], al
    jmp     .cycle_done

.op_8xy1:                               ; VX |= VY
    mov     al, [V + Y]
    or      [V + X], al
    jmp     .cycle_done

.op_8xy2:                               ; VX &= VY
    mov     al, [V + Y]
    and     [V + X], al
    jmp     .cycle_done

.op_8xy3:                               ; VX ^= VY
    mov     al, [V + Y]
    xor     [V + X], al
    jmp     .cycle_done

.op_8xy4:                               ; VX += VY, VF = carry
    mov     al, [V + X]
    add     al, [V + Y]
    setc    dl
    mov     [V + X], al
    mov     [V + VF], dl                ; written last so VF wins if X == F
    jmp     .cycle_done

.op_8xy5:                               ; VX -= VY, VF = not borrow
    mov     al, [V + X]
    sub     al, [V + Y]
    setae   dl
    mov     [V + X], al
    mov     [V + VF], dl
    jmp     .cycle_done

.op_8xy7:                               ; VX = VY - VX, VF = not borrow
    mov     al, [V + Y]
    sub     al, [V + X]
    setae   dl
    mov     [V + X], al
    mov     [V + VF], dl
    jmp     .cycle_done

.op_8xy6:                               ; shift right, VF = bit shifted out
    mov     rdx, X
    cmp     dword [quirk_shift_vy], 0
    cmovne  rdx, Y                      ; quirk: shift VY instead
    mov     al, [V + rdx]
    shr     al, 1
    setc    r9b
    mov     [V + X], al
    mov     [V + VF], r9b
    jmp     .cycle_done

.op_8xyE:                               ; shift left, VF = bit shifted out
    mov     rdx, X
    cmp     dword [quirk_shift_vy], 0
    cmovne  rdx, Y
    mov     al, [V + rdx]
    shl     al, 1
    setc    r9b
    mov     [V + X], al
    mov     [V + VF], r9b
    jmp     .cycle_done

; --- ANNN / BNNN / CXNN -----------------------------------------------------
.op_A:
    mov     [chip8_I], NNN
    jmp     .cycle_done

.op_B:                                  ; jump to NNN + V0 (or + VX with the quirk)
    xor     edx, edx
    cmp     dword [quirk_bnnn_vx], 0
    cmovne  rdx, X
    movzx   eax, byte [V + rdx]
    add     eax, NNN
    mov     [chip8_pc], eax
    jmp     .cycle_done

.op_C:
    call    chip8_rand
    and     eax, NN
    mov     [V + X], al
    jmp     .cycle_done

.op_D:
    movzx   r8d, byte [V + X]
    and     r8d, 63                     ; x origin
    movzx   r9d, byte [V + Y]
    and     r9d, 31                     ; y origin
    mov     byte [V + VF], 0
    lea     r10, [rel chip8_display]
    xor     r14d, r14d                  ; current row

.draw_row:
    cmp     r14d, N
    jae     .draw_done
    lea     eax, [r9 + r14]             ; screen y
    cmp     eax, 32
    jae     .draw_done
    shl     eax, 6                      ; * 64
    lea     r15, [r10 + rax]            ; this row in the framebuffer

    mov     eax, [chip8_I]
    add     eax, r14d
    movzx   edx, byte [RAM + rax]       ; sprite byte for this row

    mov     ecx, r8d                    ; screen x
    mov     r13d, 8                     ; pixels left in this byte
.draw_col:
    cmp     ecx, 64
    jae     .draw_next_row
    shl     dl, 1                       ; next sprite bit -> carry
    jnc     .draw_skip
    cmp     byte [r15 + rcx], 0
    je      .draw_toggle
    mov     byte [V + VF], 1            ; erasing a lit pixel
.draw_toggle:
    xor     byte [r15 + rcx], 1
.draw_skip:
    inc     ecx
    dec     r13d
    jnz     .draw_col

.draw_next_row:
    inc     r14d
    jmp     .draw_row

.draw_done:
    mov     byte [chip8_draw_flag], 1
    jmp     .cycle_done

; --- EX9E / EXA1: skip on key state -----------------------------------------
.op_E:
    cmp     NN, 0x9E
    je      .op_Ex9E
    cmp     NN, 0xA1
    je      .op_ExA1
    jmp     .cycle_done

.op_Ex9E:                               ; skip if key VX is down
    movzx   eax, byte [V + X]
    and     eax, 0xF
    lea     rdx, [rel chip8_keys]
    cmp     byte [rdx + rax], 0
    jne     .skip_next
    jmp     .cycle_done

.op_ExA1:                               ; skip if key VX is up
    movzx   eax, byte [V + X]
    and     eax, 0xF
    lea     rdx, [rel chip8_keys]
    cmp     byte [rdx + rax], 0
    je      .skip_next
    jmp     .cycle_done

; --- FXNN -------------------------------------------------------------------
.op_F:
    cmp     NN, 0x07
    je      .op_Fx07
    cmp     NN, 0x0A
    je      .op_Fx0A
    cmp     NN, 0x15
    je      .op_Fx15
    cmp     NN, 0x18
    je      .op_Fx18
    cmp     NN, 0x1E
    je      .op_Fx1E
    cmp     NN, 0x29
    je      .op_Fx29
    cmp     NN, 0x33
    je      .op_Fx33
    cmp     NN, 0x55
    je      .op_Fx55
    cmp     NN, 0x65
    je      .op_Fx65
    jmp     .cycle_done

.op_Fx07:                               ; VX = delay timer
    mov     eax, [chip8_delay]
    mov     [V + X], al
    jmp     .cycle_done

.op_Fx0A:                               ; wait for a keypress, store it in VX
    lea     rdx, [rel chip8_keys]
    xor     eax, eax
.scan_keys:
    cmp     byte [rdx + rax], 0
    jne     .key_found
    inc     eax
    cmp     eax, 16
    jb      .scan_keys
    sub     dword [chip8_pc], 2         ; nothing pressed: run this opcode again
    jmp     .cycle_done
.key_found:
    mov     [V + X], al
    jmp     .cycle_done

.op_Fx15:                               ; delay timer = VX
    movzx   eax, byte [V + X]
    mov     [chip8_delay], eax
    jmp     .cycle_done

.op_Fx18:                               ; sound timer = VX
    movzx   eax, byte [V + X]
    mov     [chip8_sound], eax
    jmp     .cycle_done

.op_Fx1E:                               ; I += VX, VF = 1 if I leaves 12-bit range
    movzx   eax, byte [V + X]
    add     eax, [chip8_I]
    xor     edx, edx
    cmp     eax, 0x1000
    setae   dl
    mov     [chip8_I], eax
    mov     [V + VF], dl
    jmp     .cycle_done

.op_Fx29:                               ; I = address of font glyph for VX
    movzx   eax, byte [V + X]
    lea     eax, [rax + rax*4 + CHIP8_FONT_BASE]    ; glyphs are 5 bytes each
    mov     [chip8_I], eax
    jmp     .cycle_done

.op_Fx33:                               ; BCD of VX -> [I], [I+1], [I+2]
    movzx   eax, byte [V + X]
    mov     r8d, [chip8_I]
    mov     ecx, 10
    xor     edx, edx
    div     ecx                         ; eax = VX / 10, edx = ones
    mov     [RAM + r8 + 2], dl
    xor     edx, edx
    div     ecx                         ; eax = hundreds, edx = tens
    mov     [RAM + r8 + 1], dl
    mov     [RAM + r8], al
    jmp     .cycle_done

.op_Fx55:                               ; store V0..VX at [I]
    mov     r8d, [chip8_I]
    lea     r9, [RAM + r8]
    xor     ecx, ecx
.store_regs:
    mov     al, [V + rcx]
    mov     [r9 + rcx], al
    inc     ecx
    cmp     rcx, X
    jbe     .store_regs
    jmp     .fx_bump_i

.op_Fx65:                               ; load V0..VX from [I]
    mov     r8d, [chip8_I]
    lea     r9, [RAM + r8]
    xor     ecx, ecx
.load_regs:
    mov     al, [r9 + rcx]
    mov     [V + rcx], al
    inc     ecx
    cmp     rcx, X
    jbe     .load_regs

.fx_bump_i:                             ; COSMAC quirk: i ends up past the block
    cmp     dword [quirk_fx55_increment_i], 0
    je      .cycle_done
    lea     eax, [r8 + X + 1]
    mov     [chip8_I], eax
    jmp     .cycle_done

; --- common exits -----------------------------------------------------------
.skip_next:
    add     dword [chip8_pc], 2
.cycle_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rsi
    pop     rdi
    pop     rbp
    pop     rbx
    ret


; jump tables for chip8_cycle. 
; entries are 32-bit offsets from the start of
; the table, which keeps them position-independent.
align 4
chip8_op_table:
    dd chip8_cycle.op_0 - chip8_op_table
    dd chip8_cycle.op_1 - chip8_op_table
    dd chip8_cycle.op_2 - chip8_op_table
    dd chip8_cycle.op_3 - chip8_op_table
    dd chip8_cycle.op_4 - chip8_op_table
    dd chip8_cycle.op_5 - chip8_op_table
    dd chip8_cycle.op_6 - chip8_op_table
    dd chip8_cycle.op_7 - chip8_op_table
    dd chip8_cycle.op_8 - chip8_op_table
    dd chip8_cycle.op_9 - chip8_op_table
    dd chip8_cycle.op_A - chip8_op_table
    dd chip8_cycle.op_B - chip8_op_table
    dd chip8_cycle.op_C - chip8_op_table
    dd chip8_cycle.op_D - chip8_op_table
    dd chip8_cycle.op_E - chip8_op_table
    dd chip8_cycle.op_F - chip8_op_table

chip8_alu_table:
    dd chip8_cycle.op_8xy0 - chip8_alu_table
    dd chip8_cycle.op_8xy1 - chip8_alu_table
    dd chip8_cycle.op_8xy2 - chip8_alu_table
    dd chip8_cycle.op_8xy3 - chip8_alu_table
    dd chip8_cycle.op_8xy4 - chip8_alu_table
    dd chip8_cycle.op_8xy5 - chip8_alu_table
    dd chip8_cycle.op_8xy6 - chip8_alu_table
    dd chip8_cycle.op_8xy7 - chip8_alu_table
    times 6 dd chip8_cycle.cycle_done - chip8_alu_table     ; 8..D: undefined
    dd chip8_cycle.op_8xyE - chip8_alu_table
    dd chip8_cycle.cycle_done - chip8_alu_table             ; F: undefined
