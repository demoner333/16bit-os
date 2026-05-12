#!/bin/bash

echo "Building The Halal OS 9008..."

# Компиляция
nasm -f bin bootloader.asm -o bootloader.bin
if [ $? -ne 0 ]; then
    echo "Bootloader compilation failed!"
    exit 1
fi

nasm -f bin kernel.asm -o kernel.bin
if [ $? -ne 0 ]; then
    echo "Kernel compilation failed!"
    exit 1
fi

nasm -f bin testprog.asm -o testprog.bin
if [ $? -ne 0 ]; then
    echo "Test program compilation failed!"
    exit 1
fi

# Создание образа
dd if=/dev/zero of=os.img bs=512 count=2880 2>/dev/null
dd if=bootloader.bin of=os.img bs=512 count=1 conv=notrunc 2>/dev/null
dd if=kernel.bin of=os.img bs=512 seek=1 conv=notrunc 2>/dev/null
dd if=testprog.bin of=os.img bs=512 seek=20 conv=notrunc 2>/dev/null

# Проверка
echo ""
echo "Checking disk sectors:"
dd if=os.img bs=512 skip=20 count=1 2>/dev/null | xxd | head -3

echo ""
echo "Build complete!"
echo "Run: qemu-system-x86_64 -drive format=raw,file=os.img"
