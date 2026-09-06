BITS 64
default rel

%define SDL_INIT_VIDEO            0x00000020
%define SDL_INIT_AUDIO            0x00000010
%define SDL_WINDOWPOS_UNDEFINED   0x1FFF0000
%define SDL_WINDOW_SHOWN          0x00000004
%define SDL_RENDERER_ACCELERATED  0x00000002
%define SEEK_SET                  0
%define SEEK_END                  2
%define AUDIO_S16LSB              0x8010
%define SDL_QUIT_EVENT            0x100
%define SDL_KEYDOWN_EVENT         0x300
%define SDL_KEYUP_EVENT           0x301
%define SDL_DROPFILE_EVENT        0x1000
%define KEYCODE_ESCAPE            27
%define SDLK_F1                   0x4000003A
%define SDLK_F2                   0x4000003B
%define SDLK_F3                   0x4000003C
%define SDLK_F4                   0x4000003D

%define CHIP8_W             64
%define CHIP8_H             32
%define SCALE               10
%define WIN_W               (CHIP8_W*SCALE)
%define WIN_H               (CHIP8_H*SCALE)
%define DEFAULT_STEPS       12
%define BEEP_SAMPLES        4410
%define BEEP_BYTES          (BEEP_SAMPLES*2)

extern fopen
extern fread
extern fclose
extern fseek
extern ftell
extern puts
extern exit

extern SDL_Init
extern SDL_CreateWindow
extern SDL_CreateRenderer
extern SDL_DestroyRenderer
extern SDL_DestroyWindow
extern SDL_PollEvent
extern SDL_RenderClear
extern SDL_SetRenderDrawColor
extern SDL_RenderFillRect
extern SDL_RenderPresent
extern SDL_Quit
extern SDL_Delay
extern SDL_GetTicks
extern SDL_SetWindowTitle
extern SDL_OpenAudioDevice
extern SDL_QueueAudio
extern SDL_PauseAudioDevice
extern SDL_GetQueuedAudioSize
extern SDL_ClearQueuedAudio
extern SDL_free
extern SDL_EventState

global main

%include "chip8_core.inc"
%include "debug_render.inc"

section .data

base_title:     db "VCHIP8", 0
sep_dash:       db " - ", 0
usage_msg:      db "Usage: vchip8 [path-to-rom]", 10, "  (or launch with no ROM and load one isn't supported on Linux yet -- CLI only)", 10, 0
open_err_msg:   db "Error: could not open ROM file", 10, 0
mode_rb:        db "rb", 0

section .bss

rom_buffer:         resb 3584
rom_size:           resd 1
event_buf:          resb 64
rect_buf:           resb 16
audiospec_desired:  resb 32
audiospec_obtained: resb 32
beep_buffer:        resb BEEP_BYTES

window_ptr:         resq 1
renderer_ptr:       resq 1
audio_dev_id:       resd 1

current_scale:      resd 1
cycles_per_frame:   resd 1
sound_enabled:      resd 1
rom_loaded:         resd 1

current_rom_path:   resb 260
current_rom_name:   resb 64
title_buffer:       resb 340

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov ebx, edi
    mov r12, rsi

    mov dword [current_scale], SCALE
    mov dword [cycles_per_frame], DEFAULT_STEPS
    mov dword [sound_enabled], 1
    mov dword [rom_loaded], 0
    mov dword [chip8_last_opcode], 0
    mov dword [quirk_shift_vy], 0
    mov dword [quirk_bnnn_vx], 0
    mov dword [quirk_fx55_increment_i], 0
    mov dword [debug_mode_enabled], 0

    call chip8_init

    mov edi, SDL_INIT_VIDEO | SDL_INIT_AUDIO
    call SDL_Init

    mov edi, SDL_DROPFILE_EVENT
    mov esi, 1                        ; SDL_ENABLE
    call SDL_EventState

    lea rdi, [rel base_title]
    mov esi, SDL_WINDOWPOS_UNDEFINED
    mov edx, SDL_WINDOWPOS_UNDEFINED
    mov ecx, WIN_W
    mov r8d, WIN_H
    mov r9d, SDL_WINDOW_SHOWN
    call SDL_CreateWindow
    mov [window_ptr], rax

    mov rdi, [window_ptr]
    mov esi, -1
    mov edx, SDL_RENDERER_ACCELERATED
    call SDL_CreateRenderer
    mov [renderer_ptr], rax

    lea rax, [rel audiospec_desired]
    mov dword [rax+0], 44100
    mov word  [rax+4], AUDIO_S16LSB
    mov byte  [rax+6], 1
    mov byte  [rax+7], 0
    mov word  [rax+8], 1024
    mov word  [rax+10], 0
    mov dword [rax+12], 0
    mov qword [rax+16], 0
    mov qword [rax+24], 0

    xor edi, edi
    xor esi, esi
    lea rdx, [rel audiospec_desired]
    lea rcx, [rel audiospec_obtained]
    xor r8d, r8d
    call SDL_OpenAudioDevice
    mov [audio_dev_id], eax

    call gen_beep_buffer

    cmp ebx, 2
    jl .no_startup_rom
    mov rdi, [r12+8]                 ; argv[1]
    call load_rom_from_path
