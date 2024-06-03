; -------------------------------------------------------------------------------------------------------------------------
; MASM x32 Calculator - Mateusz Basiaga
; -------------------------------------------------------------------------------------------------------------------------

.386
.model flat, stdcall
option casemap:none

include windows.inc
include user32.inc
include kernel32.inc
include comctl32.inc
include gdi32.inc

includelib comctl32.lib
includelib user32.lib
includelib kernel32.lib
includelib gdi32.lib
includelib dwmapi.lib

.data
   WindowClass db "WinClass",0
   WindowTitle db "Kalkulator",0
   ButtonDefaultClass db "BUTTON",0
   StaticControlClass db "STATIC",0

   window_width dd 600
   window_height dd 800

   x_test db 1

   FontNameLabel db "Raleway",0
   FontNameButtons db "Arial",0

   ButtonNumber1Text db "1",0
   ButtonNumber2Text db "2",0
   ButtonNumber3Text db "3",0
   ButtonNumber4Text db "4",0
   ButtonNumber5Text db "5",0
   ButtonNumber6Text db "6",0
   ButtonNumber7Text db "7",0
   ButtonNumber8Text db "8",0
   ButtonNumber9Text db "9",0
   ButtonNumber0Text db "0",0

   ButtonACText db "AC",0
   ButtonDeleteText db "DEL",0
   ButtonModuloText db "MOD",0
   ButtonDivideText db "÷",0
   ButtonMultiplyText db "x",0
   ButtonSubtractText db "-",0
   ButtonAddText db "+",0
   ButtonCalculateText db "=",0
   ButtonNegateText db "+/-",0

   SymbolAddition db " + ",0
   SymbolSubtraction db " - ",0
   SymbolMultiplication db " x ",0
   SymbolDivision db " ÷ ",0
   SymbolModulo db " % ",0

   operand1 dd 0
   operand1Text db 64 dup(0)

   operand2Initialized db 0
   operand2Text db 64 dup(0)

   outputText db '0', 511 dup(0)

   activeOperationId db 0

   errorText db "ERR",0

.data?
screenHeight dd ?
screenWidth dd ?

hInstance HINSTANCE ?

hLabelFont dd ?
hFontButtonNormal dd ?

hBackgroundBrush dd ?

hLabel dd ?

hButtonNumber1 dd ?
hButtonNumber2 dd ?
hButtonNumber3 dd ?
hButtonNumber4 dd ?
hButtonNumber5 dd ?
hButtonNumber6 dd ?
hButtonNumber7 dd ?
hButtonNumber8 dd ?
hButtonNumber9 dd ?
hButtonNumber0 dd ?

hButtonAC dd ?
hButtonDelete dd ?
hButtonModulo dd ?
hButtonDivide dd ?
hButtonMultiply dd ?
hButtonSubtract dd ?
hButtonAdd dd ?
hButtonCalculate dd ?
hButtonNegate dd ?

operand2 dd ?

.const
MAIN_ICON_ID equ 101

BACKGROUND_COLOR EQU 001D1F22h
TEXT_COLOR EQU 00FFFFFFh

MIN_WINDOW_WIDTH EQU 410
MIN_WINDOW_HEIGHT EQU 500

LABEL_HEIGHT_WINDOW_FRACTION EQU 4 ; LABEL_HEIGHT = WINDOW_HEIGHT / LABEL_HEIGHT_WINDOW_FRACTION

ELEMENTS_SPACING EQU 5

NUMBER_OF_BUTTONS_IN_ROW EQU 4
NUMBER_OF_BUTTONS_IN_COLUMN EQU 5

BUTTON_NUMBER_1_ID EQU 1
BUTTON_NUMBER_2_ID EQU 2
BUTTON_NUMBER_3_ID EQU 3
BUTTON_NUMBER_4_ID EQU 4
BUTTON_NUMBER_5_ID EQU 5
BUTTON_NUMBER_6_ID EQU 6
BUTTON_NUMBER_7_ID EQU 7
BUTTON_NUMBER_8_ID EQU 8
BUTTON_NUMBER_9_ID EQU 9
BUTTON_NUMBER_0_ID EQU 10

