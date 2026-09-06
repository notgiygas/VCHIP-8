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

%define CHIP8_W             64
%define CHIP8_H             32
%define BASE_UNIT           5           ; 1x = 5px/pixel, 2x = 10px/pixel, ...
%define WIN_W               (CHIP8_W*10)  ; initial window = 2x = 640x320
%define WIN_H               (CHIP8_H*10)
%define DEFAULT_STEPS       12
%define BEEP_SAMPLES        4410
%define BEEP_BYTES          (BEEP_SAMPLES*2)

%define WM_COMMAND          0x0111
%define MF_STRING           0x00000000
%define MF_POPUP            0x00000010
%define MF_SEPARATOR        0x00000800
%define MF_CHECKED          0x00000008
%define MF_UNCHECKED        0x00000000
%define GWLP_WNDPROC        -4
%define MB_OK               0x00000000
%define MB_ICONINFORMATION  0x00000040

%define ID_FILE_OPEN        1001
%define ID_FILE_EXIT        1002
%define ID_VIDEO_1X         1101
%define ID_VIDEO_2X         1102
%define ID_VIDEO_3X         1103
%define ID_STEPS_6          1201
%define ID_STEPS_12         1202
%define ID_STEPS_18         1203
%define ID_STEPS_24         1204
%define ID_SOUND_TOGGLE     1301
%define ID_DEBUG_TOGGLE     1302
%define ID_QUIRK_SHIFT      1401
%define ID_QUIRK_BNNN       1402
%define ID_QUIRK_FX55       1403
%define ID_HELP_ABOUT       1501
%define ID_HELP_CONTROLS    1502
%define ID_COLOR_FG         1601
%define ID_COLOR_BG         1602

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
extern SDL_SetWindowSize
extern SDL_OpenAudioDevice
extern SDL_QueueAudio
extern SDL_PauseAudioDevice
extern SDL_GetQueuedAudioSize
extern SDL_ClearQueuedAudio
extern SDL_free
extern SDL_EventState

extern CreateMenu
extern CreatePopupMenu
extern AppendMenuA
extern SetMenu
extern DrawMenuBar
extern CheckMenuItem
extern MessageBoxA
extern SetWindowLongPtrA
extern CallWindowProcA
extern FindWindowA
extern GetOpenFileNameA
extern ChooseColorA

global main

%include "chip8_core.inc"
%include "debug_render.inc"
%include "discord_rpc.inc"

section .data

base_title:      db "VCHIP8", 0
sep_dash:        db " - ", 0
mode_rb:         db "rb", 0

mstr_file:       db "&File", 0
mstr_open:       db "&Open ROM...", 0
mstr_exit:       db "&Exit", 0
mstr_options:    db "&Options", 0
mstr_video:      db "&Video", 0
mstr_1x:         db "1x  (320x160)", 0
mstr_2x:         db "2x  (640x320)", 0
mstr_3x:         db "3x  (960x480)", 0
mstr_steps:      db "&Steps/Ticks per frame", 0
mstr_steps6:     db "6", 0
mstr_steps12:    db "12  (default)", 0
mstr_steps18:    db "18", 0
mstr_steps24:    db "24", 0
mstr_sound:      db "&Sound Enabled", 0
mstr_debug:      db "&Debug Mode", 0
mstr_quirks:     db "&Quirks", 0
mstr_quirk_shift: db "8xy[6/E]: Put VY into VX before shift", 0
mstr_quirk_bnnn:  db "Bnnn: Use VX instead of V0", 0
mstr_quirk_fx55:  db "FX[56]5: Change value of I", 0
mstr_help:       db "&Help", 0
mstr_about:      db "&About VCHIP8...", 0
mstr_controls:   db "&Controls...", 0
mstr_colors:     db "&Colors", 0
mstr_color_fg:   db 'Foreground ("pixel on")...', 0
mstr_color_bg:   db 'Background ("pixel off")...', 0

controls_caption: db "VCHIP-8 Controls", 0
controls_text:
    db "The original CHIP-8 keypad was laid out like this:", 10, 10
    db "  1 2 3 C", 10
    db "  4 5 6 D", 10
    db "  7 8 9 E", 10
    db "  A 0 B F", 10, 10
    db "VCHIP-8 maps it onto your keyboard like this:", 10, 10
    db "  1 2 3 4", 10
    db "  Q W E R", 10
    db "  A S D F", 10
    db "  Z X C V", 10, 10
    db "(Esc quits the emulator.)", 0

about_caption:   db "About VCHIP8", 0
about_text:      db "VCHIP-8", 10, "A CHIP-8 emulator written entirely in x86-64 assembly.", 10, 10, "Programmed by GIYGAS.", 0

