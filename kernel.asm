[org 0x0000]
[bits 16]

KERNEL_SEG equ 0x1000
PROGRAM_SEG equ 0x4000

start:
    mov ax, KERNEL_SEG
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFF00

    mov ax, 0x0003
    int 0x10

    mov si, welcome_msg
    call kernel_print

shell_loop:
    call shell_prompt
    call shell_read_command
    call shell_execute
    jmp shell_loop

; ========== СИСТЕМНЫЕ ВЫЗОВЫ ==========
kernel_print:
    pusha
    mov ah, 0x0E
    mov bx, 0x0007
.print_loop:
    lodsb
    test al, al
    jz .print_done
    int 0x10
    jmp .print_loop
.print_done:
    popa
    ret

kernel_print_color:
    pusha
    mov ah, 0x09
.printc_loop:
    lodsb
    test al, al
    jz .printc_done
    mov cx, 1
    int 0x10
    inc byte [cursor_pos]
    jmp .printc_loop
.printc_done:
    popa
    ret

kernel_newline:
    pusha
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    popa
    ret

print_hex_byte:
    pusha
    push ax
    mov ah, al
    shr al, 4
    call print_nibble
    mov al, ah
    and al, 0x0F
    call print_nibble
    pop ax
    popa
    ret
    
print_nibble:
    cmp al, 0x0A
    jl .digit
    add al, 0x07
.digit:
    add al, 0x30
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    ret

str_to_hex:
    push bx
    push cx
    push si
    xor ax, ax
    xor cx, cx
    mov bx, 0
    
.str_loop:
    lodsb
    test al, al
    jz .str_check
    cmp al, ' '
    je .str_check
    cmp al, 0x09
    je .str_check
    cmp al, 0x0D
    je .str_check
    cmp al, 0x0A
    je .str_check
    
    cmp al, '0'
    jb .str_error
    cmp al, '9'
    jbe .str_digit
    cmp al, 'A'
    jb .str_error
    cmp al, 'F'
    jbe .str_hex
    cmp al, 'a'
    jb .str_error
    cmp al, 'f'
    jbe .str_hex_lower
    jmp .str_error
    
.str_digit:
    sub al, '0'
    jmp .str_store
.str_hex:
    sub al, 'A'
    add al, 10
    jmp .str_store
.str_hex_lower:
    sub al, 'a'
    add al, 10
.str_store:
    inc bx
    shl cx, 4
    or cl, al
    jmp .str_loop
    
.str_check:
    cmp bx, 0
    je .str_error
    mov ax, cx
    clc
    jmp .str_exit
    
.str_error:
    xor ax, ax
    stc
    
.str_exit:
    pop si
    pop cx
    pop bx
    ret

kernel_readline:
    pusha
    xor cx, cx
    mov di, command_buffer
.readline_input:
    mov ah, 0x00
    int 0x16
    
    cmp al, 0x0D
    je .readline_done
    
    cmp al, 0x08
    je .readline_backspace
    
    cmp al, 0x20
    jb .readline_input
    
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    
    stosb
    inc cx
    jmp .readline_input
    
.readline_backspace:
    cmp cx, 0
    je .readline_input
    
    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    
    dec cx
    dec di
    jmp .readline_input
    
.readline_done:
    mov al, 0
    stosb
    popa
    ret

; ========== ЗАГРУЗЧИК ПРОГРАММ ==========
load_program:
    pusha
    push es
    
    mov ah, 0x00
    mov dl, 0x80
    int 0x13
    jc .load_error
    
    mov ax, PROGRAM_SEG
    mov es, ax
    xor bx, bx
    
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, [loaded_sector]
    cmp cl, 0
    je .load_error
    mov dh, 0
    mov dl, 0x80
    int 0x13
    jc .load_error
    
    pop es
    clc
    popa
    ret
    
.load_error:
    pop es
    stc
    popa
    ret

run_program:
    pusha
    push ds
    push es
    
    mov al, [loaded_sector]
    cmp al, 0
    je .run_error
    
    mov ax, PROGRAM_SEG
    mov ds, ax
    mov es, ax
    
    call 0x4000:0x0000
    
    mov ax, KERNEL_SEG
    mov ds, ax
    mov es, ax
    
    pop es
    pop ds
    clc
    popa
    ret
    
.run_error:
    pop es
    pop ds
    stc
    popa
    ret

; ========== SHELL КОМАНДЫ ==========
shell_prompt:
    mov si, prompt_str
    call kernel_print
    ret

shell_read_command:
    call kernel_readline
    call kernel_newline
    ret

shell_execute:
    call get_command_word
    
    mov si, cmd_help
    call shell_strcmp
    jc .do_help
    
    mov si, cmd_cls
    call shell_strcmp
    jc .do_cls
    
    mov si, cmd_echo
    call shell_strcmp
    jc .do_echo
    
    mov si, cmd_color
    call shell_strcmp
    jc .do_color
    
    mov si, cmd_reboot
    call shell_strcmp
    jc .do_reboot
    
    mov si, cmd_ver
    call shell_strcmp
    jc .do_ver
    
    mov si, cmd_out
    call shell_strcmp
    jc .do_out
    
    mov si, cmd_in
    call shell_strcmp
    jc .do_in
    