LABEL_ID EQU 200

BUTTON_AC_ID EQU 300
BUTTON_DELETE_ID EQU 301
BUTTON_MODULO_ID EQU 302
BUTTON_DIVIDE_ID EQU 303
BUTTON_MULTIPLY_ID EQU 304
BUTTON_SUBTRACT_ID EQU 305
BUTTON_ADD_ID EQU 306
BUTTON_CALCULATE_ID EQU 307
BUTTON_NEGATE_ID EQU 308

OP_NULL EQU 0
OP_ADDITION EQU 1
OP_SUBTRACTION EQU 2
OP_MULTIPLICATION EQU 3
OP_DIVISION EQU 4
OP_MODULO EQU 5

SYMBOL_LENGTH EQU 3

.code

start:
    DwmSetWindowAttribute PROTO :HWND, :DWORD, :LPCVOID, :DWORD
  
    invoke InitCommonControls 
    invoke GetModuleHandle,0
    mov hInstance,eax

    call WinMain

    invoke ExitProcess, 0

    ; Procedure for creating a custom button
    CreateButton PROC, class:LPCSTR, text:LPCSTR, x:DWORD, y:DWORD, btnWidth:DWORD, btnHeight:DWORD, hWnd:HWND, id:HMENU, hFont:PTR DWORD
        push edx
        push ecx

        invoke CreateWindowEx, 0, class, text,\
            WS_CHILD or WS_VISIBLE, x,  y, btnWidth, btnHeight, hWnd, id, hInstance, 0

        push eax

        invoke SendMessage, eax, WM_SETFONT, hFont, TRUE

        pop eax
        pop ecx
        pop edx

        ret
    CreateButton ENDP

    MoveToNextButton PROC
        add edx, ELEMENTS_SPACING
        add edx, ecx
        
        ret
    MoveToNextButton ENDP

    MoveToNextRow PROC
        mov edx, ELEMENTS_SPACING

        add esi, ELEMENTS_SPACING
        add esi, edi
        
        ret
    MoveToNextRow ENDP

   GetLabelWidth PROC
        push ebx
        push edx

        mov eax, ELEMENTS_SPACING
        mov ebx, 3 ; 2 x spacing (both sides) + 1 fake right margin
        mul ebx
        mov edx, window_width
        sub edx, eax

        mov eax, edx
        pop edx
        pop ebx
        ret
    GetLabelWidth ENDP

    GetLabelHeight PROC
        push ebx
        push edx

        mov eax, window_height
        mov ebx, LABEL_HEIGHT_WINDOW_FRACTION
        xor edx, edx
        div ebx
        sub eax, ELEMENTS_SPACING * 2 ; 2 x spacing (both sides)

        pop edx
        pop ebx
        ret
    GetLabelHeight ENDP

    GetButtonWidth PROC
        push ebx
        push ecx

        mov eax, window_width
        mov ebx, NUMBER_OF_BUTTONS_IN_ROW
        xor edx, edx
        div ebx
        ; total spacing =  [NUMBER_OF_BUTTONS_IN_ROW - 1 (spacing between buttons) + 2 (side spacing )] * ELEMENTS_SPACING = (NUMBER_OF_BUTTONS_IN_ROW + 1) * ELEMENTS_SPACING
        ; to account for the spacing we need to distribute the difference equally on all buttons by subtracting the total spacing / NUMBER_OF_BUTTONS_IN_ROW from the width
        sub eax, ((NUMBER_OF_BUTTONS_IN_ROW + 1) * ELEMENTS_SPACING) / NUMBER_OF_BUTTONS_IN_ROW
        mov ecx, eax
        
        mov eax, ecx
        pop ecx
        pop ebx
        ret
    GetButtonWidth ENDP

    GetButtonHeight PROC labelHeight:DWORD
        push ebx
        push edx
        push edi

        mov eax, window_height
        sub eax, labelHeight ; subtract label height
        sub eax, ELEMENTS_SPACING * 7; double element spacing
        mov ebx, NUMBER_OF_BUTTONS_IN_COLUMN
        xor edx, edx
        div ebx

        pop edi
        pop edx
        pop ebx
        ret
    GetButtonHeight ENDP

    MoveButton PROC hBtn:HWND, newX:DWORD, newY:DWORD, newWidth:DWORD, newHeight:DWORD
        push edx
        push ecx

        invoke MoveWindow, hBtn, newX, newY, newWidth, newHeight, TRUE

        pop ecx
        pop edx
        ret
    MoveButton ENDP

    NumberToString proc number:DWORD, strBuffer:PTR DWORD
      local isNumberNegative:BYTE
      mov isNumberNegative, 0

      mov  esi, strBuffer

      mov eax, number
      test eax, eax
      js negativeNumber

      convert:
          mov  ebx, 10 ;DIGITS ARE EXTRACTED DIVIDING BY 10.
          mov  ecx, 0 ;COUNTER FOR EXTRACTED DIGITS.
          cycle1:       
              mov  edx, 0 ;NECESSARY TO DIVIDE BY EBX.
              div  ebx ;EDX:EAX / 10 = EAX:QUOTIENT EDX:REMAINDER.
              push dx ;PRESERVE DIGIT EXTRACTED (DL) FOR LATER.
              inc  ecx  ;INCREASE COUNTER FOR EVERY DIGIT EXTRACTED.
              cmp  eax, 0  ;IF NUMBER IS
              jne  cycle1  ;NOT ZERO, LOOP. 

              ; NOW RETRIEVE PUSHED DIGITS.
              cycle2:  
                  pop  dx        
                  add  dl, 48 ;CONVERT DIGIT TO CHARACTER.
                  mov  [ esi ], dl
                  inc  esi
                  loop cycle2

            mov dl, 0
            mov [esi], dl
            ret

    negativeNumber:
        mov isNumberNegative, 1
        neg eax
        mov dl, "-"
        mov [esi], dl
        inc esi
        jmp convert

    NumberToString endp

    WriteStringToBuffer PROC string:PTR DWORD, buffer:PTR DWORD
        mov esi, string ; Source string address
        mov edi, buffer  ; Destination string address

        ; Repeat while byte at [esi] is not 0 (null character)
        copy:
            mov  al,[esi]          
            mov  [edi],al           
            inc  esi              
            inc  edi
            cmp byte ptr [esi],0   ; Check for null terminator
            jne copy                 ; Loop if not null
            
            mov byte ptr [edi], 0
            ret
    WriteStringToBuffer ENDP

    AppendToBuffer PROC value:PTR DWORD, buffer:PTR DWORD, insertionOffset:DWORD
        mov esi, value
        mov edi, buffer

        ; Repeat while byte at [edi] is not 0 (null character)
        search:
            mov  al, [edi]
            inc  edi
            cmp byte ptr [edi],0       ; Check for null terminator
            jne search                 ; Loop if not null
            
            add edi, insertionOffset
            invoke WriteStringToBuffer, value, edi
            ret
    AppendToBuffer ENDP

    UpdateOutputLabel PROC
        LOCAL tempBuffer[64]:byte
        mov tempBuffer, " "
        mov byte ptr [tempBuffer + 1], 0

        invoke NumberToString, operand1, ADDR operand1Text

        .IF activeOperationId==OP_NULL
            invoke WriteStringToBuffer, ADDR operand1Text, ADDR outputText
        .ELSE
            invoke AppendToBuffer, ADDR operand1Text, ADDR tempBuffer, 0

            .IF activeOperationId==OP_ADDITION
                invoke AppendToBuffer, ADDR SymbolAddition, ADDR tempBuffer, 0
            .ELSEIF activeOperationId==OP_SUBTRACTION
                invoke AppendToBuffer, ADDR SymbolSubtraction, ADDR tempBuffer, 0
            .ELSEIF activeOperationId==OP_MULTIPLICATION
                invoke AppendToBuffer, ADDR SymbolMultiplication, ADDR tempBuffer, 0
            .ELSEIF activeOperationId==OP_DIVISION
                invoke AppendToBuffer, ADDR SymbolDivision, ADDR tempBuffer, 0
           .ELSEIF activeOperationId==OP_MODULO
                invoke AppendToBuffer, ADDR SymbolModulo, ADDR tempBuffer, 0
            .ENDIF

            invoke NumberToString, operand2, ADDR operand2Text
            invoke AppendToBuffer, ADDR operand2Text, ADDR tempBuffer, 0

            invoke WriteStringToBuffer, ADDR tempBuffer, ADDR outputText
        .ENDIF

        invoke SendMessage, hLabel, WM_SETTEXT, 0, ADDR outputText
        ret
    UpdateOutputLabel ENDP

    HandleClickButtonNumber PROC number:DWORD
        .IF activeOperationId==OP_NULL
            ; no active operation - update operand 1
            mov eax, operand1
            mov ebx, 10
            mul ebx
            add eax, number
            mov operand1, eax
        .ELSE
            ; there is an active operation - update operand 2
            .IF operand2Initialized==0
                mov eax, 0
                add eax, number
                mov operand2, eax
                mov operand2Initialized, 1
            .ELSE
                mov eax, operand2
                mov ebx, 10
                mul ebx
                add eax, number
                mov operand2, eax
            .ENDIF

        .ENDIF
    
        invoke UpdateOutputLabel
        ret
    HandleClickButtonNumber ENDP

    ResetState PROC
        mov activeOperationId, OP_NULL
        mov operand1, 0
        mov operand2Initialized, 0

        ret
    ResetState ENDP

    HandleClickButtonAc PROC
        invoke ResetState
        invoke UpdateOutputLabel

        ret
    HandleClickButtonAc ENDP

    EnterErrorState PROC
        invoke ResetState
        invoke SendMessage, hLabel, WM_SETTEXT, 0, ADDR errorText

        ret
    EnterErrorState ENDP

    HandleClickButtonDelete PROC
        .IF activeOperationId==OP_NULL
            mov eax, operand1
            xor edx, edx
            mov ebx, 10
            div ebx
            mov operand1, eax

            invoke UpdateOutputLabel
        .ELSE
            .IF operand2Initialized==1
                mov eax, operand2
                xor edx, edx
                mov ebx, 10
                div ebx
                mov operand2, eax

                invoke UpdateOutputLabel
            .ENDIF
        .ENDIF
        ret
    HandleClickButtonDelete ENDP

    HandleClickButtonNegate PROC
       .IF activeOperationId==OP_NULL
            neg operand1
            invoke UpdateOutputLabel
        .ELSE
            .IF operand2Initialized==1
                neg operand2
                invoke UpdateOutputLabel
            .ENDIF
        .ENDIF
        ret
    HandleClickButtonNegate ENDP

    HandleCalculateResult PROC
        LOCAL result:DWORD

        .IF activeOperationId==OP_ADDITION
            mov eax, operand1
            add eax, operand2

            mov result, eax
        .ELSEIF activeOperationId==OP_SUBTRACTION
            mov eax, operand1
            sub eax, operand2

            mov result, eax
        .ELSEIF activeOperationId==OP_MULTIPLICATION
            mov eax, operand1
            mov ebx, operand2
            mul ebx

            mov result, eax

        .ELSEIF activeOperationId==OP_DIVISION
            .IF operand2==0
                invoke EnterErrorState
                ret
            .ELSE
                mov eax, operand1
                xor edx, edx
                mov ebx, operand2
                div ebx

                mov result, eax
            .ENDIF
        
        .ELSEIF activeOperationId==OP_MODULO
            mov eax, operand1
            xor edx, edx
            mov ebx, operand2
            div ebx

            mov result, edx
        .ENDIF

        invoke NumberToString, result, ADDR outputText
        invoke SendMessage, hLabel, WM_SETTEXT, 0, ADDR outputText
        mov eax, result
        mov operand1, eax

        mov activeOperationId, OP_NULL
        mov operand2Initialized, 0
        ret
    HandleCalculateResult ENDP

    HandleClickButtonCalculate PROC
        invoke HandleCalculateResult

        ret
    HandleClickButtonCalculate ENDP

    HandleClickButtonOperation PROC operationId:BYTE
        .IF activeOperationId==OP_NULL
            .IF operationId==OP_ADDITION
                invoke AppendToBuffer, ADDR SymbolAddition, ADDR outputText, 0
            .ELSEIF operationId==OP_SUBTRACTION
                invoke AppendToBuffer, ADDR SymbolSubtraction, ADDR outputText, 0
            .ELSEIF operationId==OP_MULTIPLICATION
                invoke AppendToBuffer, ADDR SymbolMultiplication, ADDR outputText, 0
            .ELSEIF operationId==OP_DIVISION
                invoke AppendToBuffer, ADDR SymbolDivision, ADDR outputText, 0
            .ELSEIF operationId==OP_MODULO
                invoke AppendToBuffer, ADDR SymbolModulo, ADDR outputText, 0
            .ENDIF
        .ELSEIF operand2Initialized==0
            .IF operationId==OP_ADDITION
                invoke AppendToBuffer, ADDR SymbolAddition, ADDR outputText, -SYMBOL_LENGTH
            .ELSEIF operationId==OP_SUBTRACTION
                invoke AppendToBuffer, ADDR SymbolSubtraction, ADDR outputText, -SYMBOL_LENGTH
            .ELSEIF operationId==OP_MULTIPLICATION
                invoke AppendToBuffer, ADDR SymbolMultiplication, ADDR outputText, -SYMBOL_LENGTH
            .ELSEIF operationId==OP_DIVISION
                invoke AppendToBuffer, ADDR SymbolDivision, ADDR outputText, -SYMBOL_LENGTH
            .ELSEIF operationId==OP_MODULO
                invoke AppendToBuffer, ADDR SymbolModulo, ADDR outputText, -SYMBOL_LENGTH
            .ENDIF
        .ELSE
            invoke HandleCalculateResult
            .IF operationId==OP_ADDITION
                invoke AppendToBuffer, ADDR SymbolAddition, ADDR outputText, 0
            .ELSEIF operationId==OP_SUBTRACTION
                invoke AppendToBuffer, ADDR SymbolSubtraction, ADDR outputText, 0
            .ELSEIF operationId==OP_MULTIPLICATION
                invoke AppendToBuffer, ADDR SymbolMultiplication, ADDR outputText, 0
            .ELSEIF operationId==OP_DIVISION
                invoke AppendToBuffer, ADDR SymbolDivision, ADDR outputText, 0
            .ELSEIF operationId==OP_MODULO
                invoke AppendToBuffer, ADDR SymbolModulo, ADDR outputText, 0
            .ENDIF
        .ENDIF

        mov al, operationId
        mov activeOperationId, al
        invoke SendMessage, hLabel, WM_SETTEXT, 0, ADDR outputText
        ret
    HandleClickButtonOperation ENDP

    WinMain proc
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra,0
    mov wc.cbWndExtra,0
    push hInstance
    pop wc.hInstance
    invoke CreateSolidBrush, BACKGROUND_COLOR
    mov hBackgroundBrush, eax
    mov wc.hbrBackground, eax
    mov wc.lpszClassName, offset WindowClass
    invoke LoadIcon, hInstance, MAIN_ICON_ID
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, 0, IDC_ARROW
    mov wc.hCursor,eax
    invoke RegisterClassEx, addr wc

    invoke GetSystemMetrics, SM_CXSCREEN ; get the screen width
    mov screenHeight, eax
    invoke GetSystemMetrics, SM_CYSCREEN ; get the screen height
    mov screenWidth, eax

    ; calculate the top-left coordinates for the window to be centered
    mov ebx, screenHeight
    sub ebx, window_width ; subtract the window width
    sar ebx, 1 ; divide by 2

    mov ecx, screenWidth
    sub ecx, window_height ; subtract the window height
    sar ecx, 1 ; divide by 2

    invoke CreateWindowEx, 0, addr WindowClass, addr WindowTitle, WS_OVERLAPPEDWINDOW or WS_VISIBLE, ebx,    ecx,    window_width,    window_height,    0,    0,  hInstance,    0

    .WHILE TRUE
        invoke GetMessage,addr msg,0,0,0
        .BREAK .IF (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .ENDW
    ret
    WinMain endp

    WndProc proc hWnd:HWND, uMsg:UINT,wParam:WPARAM,lParam:LPARAM
        LOCAL hdc:HDC
        LOCAL ps:PAINTSTRUCT

        .IF uMsg==WM_CREATE
            ; Create a font for the label
            invoke CreateFont, 60, 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr FontNameLabel
            mov hLabelFont, eax

            ; Create a font for normal buttons
            invoke CreateFont, 40, 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, addr FontNameButtons
            mov hFontButtonNormal, eax

            ; Calculate label width
            invoke GetLabelWidth
            mov edx, eax

            ; Calculate label height
            invoke GetLabelHeight
            mov esi, eax

            ; Create label
            invoke CreateWindowEx,  0, ADDR StaticControlClass, ADDR outputText,\
                WS_CHILD or WS_VISIBLE or SS_RIGHT or SS_CENTERIMAGE, ELEMENTS_SPACING, ELEMENTS_SPACING, edx, esi, hWnd, LABEL_ID, hInstance, 0
            mov hLabel, eax
            invoke SendMessage, eax, WM_SETFONT, hLabelFont, TRUE

            ; Calculate button width
            invoke GetButtonWidth
            mov ecx, eax

            ; Calculate button height
            invoke GetButtonHeight, esi
            mov edi, eax

            ; Create buttons
            mov edx, ELEMENTS_SPACING ; first button starts at x = ELEMENTS_SPACING
            add esi, ELEMENTS_SPACING * 2 ; label starts at ELEMENTS_SPACING, so the first button starts at y = labelHeight + ELEMENTS_SPACING * 2

            ; AC
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonACText, edx, esi, ecx, edi, hWnd, BUTTON_AC_ID, hFontButtonNormal
            mov hButtonAC, eax
            invoke MoveToNextButton

            ; Delete
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonDeleteText, edx, esi, ecx, edi, hWnd, BUTTON_DELETE_ID, hFontButtonNormal
            mov hButtonDelete, eax
            invoke MoveToNextButton

            ; %
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonModuloText, edx, esi, ecx, edi, hWnd, BUTTON_MODULO_ID, hFontButtonNormal
            mov hButtonModulo, eax
            invoke MoveToNextButton

            ; ÷
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonDivideText, edx, esi, ecx, edi, hWnd, BUTTON_DIVIDE_ID, hFontButtonNormal
            mov hButtonDivide, eax
            invoke MoveToNextRow

            ; 7
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber7Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_7_ID, hFontButtonNormal
            mov hButtonNumber7, eax
            invoke MoveToNextButton

            ; 8
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber8Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_8_ID, hFontButtonNormal
            mov hButtonNumber8, eax
            invoke MoveToNextButton

            ; 9
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber9Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_9_ID, hFontButtonNormal
            mov hButtonNumber9, eax
            invoke MoveToNextButton

            ; x
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonMultiplyText, edx, esi, ecx, edi, hWnd, BUTTON_MULTIPLY_ID, hFontButtonNormal
            mov hButtonMultiply, eax
            invoke MoveToNextRow

            ; 4
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber4Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_4_ID, hFontButtonNormal
            mov hButtonNumber4, eax
            invoke MoveToNextButton

            ; 5
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber5Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_5_ID, hFontButtonNormal
            mov hButtonNumber5, eax
            invoke MoveToNextButton

            ; 6
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber6Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_6_ID, hFontButtonNormal
            mov hButtonNumber6, eax
            invoke MoveToNextButton

            ; -
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonSubtractText, edx, esi, ecx, edi, hWnd, BUTTON_SUBTRACT_ID, hFontButtonNormal
            mov hButtonSubtract, eax
            invoke MoveToNextRow

            ; 1
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber1Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_1_ID, hFontButtonNormal
            mov hButtonNumber1, eax
            invoke MoveToNextButton

            ; 2
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber2Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_2_ID, hFontButtonNormal
            mov hButtonNumber2, eax
            invoke MoveToNextButton

            ; 3
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber3Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_3_ID, hFontButtonNormal
            mov hButtonNumber3, eax
            invoke MoveToNextButton

            ; +
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonAddText, edx, esi, ecx, edi, hWnd, BUTTON_ADD_ID, hFontButtonNormal
            mov hButtonAdd, eax
            invoke MoveToNextRow

            ; +/-
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNegateText, edx, esi, ecx, edi, hWnd, BUTTON_NEGATE_ID, hFontButtonNormal
            mov hButtonNegate, eax
            invoke MoveToNextButton

            ; 0
            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonNumber0Text, edx, esi, ecx, edi, hWnd, BUTTON_NUMBER_0_ID, hFontButtonNormal
            mov hButtonNumber0, eax
            invoke MoveToNextButton

            ; =

            push edx

            mov eax, ecx
            mov ebx, 2 ; Calculate button takes double the space of a single button
            xor edx, edx
            mul ebx
            add eax, ELEMENTS_SPACING ; No spacing because cells are merged
            mov ecx, eax

            pop edx

            invoke CreateButton, ADDR ButtonDefaultClass, ADDR ButtonCalculateText, edx, esi, ecx, edi, hWnd, BUTTON_CALCULATE_ID, hFontButtonNormal
            mov hButtonCalculate, eax

        .ELSEIF uMsg==WM_GETMINMAXINFO
            mov eax, lParam
            mov dword ptr [eax + MINMAXINFO.ptMinTrackSize.x], MIN_WINDOW_WIDTH ; minimum width
            mov dword ptr [eax + MINMAXINFO.ptMinTrackSize.y], MIN_WINDOW_HEIGHT ; minimum height
            
        .ELSEIF uMsg==WM_SIZE
            invoke DwmSetWindowAttribute, hWnd, 20, ADDR x_test, 8

            .IF wParam != SIZE_MINIMIZED
                ; Get the new size of the window
                mov eax, lParam
                mov ecx, eax
                and eax, 0FFFFh ; LOWORD(lParam) contains the new width
                shr ecx, 16     ; HIWORD(lParam) contains the new height
                ; Now eax contains the width and ecx contains the height
                mov window_height, ecx
                mov window_width, eax

                ; Calculate label width
                invoke GetLabelWidth
                mov edx, eax

                ; Calculate label height
                invoke GetLabelHeight
                mov esi, eax

                ; Resize label
                invoke MoveWindow, hLabel, ELEMENTS_SPACING, ELEMENTS_SPACING, edx, esi, TRUE

                ; Calculate button width
                invoke GetButtonWidth
                mov ecx, eax

                ; Calculate button height
                invoke GetButtonHeight, esi
                mov edi, eax

                ;Resize buttons
                mov edx, ELEMENTS_SPACING ; first button starts at x = ELEMENTS_SPACING
                add esi, ELEMENTS_SPACING * 2 ; label starts at ELEMENTS_SPACING, so the first button starts at y = labelHeight + ELEMENTS_SPACING * 2

                ; AC
                invoke MoveButton, hButtonAC, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; Delete
                invoke MoveButton, hButtonDelete, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; %
                invoke MoveButton, hButtonModulo, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; ÷
                invoke MoveButton, hButtonDivide, edx, esi, ecx, edi
                invoke MoveToNextRow

                ; 7
                invoke MoveButton, hButtonNumber7, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; 8
                invoke MoveButton, hButtonNumber8, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; 9
                invoke MoveButton, hButtonNumber9, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; x
                invoke MoveButton, hButtonMultiply, edx, esi, ecx, edi
                invoke MoveToNextRow

                ; 4
                invoke MoveButton, hButtonNumber4, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; 5
                invoke MoveButton, hButtonNumber5, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; 6
                invoke MoveButton, hButtonNumber6, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; -
                invoke MoveButton, hButtonSubtract, edx, esi, ecx, edi
                invoke MoveToNextRow

                ; 1
                invoke MoveButton, hButtonNumber1, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; 2
                invoke MoveButton, hButtonNumber2, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; 3
                invoke MoveButton, hButtonNumber3, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; +
                invoke MoveButton, hButtonAdd, edx, esi, ecx, edi
                invoke MoveToNextRow

                ; +/-
                invoke MoveButton, hButtonNegate, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; 0
                invoke MoveButton, hButtonNumber0, edx, esi, ecx, edi
                invoke MoveToNextButton

                ; =

                push edx

                mov eax, ecx
                mov ebx, 2 ; Calculate button takes double the space of a single button
                xor edx, edx
                mul ebx
                add eax, ELEMENTS_SPACING ; No spacing because cells are merged
                mov ecx, eax

                pop edx

                invoke MoveButton, hButtonCalculate, edx, esi, ecx, edi

            .ENDIF
        .ELSEIF uMsg==WM_CTLCOLORSTATIC
            ; Set the text color to white
            invoke SetTextColor, wParam, TEXT_COLOR

            ; Set the text background to transparent
            invoke SetBkMode, wParam, TRANSPARENT

            ; Return a handle to the brush
            mov eax, hBackgroundBrush
            ret
        .ELSEIF uMsg==WM_COMMAND
            ; Number buttons
            .IF wParam==BUTTON_NUMBER_1_ID
                invoke HandleClickButtonNumber, 1
            .ELSEIF wParam==BUTTON_NUMBER_2_ID
                invoke HandleClickButtonNumber, 2
            .ELSEIF wParam==BUTTON_NUMBER_3_ID
                invoke HandleClickButtonNumber, 3
            .ELSEIF wParam==BUTTON_NUMBER_4_ID
                invoke HandleClickButtonNumber, 4
            .ELSEIF wParam==BUTTON_NUMBER_5_ID
                invoke HandleClickButtonNumber, 5
            .ELSEIF wParam==BUTTON_NUMBER_6_ID
                invoke HandleClickButtonNumber, 6
            .ELSEIF wParam==BUTTON_NUMBER_7_ID
                invoke HandleClickButtonNumber, 7
            .ELSEIF wParam==BUTTON_NUMBER_8_ID
                invoke HandleClickButtonNumber, 8
            .ELSEIF wParam==BUTTON_NUMBER_9_ID
                invoke HandleClickButtonNumber, 9
            .ELSEIF wParam==BUTTON_NUMBER_0_ID
                invoke HandleClickButtonNumber, 0

            ; Command buttons
            .ELSEIF wParam==BUTTON_AC_ID
                invoke HandleClickButtonAc
                
            .ELSEIF wParam==BUTTON_DELETE_ID
                invoke HandleClickButtonDelete

            .ELSEIF wParam==BUTTON_ADD_ID
                invoke HandleClickButtonOperation, OP_ADDITION
               
            .ELSEIF wParam==BUTTON_SUBTRACT_ID
                invoke HandleClickButtonOperation, OP_SUBTRACTION
            
            .ELSEIF wParam==BUTTON_MULTIPLY_ID
                invoke HandleClickButtonOperation, OP_MULTIPLICATION
                
            .ELSEIF wParam==BUTTON_DIVIDE_ID
                invoke HandleClickButtonOperation, OP_DIVISION

            .ELSEIF wParam==BUTTON_MODULO_ID
                invoke HandleClickButtonOperation, OP_MODULO
                
            .ELSEIF wParam==BUTTON_CALCULATE_ID
                invoke HandleClickButtonCalculate
                
            .ELSEIF wParam==BUTTON_NEGATE_ID
                invoke HandleClickButtonNegate

            .ENDIF
        .ELSEIF uMsg==WM_DESTROY
            invoke PostQuitMessage, 0
        .ELSE
        invoke DefWindowProc, hWnd, uMsg, wParam,lParam
        ret
    .ENDIF
    xor eax,eax
    ret
    WndProc endp
end start
