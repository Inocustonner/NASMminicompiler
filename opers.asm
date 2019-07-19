GLOBAL OperatorNew
GLOBAL OperatorPrint
GLOBAL GetVarStruct

GLOBAL OperatorEquation
GLOBAL OperatorSAdd
GLOBAL OperatorSSub

GLOBAL Operator_check

EXTERN isalnum
EXTERN PrintMessage
EXTERN WriteToTarget
EXTERN SkipSpaces
EXTERN Quit

EXTERN blockPtr
EXTERN blockSz
EXTERN SASP
EXTERN outBuffer

EXTERN operators
EXTERN operators_cnt
EXTERN operator_size
struc variable
        .name resb 1
        .offset resb 2; offset from ebp in 2 hex digits
endstruc
struc operator_word; structure for operator words
    .operator resb 8; max len 8
    .len resb 1; len of the operator word
    .func resd 1; pointer on a function
endstruc
EXTERN variable_sz
EXTERN variable_cnt
; error messages
ErrorVariableExists:    db 0x1B, "[0;31m", "Variable ", "already exists", 0x1B, "[0m"
ErrorVariableExistsL: equ $-ErrorVariableExists

NoVarDecloration: db 0x1B, "[0;31m", "No decloration of the variable ", 0x1B, "[0m"
NoVarDeclorationL: equ $-NoVarDecloration 

ErrorWrongOperator: db 0x1B, "[0;31m", "Wrong operator ", 0x1B, "[0m"
ErrorWrongOperatorL: equ $ - ErrorWrongOperator

ErrorWrongOperand: db 0x1B, "[0;31m", "Wrong operator ", 0x1B, "[0m"
ErrorWrongOperandL: equ $ - ErrorWrongOperand
;instruction List for the New operator
instructionList:
    addToStack: db "sub esp, 4", 0xA
    addToStackL: equ $ - addToStack

    pushToStack: db "push dword [ebp + 0x"
    pushToStackL: equ $ - pushToStack

    callFunc: db "call "
    callFuncL: equ $ - callFunc

    popFromStack: db "pop eax", 0xA
    popFromStackL: equ $ - popFromStack

    moveToEAXFMem: db "mov eax, [ebp + 0x"
    moveToEAXFMemL: equ $ - moveToEAXFMem

    moveToEAX: db "mov eax, "
    moveToEAXL: equ $ - moveToEAX

    moveStr: db "mov "
    moveStrL: equ $ - moveStr

    addStr: db "add "
    addStrL: equ $ - addStr

    subStr: db "sub "
    subStrL: equ $ - subStr

    loadFMem: db "[ebp + 0x"
    loadFMemL: equ $ - loadFMem

    EAXStr: db "eax"
    EAXStrL: equ $ - EAXStr


%macro strcpy 3
    cld
    mov esi, %2
    mov edi, %1
    mov ecx, %3
    rep movsb
%endmacro

;edi should contain start of writing(not changing in the function)
;al a number
altostr16:
    push bx
    xor ah, ah

    shl ax, 4
    mov bl, ah
    cmp bl, 0x9
    jbe .l1

    add bl, 0x7; 0x37 + 0xA = 'A' and so on

    .l1:
    shr al, 4
    mov bh, al
    cmp bh, 0x9
    jbe .l2

    add bh, 0x7

    .l2:
    add bx, word 0x3030

    mov word [edi], bx

    pop bx
    ret
; bl should contain var's name
; ebp should contain structure space ptr
GetVarStruct:
    xor edx, edx

    mov dl, byte [variable_cnt]
    mov eax, variable_sz
    mul edx
    mov edx, eax
    
    xor ecx, ecx
    .checkVarForExisting:
        cmp ecx, edx
        jae .quit

        mov al, byte [ebp + ecx + variable.name]; put a variable struct's name
        cmp bl, al
        jnz .next

        lea eax, [ebp + ecx]
        ret

        .next:
            add ecx, variable_sz
            jmp .checkVarForExisting
    .quit:
    mov eax, 0xFFFFFFFF 
    ret

