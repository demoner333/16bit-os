; bootloader.asm - Загрузчик, читает ядро с диска
; Компиляция: nasm -f bin bootloader.asm -o bootloader.bin

[org 0x7c00]
[bits 16]

KERNEL_OFFSET equ 0x1000   ; Куда загружать ядро (сегмент 0x1000)

start:
    ; Настройка сегментов
    cli
    mov ax, 0x0000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

    ; Очистка экрана
    mov ax, 0x0003
    int 0x10

    ; Вывод сообщения загрузчика
    mov si, boot_msg
    call print_string

    ; Загрузка ядра с диска
    call load_kernel

    ; Переход на ядро
    mov ax, KERNEL_OFFSET
    mov ds, ax
    mov es, ax
    jmp KERNEL_OFFSET:0x0000

; ========== ПРОЦЕДУРЫ ==========
print_string:
    pusha
    .loop:
        lodsb
        test al, al
        jz .done
        mov ah, 0x0E
        mov bx, 0x0007
        int 0x10
        jmp .loop
    .done:
    popa
    ret

load_kernel:
    pusha
    ; Сброс дисковода
    mov ah, 0x00
    mov dl, 0x80        ; Первый жесткий диск
    int 0x13
    jc disk_error

    ; Чтение секторов
    mov ax, KERNEL_OFFSET
    mov es, ax
    xor bx, bx           ; ES:BX = 0x1000:0000

    mov ah, 0x02         ; Функция чтения
    mov al, 10           ; Количество секторов (ядро может быть до 10 секторов)
    mov ch, 0            ; Цилиндр 0
    mov cl, 2            ; Сектор 2 (сразу после bootloader)
    mov dh, 0            ; Головка 0
    mov dl, 0x80         ; Диск
    int 0x13
    jc disk_error

    mov si, kernel_loaded_msg
    call print_string
    popa
    ret

disk_error:
    mov si, disk_error_msg
    call print_string
    cli
    hlt

boot_msg           db "Bootloader v1.0", 0x0D, 0x0A, "Loading kernel...", 0x0D, 0x0A, 0
disk_error_msg     db "DISK ERROR!", 0x0D, 0x0A, 0
kernel_loaded_msg  db "Kernel loaded successfully!", 0x0D, 0x0A, 0

times 510-($-$$) db 0
dw 0xAA55