ofn_dialog_title: db "Open CHIP-8 ROM", 0
ofn_filter:       db "CHIP-8 ROMs", 0, "*.ch8;*.c8", 0, "All Files", 0, "*.*", 0, 0

section .bss

rom_buffer:          resb 3584
rom_size:            resd 1
event_buf:           resb 64
rect_buf:            resb 16
audiospec_desired:   resb 32
audiospec_obtained:  resb 32
beep_buffer:         resb BEEP_BYTES

window_ptr:          resq 1
renderer_ptr:        resq 1
audio_dev_id:        resd 1
main_hwnd:           resq 1
old_wndproc:         resq 1

video_menu_handle:   resq 1
steps_menu_handle:   resq 1
options_menu_handle: resq 1
quirks_menu_handle:  resq 1
colors_menu_handle:  resq 1

ui_scale:            resd 1     ; 1, 2 or 3
current_scale:       resd 1     ; ui_scale * BASE_UNIT (px per CHIP-8 pixel)
cycles_per_frame:    resd 1
sound_enabled:       resd 1
want_quit:           resd 1
rom_loaded:          resd 1

fg_color_r:          resd 1     ; "pixel on" color (defaults to white)
fg_color_g:          resd 1
fg_color_b:          resd 1
bg_color_r:          resd 1     ; "pixel off" / clear color (defaults to black)
bg_color_g:          resd 1
bg_color_b:          resd 1
custom_colors_buf:   resd 16    ; CHOOSECOLOR custom color array (required by the dialog)

current_rom_path:    resb 260
current_rom_name:    resb 64
title_buffer:        resb 340

ofn_struct:          resb 152
ofn_filepath:        resb 260

choosecolor_struct:  resb 72

section .text

main:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    mov ebx, ecx
    mov r12, rdx

    mov dword [ui_scale], 2
    mov dword [current_scale], 10
    mov dword [cycles_per_frame], DEFAULT_STEPS
    mov dword [sound_enabled], 1
    mov dword [want_quit], 0
    mov dword [rom_loaded], 0
    mov dword [chip8_last_opcode], 0
    mov dword [quirk_shift_vy], 0
    mov dword [quirk_bnnn_vx], 0
    mov dword [quirk_fx55_increment_i], 0
    mov dword [debug_mode_enabled], 0

    mov dword [fg_color_r], 255
    mov dword [fg_color_g], 255
    mov dword [fg_color_b], 255
    mov dword [bg_color_r], 0
    mov dword [bg_color_g], 0
    mov dword [bg_color_b], 0

    lea rax, [rel custom_colors_buf]
    xor ecx, ecx
.zero_custom_colors:
    mov dword [rax+rcx*4], 0x00FFFFFF
    inc ecx
    cmp ecx, 16
    jne .zero_custom_colors

    call chip8_init

    sub rsp, 32
    mov ecx, SDL_INIT_VIDEO | SDL_INIT_AUDIO
    call SDL_Init
    add rsp, 32

    sub rsp, 32
    mov ecx, SDL_DROPFILE_EVENT
    mov edx, 1                        ; SDL_ENABLE
    call SDL_EventState
    add rsp, 32

    sub rsp, 48
    lea rcx, [rel base_title]
    mov edx, SDL_WINDOWPOS_UNDEFINED
    mov r8d, SDL_WINDOWPOS_UNDEFINED
    mov r9d, WIN_W
    mov dword [rsp+32], WIN_H
    mov dword [rsp+40], SDL_WINDOW_SHOWN
    call SDL_CreateWindow
    add rsp, 48
    mov [window_ptr], rax

    sub rsp, 32
    mov rcx, [window_ptr]
    mov edx, -1
    mov r8d, SDL_RENDERER_ACCELERATED
    call SDL_CreateRenderer
    add rsp, 32
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

    sub rsp, 48
    xor ecx, ecx
    xor edx, edx
    lea r8, [rel audiospec_desired]
    lea r9, [rel audiospec_obtained]
    mov dword [rsp+32], 0
    call SDL_OpenAudioDevice
    add rsp, 48
    mov [audio_dev_id], eax

    call gen_beep_buffer

    sub rsp, 32
    xor ecx, ecx
    lea rdx, [rel base_title]
    call FindWindowA
    add rsp, 32
    mov [main_hwnd], rax

    call build_menu
    call install_wndproc
    call discord_init

    cmp ebx, 2
    jl .no_startup_rom
    mov rcx, [r12+8]                 ; argv[1]
    call load_rom_from_path
.no_startup_rom:

    cmp dword [rom_loaded], 0
    je .no_title_update
    call update_window_title