;    mov si, cmd_serial
;    call shell_strcmp
;    jc .do_serial
;    
;    mov si, cmd_parallel
;    call shell_strcmp
;    jc .do_parallel
    
    mov si, cmd_beep
    call shell_strcmp
    jc .do_beep
    
    mov si, cmd_load
    call shell_strcmp
    jc .do_load
    
    mov si, cmd_run
    call shell_strcmp
    jc .do_run
    
    mov si, unknown_cmd
    call kernel_print
    call kernel_newline
    ret
    
    jmp .done

; ========== ОБРАБОТЧИКИ КОМАНД ==========
.do_help:
    mov si, help_text
    call kernel_print
    ret

.do_cls:
    mov ax, 0x0003
    int 0x10
    ret

.do_echo:
    call get_argument
    mov si, argument_buffer
    call kernel_print
    call kernel_newline
    ret

.do_color:
    mov si, color_msg
    mov bl, 0x0A
    call kernel_print_color
    call kernel_newline
    ret

.do_reboot:
    mov si, reboot_msg
    call kernel_print
    call kernel_newline
    mov al, 0xFE
    out 0x64, al
    cli
    hlt
    ret

.do_ver:
    mov si, ver_msg
    call kernel_print
    ret

.do_out:
    call get_argument
    mov si, argument_buffer
    call str_to_hex
    jc .out_error
    mov bx, ax
    
    call skip_to_next_arg
    call str_to_hex
    jc .out_error
    
    mov dx, bx
    out dx, al
    
    mov si, out_success
    call kernel_print
    ret
    
.out_error:
    mov si, out_error_msg
    call kernel_print
    ret

.do_in:
    call get_argument
    mov si, argument_buffer
    call str_to_hex
    jc .in_error
    
    mov dx, ax
    in al, dx
    
    mov si, in_result
    call kernel_print
    call print_hex_byte
    call kernel_newline
    ret
    
.in_error:
    mov si, in_error_msg
    call kernel_print
    ret

;.do_serial:
;    mov si, serial_test
;    call kernel_print
;    mov si, serial_no_response
;    call kernel_print
;    ret

;.do_parallel:
;    mov si, parallel_test
;    call kernel_print
;    mov si, parallel_done
;    call kernel_print
;    ret

.do_beep:
    mov si, beep_msg
    call kernel_print
    in al, 0x61
    or al, 0x03
    out 0x61, al
    mov al, 0xB6
    out 0x43, al
    mov ax, 1193
    out 0x42, al
    mov al, ah
    out 0x42, al
    mov cx, 0xFFFF
.beep_delay:
    loop .beep_delay
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    ret

.do_load:
    call get_argument
    mov si, argument_buffer
    
    mov al, [si]
    cmp al, 0
    je .load_no_arg
    
    call str_to_hex
    jc .load_error
    
    cmp ax, 0
    je .load_error
    cmp ax, 100
    jg .load_error
    
    mov [loaded_sector], al
    
    mov si, loading_msg
    call kernel_print
    mov al, [loaded_sector]
    call print_hex_byte
    call kernel_newline
    
    call load_program
    jc .load_error
    
    mov si, load_success
    call kernel_print
    ret
    
.load_no_arg:
    mov si, load_no_arg_msg
    call kernel_print
    ret
    
.load_error:
    mov si, load_error_msg
    call kernel_print
    mov byte [loaded_sector], 0
    ret

.do_run:
    mov al, [loaded_sector]
    cmp al, 0
    je .run_no_program
    
    mov si, running_msg
    call kernel_print
    call kernel_newline
    
    call run_program
    
    mov si, return_msg
    call kernel_print
    ret
    
.run_no_program:
    mov si, run_no_program_msg
    call kernel_print
    ret

.done:
    ret

; ========== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ==========
get_command_word:
    push si
    push di
    mov si, command_buffer
    mov di, command_word
.gcw_skip_spaces:
    lodsb
    cmp al, ' '
    je .gcw_skip_spaces
    cmp al, 0x09
    je .gcw_skip_spaces
    test al, al
    jz .gcw_done
.gcw_copy:
    cmp al, ' '
    je .gcw_done
    cmp al, 0x09
    je .gcw_done
    test al, al
    jz .gcw_done
    stosb
    lodsb
    jmp .gcw_copy
.gcw_done:
    mov al, 0
    stosb
    pop di
    pop si
    ret

shell_strcmp:
    push si
    push di
    push cx
    mov di, command_word
.ss_loop:
    mov cl, [di]
    mov ch, [si]
    cmp cl, ch
    jne .ss_not_equal
    test cl, cl
    jz .ss_equal
    inc si
    inc di
    jmp .ss_loop
.ss_not_equal:
    clc
    jmp .ss_exit
.ss_equal:
    stc
.ss_exit:
    pop cx
    pop di
    pop si
    ret