.no_startup_rom:

    cmp dword [rom_loaded], 0
    je .no_title_update
    call update_window_title
.no_title_update:

    ; prime an initial blank frame
    mov rdi, [renderer_ptr]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    call SDL_SetRenderDrawColor
    mov rdi, [renderer_ptr]
    call SDL_RenderClear
    mov rdi, [renderer_ptr]
    call SDL_RenderPresent

.mainloop:
    call SDL_GetTicks
    mov r15d, eax

.eventloop:
    lea rdi, [rel event_buf]
    call SDL_PollEvent
    test eax, eax
    jz .events_done

    mov eax, [event_buf]
    cmp eax, SDL_QUIT_EVENT
    je .quit
    cmp eax, SDL_KEYDOWN_EVENT
    je .handle_keydown
    cmp eax, SDL_KEYUP_EVENT
    je .handle_keyup
    cmp eax, SDL_DROPFILE_EVENT
    je .handle_dropfile
    jmp .eventloop

.handle_dropfile:
    mov rbx, [event_buf+8]            ; char* file path, SDL-allocated
    mov rdi, rbx
    call load_rom_from_path
    mov rdi, rbx
    call SDL_free
    jmp .eventloop

.handle_keydown:
    mov eax, [event_buf+20]
    cmp eax, KEYCODE_ESCAPE
    je .quit
    cmp eax, SDLK_F1
    je .toggle_debug
    cmp eax, SDLK_F2
    je .toggle_q1
    cmp eax, SDLK_F3
    je .toggle_q2
    cmp eax, SDLK_F4
    je .toggle_q3
    call map_key
    cmp eax, -1
    je .eventloop
    mov edi, eax
    call chip8_key_down
    jmp .eventloop
.toggle_debug:
    xor dword [debug_mode_enabled], 1
    jmp .eventloop
.toggle_q1:
    xor dword [quirk_shift_vy], 1
    jmp .eventloop
.toggle_q2:
    xor dword [quirk_bnnn_vx], 1
    jmp .eventloop
.toggle_q3:
    xor dword [quirk_fx55_increment_i], 1
    jmp .eventloop

.handle_keyup:
    mov eax, [event_buf+20]
    call map_key
    cmp eax, -1
    je .eventloop
    mov edi, eax
    call chip8_key_up
    jmp .eventloop

.events_done:
    cmp dword [rom_loaded], 0
    je .after_cycles

    mov ecx, [cycles_per_frame]
.cycleloop:
    push rcx
    call chip8_cycle
    pop rcx
    dec ecx
    jnz .cycleloop

    call chip8_timer_tick
.after_cycles:

    ; ---- audio ----
    mov eax, [chip8_sound]
    test eax, eax
    jz .no_beep
    cmp dword [sound_enabled], 0
    je .no_beep
    mov edi, [audio_dev_id]
    call SDL_GetQueuedAudioSize
    cmp eax, BEEP_BYTES
    jae .skip_queue
    lea rsi, [rel beep_buffer]
    mov edi, [audio_dev_id]
    mov edx, BEEP_BYTES
    call SDL_QueueAudio
.skip_queue:
    mov edi, [audio_dev_id]
    xor esi, esi
    call SDL_PauseAudioDevice
    jmp .audio_done
.no_beep:
    mov edi, [audio_dev_id]
    mov esi, 1
    call SDL_PauseAudioDevice
    mov edi, [audio_dev_id]
    call SDL_ClearQueuedAudio
.audio_done:

    ; ---- render ----
    cmp byte [chip8_draw_flag], 0
    jne .do_render
    cmp dword [rom_loaded], 0
    je .do_render
    cmp dword [debug_mode_enabled], 0
    je .skip_render