.no_title_update:

    sub rsp, 32
    mov rcx, [renderer_ptr]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call SDL_SetRenderDrawColor
    add rsp, 32
    sub rsp, 32
    mov rcx, [renderer_ptr]
    call SDL_RenderClear
    add rsp, 32
    sub rsp, 32
    mov rcx, [renderer_ptr]
    call SDL_RenderPresent
    add rsp, 32

.mainloop:
    sub rsp, 32
    call SDL_GetTicks
    add rsp, 32
    mov r15d, eax                    ; frame_start

.eventloop:
    sub rsp, 32
    lea rcx, [rel event_buf]
    call SDL_PollEvent
    add rsp, 32
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
    mov rcx, rbx
    call load_rom_from_path
    mov rcx, rbx
    sub rsp, 32
    call SDL_free
    add rsp, 32
    jmp .eventloop

.handle_keydown:
    mov eax, [event_buf+20]
    cmp eax, KEYCODE_ESCAPE
    je .quit
    call map_key
    cmp eax, -1
    je .eventloop
    mov edi, eax
    call chip8_key_down
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
    cmp dword [want_quit], 1
    je .quit

    cmp dword [rom_loaded], 0
    je .after_cycles

    mov ebx, [cycles_per_frame]
.cycleloop:
    call chip8_cycle
    dec ebx
    jnz .cycleloop

    call chip8_timer_tick
.after_cycles:

    ; ---- audio ----
    mov eax, [chip8_sound]
    test eax, eax
    jz .no_beep
    cmp dword [sound_enabled], 0
    je .no_beep
    sub rsp, 32
    mov ecx, [audio_dev_id]
    call SDL_GetQueuedAudioSize
    add rsp, 32
    cmp eax, BEEP_BYTES
    jae .skip_queue
    sub rsp, 32
    mov ecx, [audio_dev_id]
    lea rdx, [rel beep_buffer]
    mov r8d, BEEP_BYTES
    call SDL_QueueAudio
    add rsp, 32
.skip_queue:
    sub rsp, 32
    mov ecx, [audio_dev_id]
    xor edx, edx
    call SDL_PauseAudioDevice
    add rsp, 32
    jmp .audio_done
.no_beep:
    sub rsp, 32
    mov ecx, [audio_dev_id]
    mov edx, 1
    call SDL_PauseAudioDevice
    add rsp, 32
    sub rsp, 32
    mov ecx, [audio_dev_id]
    call SDL_ClearQueuedAudio
    add rsp, 32
.audio_done:

    ; ---- render ----
    cmp byte [chip8_draw_flag], 0
    jne .do_full_render
    cmp dword [rom_loaded], 0
    je .maybe_debug_only          ; nothing changed and a ROM is running -- skip
.do_full_render:

    sub rsp, 48
    mov rcx, [renderer_ptr]
    mov edx, [bg_color_r]
    mov r8d, [bg_color_g]
    mov r9d, [bg_color_b]
    mov dword [rsp+32], 255
    call SDL_SetRenderDrawColor
    add rsp, 48

    sub rsp, 32
    mov rcx, [renderer_ptr]
    call SDL_RenderClear
    add rsp, 32

    sub rsp, 48
    mov rcx, [renderer_ptr]
    mov edx, [fg_color_r]
    mov r8d, [fg_color_g]
    mov r9d, [fg_color_b]
    mov dword [rsp+32], 255
    call SDL_SetRenderDrawColor
    add rsp, 48

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
    mov eax, [current_scale]
    mov ecx, ebx
    and ecx, 63
    imul ecx, eax
    mov [rect_buf+0], ecx
    mov ecx, ebx
    shr ecx, 6
    imul ecx, eax
    mov [rect_buf+4], ecx
    mov [rect_buf+8], eax
    mov [rect_buf+12], eax
    sub rsp, 32
    mov rcx, [renderer_ptr]
    lea rdx, [rel rect_buf]
    call SDL_RenderFillRect
    add rsp, 32
.pix_next:
    inc ebx
    jmp .pixloop
.pix_done:
    mov byte [chip8_draw_flag], 0

    cmp dword [debug_mode_enabled], 0
    je .present_now
    call render_debug_overlay
.present_now:
    sub rsp, 32
    mov rcx, [renderer_ptr]
    call SDL_RenderPresent
    add rsp, 32
    jmp .skip_render

