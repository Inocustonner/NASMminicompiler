; main compiler program
GLOBAL blockPtr
GLOBAL blockSz
GLOBAL fd
GLOBAL outBuffer

GLOBAL SASP
GLOBAL variable_sz
GLOBAL variable_cnt
GLOBAL operators
GLOBAL operators_cnt
GLOBAL operator_size
GLOBAL isalnum
GLOBAL PrintMessage
GLOBAL WriteToTarget
GLOBAL SkipSpaces
GLOBAL Quit

EXTERN OperatorNew
EXTERN OperatorPrint
EXTERN GetVarStruct

EXTERN OperatorEquation
EXTERN OperatorSAdd
EXTERN OperatorSSub
EXTERN Operator_check

SECTION .bss
    FBSZ: equ 4096; max size
    filebuffer: resb FBSZ
    AFBSZ: resd 1; how many bytes were read into buffer
    
    blockPtr: resd 1
    blockSz: resd 1
    ifd: resd 1; file descriptor for input file
    fd: resd 1; file descriptor for output file

    struc operator_word; structure for operator words
        .operator resb 8; max len 8
        .len resb 1; len of the operator word
        .func resd 1; pointer on a function
    endstruc

    struc variable
        .name resb 1
        .offset resb 2; offset from ebp in 2 hex digits
    endstruc

    variable_sz: equ 3

    SASP: resb variable_sz*26; struct allocated space ptr

    outBuffer: resb 60

SECTION .data
    bbs: equ 0x3B; block breaking symbol ( 3B = ';' )
    of: db "out.zo", 0; output file

    variable_cnt: db 0

    new: db "new"
    operators_keywords:
        istruc operator_word
            at operator_word.operator, db "new"
            at operator_word.len, db 3
            at operator_word.func, dd OperatorNew
        iend
    operator_size: equ $ - operators_keywords
        istruc operator_word
            at operator_word.operator, db "print"
            at operator_word.len, db 5
            at operator_word.func, dd OperatorPrint
        iend
    keywords_cnt: equ ($ - operators_keywords) / operator_size
    operators:
        istruc operator_word
            at operator_word.operator, db "="
            at operator_word.len, db 1
            at operator_word.func, dd OperatorEquation
        iend
        istruc operator_word
            at operator_word.operator, db "+="
            at operator_word.len, db 2
            at operator_word.func, dd OperatorSAdd
        iend
        istruc operator_word
            at operator_word.operator, db "-="
            at operator_word.len, db 2
            at operator_word.func, dd OperatorSSub
        iend
    operators_cnt: equ ($ - operators) / operator_size

    start_input:    db "SECTION .bss", 0xA
                    db "SECTION .data", 0xA
                    db "SECTION .text", 0xA
                    db "GLOBAL _start", 0xA
                    db "EXTERN print", 0xA
                    db "_start:", 0xA
                    db "mov ebp, esp", 0xA
    start_inputl: equ $ - start_input

    end_input:      db "mov eax, 1", 0xA
                    db "mov ebx, 0", 0xA
                    db "int 0x80"
    end_inputl: equ $ - end_input

SECTION .text
GLOBAL _start
;  argument is fd
%macro closeFile 1
    mov eax, 6
    mov ebx, %1
    int 0x80
%endmacro

;al should contain symbol
;bl will contain a num. if 10 - num if 01 - alpha(only small charters) if 00 one of space charters
isalnum:
    xor bl, bl
    cmp al, byte 0x30
    ja .isnum
    ret

    .isnum:
    cmp al, byte 0x39
    ja .isalpha
    mov bl, 0b10
    ret

    .isalpha:
    cmp al, byte 0x61
    jb .end

    cmp al, byte 0x7A
    ja .end

    mov bl, 0b01
    .end:
        ret
;esi contain buffer pointer
;edx contain buffer len
PrintMessage:
    push eax
    push ebx
    push ecx

    mov eax, 4; sys_write
    mov ebx, 2; stderr
    mov ecx, esi
    ;edx is ready
    int 0x80

    pop ecx
    pop ebx
    pop eax

    ret

