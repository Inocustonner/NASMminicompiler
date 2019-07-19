; lib that used for zlang
BFL: equ 17
GLOBAL print
print:
    xor eax, eax
    xor ecx, ecx

    mov ecx, BFL / 4; we gonna print 4 bytes because this is the size of integer on 32bit
    mov esi, dword [esp + 4]; mov a number to print in esi

    sub esp, BFL; add a space in stack for the buffer for output
    mov byte [esp + BFL / 2], 0xA; add EOL at the end
    .setbuffer:

        mov bx, si
        xor bh, bh; clear high nybble because he contains next 2 chars but we don't need 'em now
        
        shl bx, 4; mov first number to higher nybble to copy to al
        mov dl, bh
        cmp dl, 0x9
        jbe .l1

        add dl, 0x7

        .l1:
        shr bl, 4; repeate for a lower one
        mov dh, bl
        cmp dh, 0x9
        jbe .l2

        add dh, 0x7

        .l2:
        add dx, word 0x3030

        mov al, cl
        dec al
        shl al, 1; al = al * 2

        mov word [esp + eax], dx

        shr esi, 0x8; remove last 2 bytes

        loop .setbuffer
    ;print
    mov eax, 4; sys_write
    mov ebx, 1; stdout
    mov ecx, esp; buffer in the stack
    mov edx, BFL/2 + 1
    int 0x80

    add esp, 17; return the stack on the previous position
    ret