OperatorNew:
    ;esi contains block
    ;calculate the left size
    mov edx, blockSz
    lea ecx, [blockPtr + edx]
    sub ecx, esi
    ;ecx contains the rest of a len
    call SkipSpaces

    ;Look if a varibale has been created
    mov ebp, SASP; structure allocated space
    mov bl, byte [esi]; put a variable name into al
    call GetVarStruct
    cmp eax, 0xFFFFFFFF; if -1 returned than structure does not exist
    je CreateVariableStruct

    strcpy outBuffer, ErrorVariableExists, ErrorVariableExistsL

    mov edx, ErrorVariableExistsL
    mov esi, outBuffer

    mov ah, bl
    mov al, 0x20
    
    mov word [edi], ax
    mov byte [edi + 2], 0xA
    lea edx, [ErrorVariableExistsL + 3]

    call PrintMessage
    jmp Quit

    CreateVariableStruct:
        xor ecx, ecx
        ;mov offset into ecx
        mov cl, byte [variable_cnt]
        mov eax, variable_sz
        mul ecx
        mov ecx, eax

        mov byte [ebp + ecx + variable.name], bl

        mov al, byte [variable_cnt]
        inc al
        shl al, 2

        lea edi, [ebp + ecx + variable.offset]
        call altostr16

        inc byte [variable_cnt]
    
    ; Write to the target file
    mov esi, addToStack
    mov edx, addToStackL
    call WriteToTarget
    ret

OperatorPrint:
    mov edi, ebx; save ptr on the struct

    ;esi contains block
    ;calculate the left size
    mov edx, blockSz
    lea ecx, [blockPtr + edx]
    sub ecx, esi
    ;ecx contains the rest of a len
    call SkipSpaces

    ;Look if a varibale has been created
    mov ebp, SASP; structure allocated space
    mov bl, byte [esi]; put a variable name into bl
    call GetVarStruct
    cmp eax, 0xFFFFFFFF
    jne ApplyPrint

    strcpy outBuffer, NoVarDecloration, NoVarDeclorationL
    mov al, bl
    mov ah, 0xA
    mov word [edi], ax
    ErrorNoVarDecloration:
    mov esi, outBuffer
    lea edx, [NoVarDeclorationL + 2]
    call PrintMessage
    jmp Quit
    ApplyPrint:
        mov edx, eax; save ptr on the variable struct

        mov ebx, edi; move ptr back
        ; push var to the stack
        strcpy outBuffer, pushToStack, pushToStackL
        mov ax, word [edx + variable.offset]
        mov word [edi], ax
        add edi, 2
        mov byte [edi], ']'
        mov byte [edi + 1], 0xA
        add edi, 2

        ; call the function
        strcpy edi, callFunc, callFuncL
        ; function name
        xor edx, edx
        mov dl, byte [ebx + operator_word.len]
        lea eax, [ebx + operator_word.operator]

        strcpy edi, eax, edx
        mov byte[edi], 0xA
        inc edi
        ;pop from the stack
        strcpy edi, popFromStack, popFromStackL

    ; Write to the target file
    mov esi, outBuffer
    lea edx, [edx + pushToStackL + 4]
    lea edx, [edx + callFuncL + 1]
    add edx, popFromStackL
    call WriteToTarget
    ret