.maybe_debug_only:
    cmp dword [debug_mode_enabled], 0
    je .skip_render
    sub rsp, 48
    mov rcx, [renderer_ptr]
    mov edx, [bg_color_r]
    mov r8d, [bg_color_g]
    mov r9d, [bg_color_b]
    mov dword [rsp+32], 255
    call SDL_SetRenderDrawColor
    add rsp, 48
    sub rsp, 32
    mov rcx, [renderer_ptr]
    call SDL_RenderClear
    add rsp, 32
    sub rsp, 48
    mov rcx, [renderer_ptr]
    mov edx, [fg_color_r]
    mov r8d, [fg_color_g]
    mov r9d, [fg_color_b]
    mov dword [rsp+32], 255
    call SDL_SetRenderDrawColor
    add rsp, 48
    xor ebx, ebx
    lea rbp, [rel chip8_display]      ; callee-saved -- survives the SDL calls below
.dbg_pixloop:
    cmp ebx, 2048
    jae .dbg_pix_done
    cmp byte [rbp + rbx], 0
    je .dbg_pix_next
    mov eax, [current_scale]
    mov ecx, ebx
    and ecx, 63
    imul ecx, eax
    mov [rect_buf+0], ecx
    mov ecx, ebx
    shr ecx, 6
    imul ecx, eax
    mov [rect_buf+4], ecx
    mov [rect_buf+8], eax
    mov [rect_buf+12], eax
    sub rsp, 32
    mov rcx, [renderer_ptr]
    lea rdx, [rel rect_buf]
    call SDL_RenderFillRect
    add rsp, 32
.dbg_pix_next:
    inc ebx
    jmp .dbg_pixloop
.dbg_pix_done:
    call render_debug_overlay
    sub rsp, 32
    mov rcx, [renderer_ptr]
    call SDL_RenderPresent
    add rsp, 32
.skip_render:

    sub rsp, 32
    call SDL_GetTicks
    add rsp, 32
    sub eax, r15d
    cmp eax, 16
    jae .mainloop
    sub rsp, 32
    mov ecx, 16
    sub ecx, eax
    call SDL_Delay
    add rsp, 32
    jmp .mainloop

.quit:
    call discord_shutdown
    sub rsp, 32
    mov rcx, [renderer_ptr]
    call SDL_DestroyRenderer
    add rsp, 32
    sub rsp, 32
    mov rcx, [window_ptr]
    call SDL_DestroyWindow
    add rsp, 32
    sub rsp, 32
    call SDL_Quit
    add rsp, 32
    sub rsp, 32
    xor ecx, ecx
    call exit
    add rsp, 32

load_rom_from_path:
    push rbx
    push r12
    push r13

    mov r12, rcx

    sub rsp, 40
    mov rcx, r12
    lea rdx, [rel mode_rb]
    call fopen
    add rsp, 40
    test rax, rax
    jnz .open_ok
    xor eax, eax
    jmp .done
.open_ok:
    mov r13, rax

    sub rsp, 40
    mov rcx, r13
    xor edx, edx
    mov r8d, SEEK_END
    call fseek
    add rsp, 40

    sub rsp, 40
    mov rcx, r13
    call ftell
    add rsp, 40
    mov ebx, eax

    sub rsp, 40
    mov rcx, r13
    xor edx, edx
    mov r8d, SEEK_SET
    call fseek
    add rsp, 40

    sub rsp, 40
    lea rcx, [rel rom_buffer]
    mov edx, 1
    mov r8d, ebx
    mov r9, r13
    call fread
    add rsp, 40

    sub rsp, 40
    mov rcx, r13
    call fclose
    add rsp, 40

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
    call discord_set_playing

    mov eax, 1
.done:
    pop r13
    pop r12
    pop rbx
    ret

open_rom_dialog:
    push rbx

    lea rdi, [rel ofn_struct]
    xor ecx, ecx
.zero1:
    mov byte [rdi+rcx], 0
    inc ecx
    cmp ecx, 152
    jne .zero1

    mov byte [rel ofn_filepath], 0

    lea rax, [rel ofn_struct]
    mov dword [rax+0], 152
    mov rbx, [main_hwnd]
    mov [rax+8], rbx
    lea rbx, [rel ofn_filter]
    mov [rax+24], rbx
    lea rbx, [rel ofn_filepath]
    mov [rax+48], rbx
    mov dword [rax+56], 260
    lea rbx, [rel ofn_dialog_title]
    mov [rax+88], rbx
    mov dword [rax+96], 0x00001804

    sub rsp, 40
    lea rcx, [rel ofn_struct]
    call GetOpenFileNameA
    add rsp, 40
    test eax, eax
    jz .cancelled

    lea rcx, [rel ofn_filepath]
    call load_rom_from_path

.cancelled:
    pop rbx
    ret