.do_render:
    mov rdi, [renderer_ptr]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    mov r8d, 255
    call SDL_SetRenderDrawColor
    mov rdi, [renderer_ptr]
    call SDL_RenderClear

    mov rdi, [renderer_ptr]
    mov esi, 255
    mov edx, 255
    mov ecx, 255
    mov r8d, 255
    call SDL_SetRenderDrawColor

    xor ebx, ebx
    lea rbp, [rel chip8_display]      ; callee-saved -- survives the SDL calls below
.pixloop:
    cmp ebx, 2048
    jae .pix_done
    cmp dword [rom_loaded], 0
    jne .pix_use_display
    call chip8_rand
    and eax, 1
    jz .pix_next
    jmp .pix_draw
.pix_use_display:
    cmp byte [rbp + rbx], 0
    je .pix_next
.pix_draw:
    mov eax, ebx
    and eax, 63
    imul eax, eax, SCALE
    mov [rect_buf+0], eax
    mov eax, ebx
    shr eax, 6
    imul eax, eax, SCALE
    mov [rect_buf+4], eax
    mov dword [rect_buf+8], SCALE
    mov dword [rect_buf+12], SCALE
    mov rdi, [renderer_ptr]
    lea rsi, [rel rect_buf]
    call SDL_RenderFillRect
.pix_next:
    inc ebx
    jmp .pixloop
.pix_done:
    mov byte [chip8_draw_flag], 0

    cmp dword [debug_mode_enabled], 0
    je .present_now
    call render_debug_overlay
.present_now:
    mov rdi, [renderer_ptr]
    call SDL_RenderPresent
.skip_render:

    call SDL_GetTicks
    sub eax, r15d
    cmp eax, 16
    jae .mainloop
    mov edi, 16
    sub edi, eax
    call SDL_Delay
    jmp .mainloop

.quit:
    mov rdi, [renderer_ptr]
    call SDL_DestroyRenderer
    mov rdi, [window_ptr]
    call SDL_DestroyWindow
    call SDL_Quit
    xor edi, edi
    call exit

load_rom_from_path:
    push rbx
    push r12
    push r13

    mov r12, rdi

    lea rsi, [rel mode_rb]
    mov rdi, r12
    call fopen
    test rax, rax
    jnz .open_ok
    lea rdi, [rel open_err_msg]
    call puts
    xor eax, eax
    jmp .done
.open_ok:
    mov r13, rax

    mov rdi, r13
    xor esi, esi
    mov edx, SEEK_END
    call fseek

    mov rdi, r13
    call ftell
    mov ebx, eax

    mov rdi, r13
    xor esi, esi
    mov edx, SEEK_SET
    call fseek

    lea rdi, [rel rom_buffer]
    mov esi, 1
    mov rdx, rbx
    mov rcx, r13
    call fread

    mov rdi, r13
    call fclose

    mov [rom_size], ebx

    call chip8_init

    lea rdi, [rel rom_buffer]
    mov esi, [rom_size]
    call chip8_load_rom

    lea rdi, [rel current_rom_path]
    mov rsi, r12
    mov ecx, 259
    call copy_cstr_capped

    call extract_rom_name
    mov dword [rom_loaded], 1
    call update_window_title

    mov eax, 1
.done:
    pop r13
    pop r12
    pop rbx
    ret

draw_rect:
    push rax
    push rdi
    push rsi
    push rdx
    push rcx
    push r12

    mov eax, edi
    mov [dbg_rect_buf+0], eax
    mov eax, esi
    mov [dbg_rect_buf+4], eax
    mov eax, edx
    mov [dbg_rect_buf+8], eax
    mov eax, ecx
    mov [dbg_rect_buf+12], eax

    mov r12, rsp
    and rsp, -16
    mov rdi, [renderer_ptr]
    lea rsi, [rel dbg_rect_buf]
    call SDL_RenderFillRect
    mov rsp, r12

    pop r12
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

set_debug_color:
    push r10
    push r11
    push r12
    push r13
    mov r10d, edi
    mov r11d, esi
    mov r12d, edx

    mov r13, rsp
    and rsp, -16
    mov rdi, [renderer_ptr]
    mov esi, r10d
    mov edx, r11d
    mov ecx, r12d
    mov r8d, 255
    call SDL_SetRenderDrawColor
    mov rsp, r13

    pop r13
    pop r12
    pop r11
    pop r10
    ret