; esi contains current operator + 1
; eax contains current operator's struct
; ebx contains destonation variable's struct
OperatorEquation:
    push ebx; save variable till the .end

    mov ecx, [blockPtr]
    add ecx, [blockSz]
    sub ecx, esi; ecx contains the rest of the line
    ; esi is ready
    call SkipSpaces
    push esi

    strcpy outBuffer, moveToEAX, moveToEAXL; move eax,

    pop esi

    mov al, [esi]
    call isalnum

    cmp bl, 0b10
    je .doNum

    cmp bl, 0b01
    je .doVar

    jmp .err
    ; print num until it will end
    .doNum:
        mov byte [edi], al

        inc edi
        inc esi
        mov al, byte [esi]
        call isalnum
        cmp bl, 0b01

        loopnz .doNum

        jmp .end
    ; print[ebp - 0x(var offset)]
    .doVar:
        mov bl, al
        mov ebp, SASP
        call GetVarStruct
        cmp eax, 0xFFFFFFFF
        je ErrorNoVarDecloration

        strcpy edi, loadFMem, loadFMemL
        mov bx, word [eax + variable.offset]
        mov [edi], bx
        add edi, 2

        mov ah, 0xA
        mov al, ']'
        mov [edi], word ax
        add edi, 2
        jmp .end
    .err:
        pop ebx
		strcpy outBuffer, ErrorWrongOperand, ErrorWrongOperandL

		mov ah, 0xA
		mov word [edi], ax
		add edi, 2


		mov esi, outBuffer
		mov edx, edi
		sub edx, esi
		call PrintMessage

        jmp Quit
    .end:
        strcpy edi, moveStr, moveStrL
        strcpy edi, loadFMem, loadFMemL
        pop ebx
        ; write variables offset
        mov ax, word [ebx + variable.offset]
        mov word [edi], ax
        add edi, 2

        mov al, "]"
        mov ah, ","
        mov word [edi], ax
        add edi, 2

        strcpy edi, EAXStr, EAXStrL
        mov byte [edi], 0xA
        inc edi
        ; write outBuffer to  the target file
        mov esi, outBuffer

        mov edx, edi
        sub edx, esi

        call WriteToTarget
        ret

; esi contains current operator + 1
; eax contains current operator's struct
; ebx contains destonation variable's struct
OperatorSAdd:
    push ebx; save ebx

    inc esi
    mov ecx, dword [blockPtr]
    add ecx,  dword [blockSz]
    sub ecx, esi
    ;esi conatins operator + 1, ecx contains the rest length of the current block
    call SkipSpaces
    push esi; esi points on a start of a var of num

    ; load variable's value to eax
    ; mov eax, [ebp + 0x(...)] 
    strcpy outBuffer, moveToEAX, moveToEAXL
    strcpy edi, loadFMem, loadFMemL
    mov ax, [ebx + variable.offset]
    mov word [edi], ax
    mov al, ']'
    mov ah, 0xA
    mov word [edi + 2], ax
    add edi, 4

    ; write add eax, 
    strcpy edi, addStr, addStrL
    strcpy edi, EAXStr, EAXStrL
    mov al, ','
    mov ah, 0x20
    mov word [edi], ax
    add edi, 2
    pop esi

    mov al, [esi]
    call isalnum

    cmp bl, 0b10
    je .doNum

    cmp bl, 0b01
    je .doVar

    jmp .err
    ; print num until it will end
    .doNum:
        mov byte [edi], al

        inc edi
        inc esi
        mov al, byte [esi]
        call isalnum
        cmp bl, 0b01

        loopnz .doNum

        jmp .end
    ; print[ebp - 0x(var offset)]
    .doVar:
        mov bl, al
        mov ebp, SASP
        call GetVarStruct
        cmp eax, 0xFFFFFFFF
        je ErrorNoVarDecloration

        strcpy edi, loadFMem, loadFMemL
        mov bx, word [eax + variable.offset]
        mov [edi], bx
        add edi, 2

        mov ah, 0xA
        mov al, ']'
        mov [edi], word ax
        add edi, 2
        jmp .end
    .err:
        pop ebx

        jmp OperatorEquation.err
    .end:
        strcpy edi, moveStr, moveStrL
        strcpy edi, loadFMem, loadFMemL
        pop ebx
        ; write variables offset
        mov ax, word [ebx + variable.offset]
        mov word [edi], ax
        add edi, 2

        mov al, "]"
        mov ah, ","
        mov word [edi], ax
        add edi, 2

        strcpy edi, EAXStr, EAXStrL
        mov byte [edi], 0xA
        inc edi
        ; write outBuffer to  the target file
        mov esi, outBuffer

        mov edx, edi
        sub edx, esi

        call WriteToTarget
    ret