build_menu:
    push rbx
    push rsi
    push r12
    push r13
    push r14
    push r15

    sub rsp, 40
    call CreatePopupMenu
    add rsp, 40
    mov r12, rax                     ; file menu

    sub rsp, 40
    mov rcx, r12
    mov edx, MF_STRING
    mov r8d, ID_FILE_OPEN
    lea r9, [rel mstr_open]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r12
    mov edx, MF_SEPARATOR
    xor r8, r8
    xor r9, r9
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r12
    mov edx, MF_STRING
    mov r8d, ID_FILE_EXIT
    lea r9, [rel mstr_exit]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    call CreatePopupMenu
    add rsp, 40
    mov r13, rax                     ; video submenu
    mov [video_menu_handle], r13

    sub rsp, 40
    mov rcx, r13
    mov edx, MF_STRING
    mov r8d, ID_VIDEO_1X
    lea r9, [rel mstr_1x]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, r13
    mov edx, MF_STRING
    mov r8d, ID_VIDEO_2X
    lea r9, [rel mstr_2x]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, r13
    mov edx, MF_STRING
    mov r8d, ID_VIDEO_3X
    lea r9, [rel mstr_3x]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    call CreatePopupMenu
    add rsp, 40
    mov r14, rax                     ; colors submenu (video submenu no longer needed via r13)
    mov [colors_menu_handle], r14

    sub rsp, 40
    mov rcx, r14
    mov edx, MF_STRING
    mov r8d, ID_COLOR_FG
    lea r9, [rel mstr_color_fg]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, r14
    mov edx, MF_STRING
    mov r8d, ID_COLOR_BG
    lea r9, [rel mstr_color_bg]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    call CreatePopupMenu
    add rsp, 40
    mov r14, rax                     ; steps/ticks submenu
    mov [steps_menu_handle], r14

    sub rsp, 40
    mov rcx, r14
    mov edx, MF_STRING
    mov r8d, ID_STEPS_6
    lea r9, [rel mstr_steps6]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, r14
    mov edx, MF_STRING
    mov r8d, ID_STEPS_12
    lea r9, [rel mstr_steps12]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, r14
    mov edx, MF_STRING
    mov r8d, ID_STEPS_18
    lea r9, [rel mstr_steps18]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, r14
    mov edx, MF_STRING
    mov r8d, ID_STEPS_24
    lea r9, [rel mstr_steps24]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    call CreatePopupMenu
    add rsp, 40
    mov rbx, rax                     ; quirks submenu
    mov [quirks_menu_handle], rbx

    sub rsp, 40
    mov rcx, rbx
    mov edx, MF_STRING
    mov r8d, ID_QUIRK_SHIFT
    lea r9, [rel mstr_quirk_shift]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, rbx
    mov edx, MF_STRING
    mov r8d, ID_QUIRK_BNNN
    lea r9, [rel mstr_quirk_bnnn]
    call AppendMenuA
    add rsp, 40
    sub rsp, 40
    mov rcx, rbx
    mov edx, MF_STRING
    mov r8d, ID_QUIRK_FX55
    lea r9, [rel mstr_quirk_fx55]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    call CreatePopupMenu
    add rsp, 40
    mov r15, rax                     ; options (top-level) menu
    mov [options_menu_handle], r15

    sub rsp, 40
    mov rcx, r15
    mov edx, MF_POPUP
    mov r8, r13
    lea r9, [rel mstr_video]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r15
    mov edx, MF_POPUP
    mov r8, r14
    lea r9, [rel mstr_steps]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r15
    mov edx, MF_POPUP
    mov r8, rbx
    lea r9, [rel mstr_quirks]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r15
    mov edx, MF_POPUP
    mov r8, [colors_menu_handle]
    lea r9, [rel mstr_colors]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r15
    mov edx, MF_SEPARATOR
    xor r8, r8
    xor r9, r9
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r15
    mov edx, MF_STRING
    mov r8d, ID_SOUND_TOGGLE
    lea r9, [rel mstr_sound]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r15
    mov edx, MF_STRING
    mov r8d, ID_DEBUG_TOGGLE
    lea r9, [rel mstr_debug]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    call CreatePopupMenu
    add rsp, 40
    mov r13, rax                     ; help menu (r13/video submenu no longer needed)

    sub rsp, 40
    mov rcx, r13
    mov edx, MF_STRING
    mov r8d, ID_HELP_CONTROLS
    lea r9, [rel mstr_controls]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, r13
    mov edx, MF_STRING
    mov r8d, ID_HELP_ABOUT
    lea r9, [rel mstr_about]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    call CreateMenu
    add rsp, 40
    mov rsi, rax                     ; menu bar

    sub rsp, 40
    mov rcx, rsi
    mov edx, MF_POPUP
    mov r8, r12
    lea r9, [rel mstr_file]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, rsi
    mov edx, MF_POPUP
    mov r8, r15
    lea r9, [rel mstr_options]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, rsi
    mov edx, MF_POPUP
    mov r8, r13
    lea r9, [rel mstr_help]
    call AppendMenuA
    add rsp, 40

    sub rsp, 40
    mov rcx, [main_hwnd]
    mov rdx, rsi
    call SetMenu
    add rsp, 40

    sub rsp, 40
    mov rcx, [window_ptr]
    mov edx, WIN_W
    mov r8d, WIN_H
    call SDL_SetWindowSize
    add rsp, 40

    call refresh_checkmarks

    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rbx
    ret

refresh_checkmarks:
    push rbx
    push r12

    sub rsp, 40
    mov rcx, [video_menu_handle]
    mov edx, ID_VIDEO_1X
    mov r8d, MF_UNCHECKED
    call CheckMenuItem
    add rsp, 40
    sub rsp, 40
    mov rcx, [video_menu_handle]
    mov edx, ID_VIDEO_2X
    mov r8d, MF_UNCHECKED
    call CheckMenuItem
    add rsp, 40
    sub rsp, 40
    mov rcx, [video_menu_handle]
    mov edx, ID_VIDEO_3X
    mov r8d, MF_UNCHECKED
    call CheckMenuItem
    add rsp, 40

    mov eax, [ui_scale]
    mov r12d, ID_VIDEO_2X
    cmp eax, 1
    jne .notv1
    mov r12d, ID_VIDEO_1X
.notv1:
    cmp eax, 3
    jne .notv3
    mov r12d, ID_VIDEO_3X
.notv3:
    sub rsp, 40
    mov rcx, [video_menu_handle]
    mov edx, r12d
    mov r8d, MF_CHECKED
    call CheckMenuItem
    add rsp, 40

    sub rsp, 40
    mov rcx, [steps_menu_handle]
    mov edx, ID_STEPS_6
    mov r8d, MF_UNCHECKED
    call CheckMenuItem
    add rsp, 40
    sub rsp, 40
    mov rcx, [steps_menu_handle]
    mov edx, ID_STEPS_12
    mov r8d, MF_UNCHECKED
    call CheckMenuItem
    add rsp, 40
    sub rsp, 40
    mov rcx, [steps_menu_handle]
    mov edx, ID_STEPS_18
    mov r8d, MF_UNCHECKED
    call CheckMenuItem
    add rsp, 40
    sub rsp, 40
    mov rcx, [steps_menu_handle]
    mov edx, ID_STEPS_24
    mov r8d, MF_UNCHECKED
    call CheckMenuItem
    add rsp, 40

    mov eax, [cycles_per_frame]
    mov r12d, ID_STEPS_12
    cmp eax, 6
    jne .nots6
    mov r12d, ID_STEPS_6
.nots6:
    cmp eax, 18
    jne .nots18
    mov r12d, ID_STEPS_18
.nots18:
    cmp eax, 24
    jne .nots24
    mov r12d, ID_STEPS_24
.nots24:
    sub rsp, 40
    mov rcx, [steps_menu_handle]
    mov edx, r12d
    mov r8d, MF_CHECKED
    call CheckMenuItem
    add rsp, 40

    mov r12d, MF_UNCHECKED
    cmp dword [sound_enabled], 0
    je .soundoff
    mov r12d, MF_CHECKED
.soundoff:
    sub rsp, 40
    mov rcx, [options_menu_handle]
    mov edx, ID_SOUND_TOGGLE
    mov r8d, r12d
    call CheckMenuItem
    add rsp, 40

    mov r12d, MF_UNCHECKED
    cmp dword [debug_mode_enabled], 0
    je .debugoff
    mov r12d, MF_CHECKED
.debugoff:
    sub rsp, 40
    mov rcx, [options_menu_handle]
    mov edx, ID_DEBUG_TOGGLE
    mov r8d, r12d
    call CheckMenuItem
    add rsp, 40

    mov r12d, MF_UNCHECKED
    cmp dword [quirk_shift_vy], 0
    je .qshiftoff
    mov r12d, MF_CHECKED
.qshiftoff:
    sub rsp, 40
    mov rcx, [quirks_menu_handle]
    mov edx, ID_QUIRK_SHIFT
    mov r8d, r12d
    call CheckMenuItem
    add rsp, 40

    mov r12d, MF_UNCHECKED
    cmp dword [quirk_bnnn_vx], 0
    je .qbnnnoff
    mov r12d, MF_CHECKED
.qbnnnoff:
    sub rsp, 40
    mov rcx, [quirks_menu_handle]
    mov edx, ID_QUIRK_BNNN
    mov r8d, r12d
    call CheckMenuItem
    add rsp, 40

    mov r12d, MF_UNCHECKED
    cmp dword [quirk_fx55_increment_i], 0
    je .qfx55off
    mov r12d, MF_CHECKED
.qfx55off:
    sub rsp, 40
    mov rcx, [quirks_menu_handle]
    mov edx, ID_QUIRK_FX55
    mov r8d, r12d
    call CheckMenuItem
    add rsp, 40

    sub rsp, 40
    mov rcx, [main_hwnd]
    call DrawMenuBar
    add rsp, 40

    pop r12
    pop rbx
    ret

pick_color:
    push rbx
    push rsi
    push r12

    mov ebx, edi                     ; which color (0=fg, 1=bg)

    lea rsi, [rel choosecolor_struct]
    xor ecx, ecx
.zero_ccs:
    mov byte [rsi+rcx], 0
    inc ecx
    cmp ecx, 72
    jne .zero_ccs

    test ebx, ebx
    jnz .use_bg
    mov eax, [fg_color_r]
    mov edx, [fg_color_g]
    mov r8d, [fg_color_b]
    jmp .have_rgb
.use_bg:
    mov eax, [bg_color_r]
    mov edx, [bg_color_g]
    mov r8d, [bg_color_b]
.have_rgb:
    ; pack as COLORREF 0x00BBGGRR
    shl edx, 8
    or eax, edx
    shl r8d, 16
    or eax, r8d

    mov dword [rsi+0], 72            ; lStructSize
    mov rdx, [main_hwnd]
    mov [rsi+8], rdx                 ; hwndOwner
    mov [rsi+24], eax                ; rgbResult (initial color shown)
    lea rdx, [rel custom_colors_buf]
    mov [rsi+32], rdx                ; lpCustColors
    mov dword [rsi+40], 3            ; CC_RGBINIT | CC_FULLOPEN

    mov r12, rsp
    and rsp, -16
    sub rsp, 32
    mov rcx, rsi
    call ChooseColorA
    mov rsp, r12

    test eax, eax
    jz .cancelled                    ; user hit Cancel -- leave colors alone

    mov eax, [rsi+24]                ; rgbResult
    mov ecx, eax
    and ecx, 0xFF                    ; r
    mov edx, eax
    shr edx, 8
    and edx, 0xFF                    ; g
    mov r8d, eax
    shr r8d, 16
    and r8d, 0xFF                    ; b

    test ebx, ebx
    jnz .store_bg
    mov [fg_color_r], ecx
    mov [fg_color_g], edx
    mov [fg_color_b], r8d
    jmp .cancelled
.store_bg:
    mov [bg_color_r], ecx
    mov [bg_color_g], edx
    mov [bg_color_b], r8d

.cancelled:
    mov byte [chip8_draw_flag], 1    ; force a repaint with the (possibly new) colors
    pop r12
    pop rsi
    pop rbx
    ret

apply_video_scale:
    push r10
    push r11
    push r12

    mov eax, [ui_scale]
    imul eax, eax, BASE_UNIT
    mov [current_scale], eax
    mov r10d, eax
    imul r10d, r10d, CHIP8_W
    mov r11d, eax
    imul r11d, r11d, CHIP8_H

    mov r12, rsp
    and rsp, -16
    sub rsp, 32
    mov rcx, [window_ptr]
    mov edx, r10d
    mov r8d, r11d
    call SDL_SetWindowSize
    mov rsp, r12

    call refresh_checkmarks

    pop r12
    pop r11
    pop r10
    ret

install_wndproc:
    sub rsp, 40
    mov rcx, [main_hwnd]
    mov edx, GWLP_WNDPROC
    lea r8, [rel vchip8_wndproc]
    call SetWindowLongPtrA
    add rsp, 40
    mov [old_wndproc], rax
    ret

vchip8_wndproc:
    push rbx
    push rbp
    push rdi
    push rsi
    push r12
    push r13
    push r14
    push r15

    mov r12, rcx                     ; save hwnd for use by handlers below

    cmp edx, WM_COMMAND
    je .handle_command
    jmp .forward

.handle_command:
    mov eax, r8d
    and eax, 0xFFFF
    cmp eax, ID_FILE_OPEN
    je .do_open
    cmp eax, ID_FILE_EXIT
    je .do_exit
    cmp eax, ID_VIDEO_1X
    je .do_video1x
    cmp eax, ID_VIDEO_2X
    je .do_video2x
    cmp eax, ID_VIDEO_3X
    je .do_video3x
    cmp eax, ID_STEPS_6
    je .do_steps6
    cmp eax, ID_STEPS_12
    je .do_steps12
    cmp eax, ID_STEPS_18
    je .do_steps18
    cmp eax, ID_STEPS_24
    je .do_steps24
    cmp eax, ID_SOUND_TOGGLE
    je .do_sound_toggle
    cmp eax, ID_DEBUG_TOGGLE
    je .do_debug_toggle
    cmp eax, ID_QUIRK_SHIFT
    je .do_quirk_shift
    cmp eax, ID_QUIRK_BNNN
    je .do_quirk_bnnn
    cmp eax, ID_QUIRK_FX55
    je .do_quirk_fx55
    cmp eax, ID_HELP_ABOUT
    je .do_about
    cmp eax, ID_HELP_CONTROLS
    je .do_controls
    cmp eax, ID_COLOR_FG
    je .do_color_fg
    cmp eax, ID_COLOR_BG
    je .do_color_bg
    xor eax, eax
    jmp .epilogue

.do_open:
    call open_rom_dialog
    xor eax, eax
    jmp .epilogue

.do_exit:
    mov dword [want_quit], 1
    xor eax, eax
    jmp .epilogue

.do_video1x:
    mov dword [ui_scale], 1
    call apply_video_scale
    xor eax, eax
    jmp .epilogue
.do_video2x:
    mov dword [ui_scale], 2
    call apply_video_scale
    xor eax, eax
    jmp .epilogue
.do_video3x:
    mov dword [ui_scale], 3
    call apply_video_scale
    xor eax, eax
    jmp .epilogue

.do_steps6:
    mov dword [cycles_per_frame], 6
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue
.do_steps12:
    mov dword [cycles_per_frame], 12
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue
.do_steps18:
    mov dword [cycles_per_frame], 18
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue
.do_steps24:
    mov dword [cycles_per_frame], 24
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue

.do_sound_toggle:
    xor dword [sound_enabled], 1
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue

.do_debug_toggle:
    xor dword [debug_mode_enabled], 1
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue

.do_quirk_shift:
    xor dword [quirk_shift_vy], 1
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue
.do_quirk_bnnn:
    xor dword [quirk_bnnn_vx], 1
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue
.do_quirk_fx55:
    xor dword [quirk_fx55_increment_i], 1
    call refresh_checkmarks
    xor eax, eax
    jmp .epilogue

.do_about:
    mov r14, rsp
    and rsp, -16
    sub rsp, 32
    mov rcx, r12
    lea rdx, [rel about_text]
    lea r8, [rel about_caption]
    mov r9d, MB_OK | MB_ICONINFORMATION
    call MessageBoxA
    mov rsp, r14
    xor eax, eax
    jmp .epilogue

.do_controls:
    mov r14, rsp
    and rsp, -16
    sub rsp, 32
    mov rcx, r12
    lea rdx, [rel controls_text]
    lea r8, [rel controls_caption]
    mov r9d, MB_OK | MB_ICONINFORMATION
    call MessageBoxA
    mov rsp, r14
    xor eax, eax
    jmp .epilogue

.do_color_fg:
    xor edi, edi
    call pick_color
    xor eax, eax
    jmp .epilogue

.do_color_bg:
    mov edi, 1
    call pick_color
    xor eax, eax
    jmp .epilogue

.forward:
    mov r10, rcx
    mov r11, rdx
    mov rax, r9
    mov r9, r8
    mov r8, r11
    mov rdx, r10
    mov rcx, [old_wndproc]
    mov r14, rsp
    and rsp, -16
    sub rsp, 48
    mov [rsp+32], rax
    call CallWindowProcA
    mov rsp, r14
    jmp .epilogue

.epilogue:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rbp
    pop rbx
    ret

draw_rect:
    push rax
    push rcx
    push rdx
    push r8
    push r9
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
    sub rsp, 32
    mov rcx, [renderer_ptr]
    lea rdx, [rel dbg_rect_buf]
    call SDL_RenderFillRect
    mov rsp, r12

    pop r12
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
    ret

set_debug_color:
    push rax
    push r10
    push r11
    push r12
    mov r10d, edi
    mov r11d, esi
    mov eax, edx

    mov r12, rsp
    and rsp, -16
    sub rsp, 48
    mov rcx, [renderer_ptr]
    mov edx, r10d
    mov r8d, r11d
    mov r9d, eax
    mov dword [rsp+32], 255
    call SDL_SetRenderDrawColor
    mov rsp, r12

    pop r12
    pop r11
    pop r10
    pop rax
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
    lea r10, [rel beep_buffer]
    mov [r10 + rdx*2], ax
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
    push r12

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
    mov r12, rsp
    and rsp, -16
    sub rsp, 32
    mov rcx, [window_ptr]
    lea rdx, [rel title_buffer]
    call SDL_SetWindowTitle
    mov rsp, r12

    pop r12
    pop rdi
    pop rsi
    pop rcx
    pop rax
    ret
