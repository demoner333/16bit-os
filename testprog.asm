; testprog.asm - Простая тестовая программа
[org 0x0000]
[bits 16]

start:
    ; Прямой вызов BIOS без лишних функций
    mov si, msg
    
print_loop:
    lodsb
    test al, al
    jz done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp print_loop
    
done:
    ; Возврат в ОС через far ret
    retf

msg db 0x0D, 0x0A
    db ">>> PROGRAM RUNNING! <<<", 0x0D, 0x0A
    db "Test program v1.0", 0x0D, 0x0A
    db "Returning to kernel...", 0x0D, 0x0A, 0

times 512-($-$$) db 0