;esi contain buffer pointer
;edx contain buffer len
WriteToTarget:
    push eax
    push ebx
    push ecx

    mov eax, 4; sys_write
    mov ebx, [fd]; target file desc
    mov ecx, esi
    ;edx is ready
    int 0x80

    pop ecx
    pop ebx
    pop eax

    ret

;esi should contain pointer on a string
;ecx should contain len of the string in esi
;the function increments esi as decrements ecx until not a space reached
SkipSpaces:
    mov al, [esi]

    cmp al, 0x20
    jbe .next

    ret
    .next:
        inc esi; move pointer forward
        dec ecx; decrease size
        jmp SkipSpaces

_start:
    mov ebp, esp
         
    mov ecx, [esp]
    dec ecx
    jz Quit; if only one argument given

    mov eax, 5; sys_open
    mov ebx, [ebp + 8]; path to file in the first  arg
    mov ecx, 0
    mov edx, 0o700
    int 0x80

    ; check if file was openned correctly
    test eax, 0xFFFF0000
    jnz Close

    mov ebx, eax; copy ifd to ebx from eax
    mov [ifd], eax; copy ifd from eax

    mov eax, 3; sys_read
    ; ebx contains fd
    mov ecx, filebuffer
    mov edx, FBSZ
    int 0x80

    mov [AFBSZ], eax; mov number of bytes read

    mov eax, 8
    mov ebx, of
    mov ecx, 0o700
    mov edx, 100 | 1; O_CREAT & O_WRONLY
    int 0x80

    ; check if file was created correctly
    test eax, 0xFFFF0000
    jnz Close

    mov [fd], eax; save fd in eax

    InputBeginning:
        mov esi, start_input
        mov edx, start_inputl
        call WriteToTarget

    ; pre installation
    mov esi, filebuffer; set blockPtr at the start
    mov [blockPtr], esi
    
    ;while end isn't reached mov blockptr to the next block
    SetBlock:
        mov edi, esi; esi represents current blockptr

        mov edx, [AFBSZ]

        lea ecx, [filebuffer + edx]
        sub ecx, edi; length between current block and end

        cmp edi, 0; clear zero flag

        mov al, bbs; ';' block breaking symbol
        repne scasb; till ';' isn't reached
        jnz Quit; means end has reached

        sub edi, esi; calculate and save a size of the current block

        ;skip spaces
        ;esi already contain sting pointer
        mov ecx, edi
        call SkipSpaces
        mov edi, ecx

        mov dword [blockPtr], esi
        mov dword [blockSz], edi
		;LOG
        ;esi is setted
        ;mov edx, edi
        ;call PrintMessage

        ;check first word in a line if it is one of operators_keywords go to their functions
        xor ecx, ecx
        mov eax, keywords_cnt
        mov ebx, operators_keywords
        OwnedWordsCheck:
            mov cl, byte [ebx + operator_word.len]
            lea edi, [ebx + operator_word.operator]
            mov esi, [blockPtr]

            repe cmpsb
            jnz .post

            call [ebx + operator_word.func]; esi points on the position after a word
            jmp PrepareNewBlock; if found 
        .post:
            add ebx, operator_size
            dec eax

            loopnz OwnedWordsCheck

        VariableCheck:
            mov esi, dword [blockPtr]
            mov ecx, dword [blockSz]
            call SkipSpaces

            mov bl, [esi]
            mov ebp, SASP
            call GetVarStruct
            cmp eax, 0xFFFFFFFF
            je PrepareNewBlock

            call Operator_check

        PrepareNewBlock:
            ;post establishing
            mov esi, dword [blockPtr]
            add esi, dword [blockSz]; mov on the block size forward
            mov dword [blockPtr], esi
            jmp SetBlock

Quit:
    InputEnd:
        mov esi, end_input
        mov edx, end_inputl
        call WriteToTarget

    closeFile [ifd]; close input file
    closeFile [fd]; close output file
Close:
    mov esp, ebp; return stack pointer on the place

    mov eax, 1
    mov ebx, 0
    int 0x80