OperatorSSub:
    push ebx; save ebx

    inc esi
    mov ecx, dword [blockPtr]
    add ecx,  dword [blockSz]
    sub ecx, esi
    ;esi conatins operator + 1, ecx contains the rest length of the current block
    call SkipSpaces
    push esi; esi points on a start of a var of num

    ; load variable's value to eax
    ; mov eax, [ebp + 0x(...)] 
    strcpy outBuffer, moveToEAX, moveToEAXL
    strcpy edi, loadFMem, loadFMemL
    mov ax, [ebx + variable.offset]
    mov word [edi], ax
    mov al, ']'
    mov ah, 0xA
    mov word [edi + 2], ax
    add edi, 4

    ; write add eax, 
    strcpy edi, subStr, subStrL
    strcpy edi, EAXStr, EAXStrL
    mov al, ','
    mov ah, 0x20
    mov word [edi], ax
    add edi, 2
    pop esi

    mov al, [esi]
    call isalnum

    cmp bl, 0b10
    je .doNum

    cmp bl, 0b01
    je .doVar

    jmp .err
    ; print num until it will end
    .doNum:
        mov byte [edi], al

        inc edi
        inc esi
        mov al, byte [esi]
        call isalnum
        cmp bl, 0b01

        loopnz .doNum

        jmp .end
    ; print[ebp - 0x(var offset)]
    .doVar:
        mov bl, al
        mov ebp, SASP
        call GetVarStruct
        cmp eax, 0xFFFFFFFF
        je ErrorNoVarDecloration

        strcpy edi, loadFMem, loadFMemL
        mov bx, word [eax + variable.offset]
        mov [edi], bx
        add edi, 2

        mov ah, 0xA
        mov al, ']'
        mov [edi], word ax
        add edi, 2
        jmp .end
    .err:
        pop ebx

        jmp OperatorEquation.err
    .end:
        strcpy edi, moveStr, moveStrL
        strcpy edi, loadFMem, loadFMemL
        pop ebx
        ; write variables offset
        mov ax, word [ebx + variable.offset]
        mov word [edi], ax
        add edi, 2

        mov al, "]"
        mov ah, ","
        mov word [edi], ax
        add edi, 2

        strcpy edi, EAXStr, EAXStrL
        mov byte [edi], 0xA
        inc edi
        ; write outBuffer to  the target file
        mov esi, outBuffer

        mov edx, edi
        sub edx, esi

        call WriteToTarget
    ret

;eax should contain address of the struct with the current variable
;esi should contain the current block and pointing on the variable
Operator_check:
    push eax; save destonation variable's struct

    inc esi
    mov ecx, blockPtr
    add ecx, dword [blockSz]
    sub ecx, esi; ecx contains the rest size of a line
    call SkipSpaces
    ; find current operator
    mov ebp, operators
    mov ebx, esi; save esi's position in ebx to restore in future
    ; calc value for edx
    mov dx, operators_cnt
    mov ax, operator_size
    mul dx
    mov dx, ax

    xor eax, eax
    xor ecx, ecx
    .search_operator:
        cmp ax, dx
        jae .error
        
        lea edi, [ebp + eax + operator_word.operator]
        mov cl, byte [ebp + eax + operator_word.len]
        repe cmpsb
        .G:
        jne .post
        mov edx, [ebp + eax + operator_word.func]
        pop ebx; pop current variable's struct
        call edx
        jmp .end

        .post:
            mov esi, ebx
            add eax, operator_size
            jmp .search_operator 
    .error:
    ; print error and quit
    pop eax
    mov al, byte [esi]
    mov ah, 0xA
    strcpy outBuffer, ErrorWrongOperator, ErrorWrongOperatorL
    mov word [edi], ax
    mov esi, outBuffer
    lea edx, [ErrorWrongOperatorL + 2]
    call PrintMessage 
    jmp Quit

    .end:
    ret