;   1 2 3 4          1 2 3 C
;   Q W E R    -->   4 5 6 D
;   A S D F          7 8 9 E
;   Z X C V          A 0 B F

map_key:
    cmp eax, '1'
    jne .n1
    mov eax, 0x1
    ret
.n1:
    cmp eax, '2'
    jne .n2
    mov eax, 0x2
    ret
.n2:
    cmp eax, '3'
    jne .n3
    mov eax, 0x3
    ret
.n3:
    cmp eax, '4'
    jne .n4
    mov eax, 0xC
    ret
.n4:
    cmp eax, 'q'
    jne .n5
    mov eax, 0x4
    ret
.n5:
    cmp eax, 'w'
    jne .n6
    mov eax, 0x5
    ret
.n6:
    cmp eax, 'e'
    jne .n7
    mov eax, 0x6
    ret
.n7:
    cmp eax, 'r'
    jne .n8
    mov eax, 0xD
    ret
.n8:
    cmp eax, 'a'
    jne .n9
    mov eax, 0x7
    ret
.n9:
    cmp eax, 's'
    jne .n10
    mov eax, 0x8
    ret
.n10:
    cmp eax, 'd'
    jne .n11
    mov eax, 0x9
    ret
.n11:
    cmp eax, 'f'
    jne .n12
    mov eax, 0xE
    ret
.n12:
    cmp eax, 'z'
    jne .n13
    mov eax, 0xA
    ret
.n13:
    cmp eax, 'x'
    jne .n14
    mov eax, 0x0
    ret
.n14:
    cmp eax, 'c'
    jne .n15
    mov eax, 0xB
    ret
.n15:
    cmp eax, 'v'
    jne .none
    mov eax, 0xF
    ret
.none:
    mov eax, -1
    ret

gen_beep_buffer:
    xor ecx, ecx
.genloop:
    cmp ecx, BEEP_SAMPLES
    jae .gendone
    mov eax, ecx
    xor edx, edx
    mov ebx, 100
    div ebx
    cmp edx, 50
    jb .pos
    mov ax, -3000
    jmp .store
.pos:
    mov ax, 3000
.store:
    mov edx, ecx
    lea rdi, [rel beep_buffer]
    mov [rdi + rdx*2], ax
    inc ecx
    jmp .genloop
.gendone:
    ret

extract_rom_name:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9

    lea rsi, [rel current_rom_path]
    xor ebx, ebx
    xor edx, edx
.scan1:
    movzx eax, byte [rsi+rbx]
    test al, al
    jz .scan1_done
    cmp al, '\'
    je .found_slash
    cmp al, '/'
    je .found_slash
    inc ebx
    jmp .scan1
.found_slash:
    lea edx, [ebx+1]
    inc ebx
    jmp .scan1
.scan1_done:
    mov ecx, ebx
.scan2:
    cmp ecx, edx
    jle .scan2_done
    dec ecx
    movzx eax, byte [rsi+rcx]
    cmp al, '.'
    je .scan2_done
    jmp .scan2
.scan2_done:
    cmp ecx, edx
    jne .have_end
    movzx eax, byte [rsi+rcx]
    cmp al, '.'
    je .have_end
    mov ecx, ebx
.have_end:
    lea rdi, [rel current_rom_name]
    xor eax, eax
.copyloop:
    mov r8d, edx
    add r8d, eax
    cmp r8d, ecx
    jge .copydone
    cmp eax, 63
    jae .copydone
    movzx r9d, byte [rsi + r8]
    mov [rdi+rax], r9b
    inc eax
    jmp .copyloop
.copydone:
    mov byte [rdi+rax], 0

    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

update_window_title:
    push rax
    push rcx
    push rsi
    push rdi

    lea rdi, [rel title_buffer]
    lea rsi, [rel base_title]
    call copy_cstr

    cmp byte [rel current_rom_name], 0
    je .settitle

    lea rsi, [rel title_buffer]
    call strlen_of
    lea rdi, [rel title_buffer]
    add rdi, rax
    lea rsi, [rel sep_dash]
    call copy_cstr

    lea rsi, [rel title_buffer]
    call strlen_of
    lea rdi, [rel title_buffer]
    add rdi, rax
    lea rsi, [rel current_rom_name]
    call copy_cstr

.settitle:
    mov rdi, [window_ptr]
    lea rsi, [rel title_buffer]
    call SDL_SetWindowTitle

    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret
