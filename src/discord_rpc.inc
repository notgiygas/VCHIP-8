extern CreateFileA
extern WriteFile
extern CloseHandle
extern GetCurrentProcessId
extern time

%define GENERIC_READ        0x80000000
%define GENERIC_WRITE       0x40000000
%define OPEN_EXISTING       3

section .data

discord_pipe_name:      db '\\.\pipe\discord-ipc-0', 0
discord_client_id:      db '1234567890123456789', 0   ; <-- put application ID here later
discord_activity_state: db 'Emulating CHIP-8', 0

j_handshake_1: db '{"v":1,"client_id":"', 0
j_handshake_2: db '"}', 0
j_frame_1:     db '{"cmd":"SET_ACTIVITY","args":{"pid":', 0
j_frame_2:     db ',"activity":{"details":"Playing ', 0
j_frame_3:     db '","state":"', 0
j_frame_4:     db '","timestamps":{"start":', 0
j_frame_5:     db '}}},"nonce":"1"}', 0

section .bss

discord_pipe_handle:  resq 1
discord_connected:    resd 1
discord_bytes_out:    resd 1
discord_num_buf:      resb 16
discord_json_buf:     resb 768
discord_frame_buf:    resb 784      ; 8-byte header + discord_json_buf, some slack

section .text

discord_uint_to_dec:
    push rbx
    push rcx
    push rdx
    push rsi

    lea rsi, [rel discord_num_buf]
    mov eax, edi
    test eax, eax
    jnz .nonzero
    mov byte [rsi], '0'
    mov byte [rsi+1], 0
    mov eax, 1
    jmp .done
.nonzero:
    xor ecx, ecx                    ; digit count
.divloop:
    test eax, eax
    jz .divdone
    xor edx, edx
    mov ebx, 10
    div ebx                         ; eax/=10, edx=eax%10
    add edx, '0'
    mov [rsi+rcx], dl
    inc ecx
    jmp .divloop
.divdone:
    ; digits were written least-significant-first -- reverse them in place
    xor eax, eax
    mov edx, ecx
    dec edx
.revloop:
    cmp eax, edx
    jge .revdone
    mov bl, [rsi+rax]
    mov bh, [rsi+rdx]
    mov [rsi+rax], bh
    mov [rsi+rdx], bl
    inc eax
    dec edx
    jmp .revloop
.revdone:
    mov byte [rsi+rcx], 0
    mov eax, ecx
.done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

discord_send_frame:
    cmp dword [discord_connected], 0
    je .out

    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14

    mov ebx, edi                     ; opcode
    mov r13d, edx                    ; json length
    lea rdi, [rel discord_frame_buf]
    mov [rdi+0], ebx                 ; opcode, little-endian (native store)
    mov [rdi+4], r13d                ; length, little-endian (native store)

    xor ecx, ecx
.copyloop:
    cmp ecx, r13d
    jae .copydone
    mov al, [rsi+rcx]
    mov [rdi+8+rcx], al
    inc ecx
    jmp .copyloop
.copydone:
    lea r14d, [r13d+8]                ; total bytes = header(8) + json

    mov r12, rsp
    and rsp, -16
    sub rsp, 48
    mov rcx, [discord_pipe_handle]
    lea rdx, [rel discord_frame_buf]
    mov r8d, r14d
    lea r9, [rel discord_bytes_out]
    mov qword [rsp+32], 0            ; lpOverlapped = NULL
    call WriteFile
    mov rsp, r12

    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
.out:
    ret

discord_init:
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r12

    mov dword [discord_connected], 0

    lea rcx, [rel discord_pipe_name]
    mov edx, GENERIC_READ | GENERIC_WRITE
    xor r8d, r8d                     ; dwShareMode = 0
    xor r9d, r9d                     ; lpSecurityAttributes = NULL

    mov r12, rsp
    and rsp, -16
    sub rsp, 64
    mov dword [rsp+32], OPEN_EXISTING
    mov dword [rsp+40], 0            ; dwFlagsAndAttributes = 0
    mov qword [rsp+48], 0            ; hTemplateFile = NULL
    call CreateFileA
    mov rsp, r12

    cmp rax, -1                      ; INVALID_HANDLE_VALUE
    je .done
    mov [discord_pipe_handle], rax
    mov dword [discord_connected], 1

    ; build {"v":1,"client_id":"<id>"} into discord_json_buf
    lea rdi, [rel discord_json_buf]
    lea rsi, [rel j_handshake_1]
    call copy_cstr
    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel discord_client_id]
    call copy_cstr
    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel j_handshake_2]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    mov edx, eax
    lea rsi, [rel discord_json_buf]
    xor edi, edi                     ; opcode 0 = Handshake
    call discord_send_frame

.done:
    pop r12
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

discord_set_playing:
    cmp dword [discord_connected], 0
    je .out

    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r12

    mov r12, rsp
    and rsp, -16
    sub rsp, 32
    call GetCurrentProcessId
    mov rsp, r12
    mov edi, eax
    call discord_uint_to_dec

    lea rdi, [rel discord_json_buf]
    lea rsi, [rel j_frame_1]
    call copy_cstr
    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel discord_num_buf]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel j_frame_2]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel current_rom_name]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel j_frame_3]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel discord_activity_state]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel j_frame_4]
    call copy_cstr

    mov r12, rsp
    and rsp, -16
    sub rsp, 32
    xor ecx, ecx                     ; time(NULL)
    call time
    mov rsp, r12
    mov edi, eax
    call discord_uint_to_dec
    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel discord_num_buf]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    lea rdi, [rel discord_json_buf]
    add rdi, rax
    lea rsi, [rel j_frame_5]
    call copy_cstr

    lea rsi, [rel discord_json_buf]
    call strlen_of
    mov edx, eax
    lea rsi, [rel discord_json_buf]
    mov edi, 1                       ; opcode 1 = Frame
    call discord_send_frame

    pop r12
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
.out:
    ret

discord_shutdown:
    cmp dword [discord_connected], 0
    je .out
    push rcx
    push r12
    mov r12, rsp
    and rsp, -16
    sub rsp, 32
    mov rcx, [discord_pipe_handle]
    call CloseHandle
    mov rsp, r12
    mov dword [discord_connected], 0
    pop r12
    pop rcx
.out:
    ret