get_argument:
    push si
    push di
    mov si, command_buffer
    mov di, argument_buffer
.ga_skip_command:
    lodsb
    test al, al
    jz .ga_done
    cmp al, ' '
    je .ga_skip_spaces
    cmp al, 0x09
    je .ga_skip_spaces
    jmp .ga_skip_command
.ga_skip_spaces:
    lodsb
    cmp al, ' '
    je .ga_skip_spaces
    cmp al, 0x09
    je .ga_skip_spaces
    test al, al
    jz .ga_done
.ga_copy_arg:
    cmp al, 0
    je .ga_done
    stosb
    lodsb
    jmp .ga_copy_arg
.ga_done:
    mov al, 0
    stosb
    pop di
    pop si
    ret

skip_to_next_arg:
    push si
    push di
    mov si, argument_buffer
.stna_loop:
    lodsb
    test al, al
    jz .stna_done
    cmp al, ' '
    je .stna_found
    cmp al, 0x09
    je .stna_found
    jmp .stna_loop
.stna_found:
    lodsb
    cmp al, ' '
    je .stna_found
    cmp al, 0x09
    je .stna_found
    test al, al
    jz .stna_done
    dec si
.stna_done:
    mov di, argument_buffer
.stna_copy:
    lodsb
    stosb
    test al, al
    jnz .stna_copy
    pop di
    pop si
    ret

; ========== ДАННЫЕ ==========
welcome_msg      db "+===================================+", 0x0D, 0x0A
                 db "|         The Halal OS 9008         |", 0x0D, 0x0A
                 db "+===================================+", 0x0D, 0x0A
                 db "Created by Germany organization.", 0x0D, 0x0A,0

prompt_str       db "> ", 0
unknown_cmd      db "Unknown command. Type 'help'", 0x0D, 0x0A, 0
help_text        db "Available commands:", 0x0D, 0x0A
                 db "  help      - show this help", 0x0D, 0x0A
                 db "  cls       - clear screen", 0x0D, 0x0A
                 db "  echo TEXT - print text", 0x0D, 0x0A
                 db "  color     - change color", 0x0D, 0x0A
                 db "  reboot    - restart system", 0x0D, 0x0A
                 db "  ver       - show version", 0x0D, 0x0A
                 db "  out PORT VAL - write to I/O port", 0x0D, 0x0A
                 db "  in PORT      - read from I/O port", 0x0D, 0x0A
;                 db "  serial    - test COM1", 0x0D, 0x0A
;                 db "  parallel  - test LPT1", 0x0D, 0x0A
                 db "  beep      - make sound", 0x0D, 0x0A
                 db "  load NUM  - load program", 0x0D, 0x0A
                 db "  run       - run loaded program", 0x0D, 0x0A
                 db "Programs load at 0x4000:0000", 0x0D, 0x0A, 0

color_msg        db "Color changed to green!", 0
reboot_msg       db "Rebooting system...", 0x0D, 0x0A, 0
ver_msg          db "The Halal OS 9008 v4.1 (Fixed)", 0x0D, 0x0A, 0

out_success      db "I/O write completed", 0x0D, 0x0A, 0
out_error_msg    db "Error: Usage: out PORT VALUE (hex)", 0x0D, 0x0A, 0
in_result        db "Input value: 0x", 0
in_error_msg     db "Error: Usage: in PORT (hex)", 0x0D, 0x0A, 0

;serial_test      db "Testing COM1 port...", 0x0D, 0x0A, 0
;serial_no_response db "COM1 test skipped", 0x0D, 0x0A, 0

;parallel_test    db "Testing LPT1 port...", 0x0D, 0x0A, 0
;parallel_done    db "LPT1 test completed", 0x0D, 0x0A, 0
beep_msg         db "BEEP!", 0x0D, 0x0A, 0

load_success     db "Program loaded successfully.", 0x0D, 0x0A, 0
load_error_msg   db "Error: Failed to load program", 0x0D, 0x0A, 0
load_no_arg_msg  db "Usage: load SECTOR (1-100, hex)", 0x0D, 0x0A, 0
loading_msg      db "Loading program from sector: 0x", 0
running_msg      db "Running program...", 0x0D, 0x0A, 0
return_msg       db 0x0D, 0x0A, "Program returned to kernel.", 0x0D, 0x0A, 0
run_no_program_msg db "No program loaded. Use 'load SECTOR' first.", 0x0D, 0x0A, 0

cmd_help         db "help", 0
cmd_cls          db "cls", 0
cmd_echo         db "echo", 0
cmd_color        db "color", 0
cmd_reboot       db "reboot", 0
cmd_ver          db "ver", 0
cmd_out          db "out", 0
cmd_in           db "in", 0
;cmd_serial       db "serial", 0
;cmd_parallel     db "parallel", 0
cmd_beep         db "beep", 0
cmd_load         db "load", 0
cmd_run          db "run", 0

cursor_pos       db 0
loaded_sector    db 0
command_buffer   times 128 db 0
command_word     times 32 db 0
argument_buffer  times 96 db 0

times 5120-($-$$) db 0
