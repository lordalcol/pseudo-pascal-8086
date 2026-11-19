;=============================================================================
; CHARACTER CLASSES: isAlpha, isDigit, isAlNum, isWhite, isAddop, isRelOp...
; STRINGS: strcmp, strcpy, ToUpper, PushString, PopString
; IsAlpha, IsDigit, IsAlNum, strcmp, StrCpy and ToUpper come from the UCR
; Standard Library for 80x86 assembly (Randy Hyde, public domain).
;=============================================================================
CHARSS      SEGMENT PARA PUBLIC 'CODE'
             ASSUME  CS:CHARSS
;
; set ZF=1 if is Alpha
;
IsAlpha         proc	far
		push	ax
		or	al, 20h		;maps UC -> LC.
		sub	al, 'a'		;maps 'a'..'z' -> 0..25.
		cmp	al, 'z'-'a'	;If al > 25 then it's not alpha.
		ja	NotAlpha
IsAl:		cmp	al, al		;Sets zero flag
NotAlpha:	
		pop	ax
		ret
IsAlpha         endp
;
; IsDigit- 	Checks a character to see if it is a decimal digit.
;               Checks character in AL.
;
IsDigit         proc	far

		cmp	al, '0'
		jb	NotDigit
		cmp	al, '9'
		ja	NotDigit
		cmp	al, al			;Sets zero flag.
NotDigit:	
		ret
IsDigit         endp
;
; IsAlNum-
;		Checks a character to see if it is alphanumeric.
;		Returns the status in the zero flag.
;		ZF=1 if character is in the set 
;			{'0'..'9', 'A'..'Z', 'a'..'z'}
;		ZF=0 if the character is not in this set.
;	
; 		Checks the character passed in the AL register.
IsAlNum         proc	far

		cmp	al, '0'		;See if in the range '0'..'9'.
		jb	NotAN
		cmp	al, '9'
		jbe	IsAN

		push	ax
		or	al, 20h		;Convert UC -> LC
		sub	al, 'a'		;Convert 'a'..'z' -> 0..25
		cmp	al, 'z'-'a'	;Is alpha if 25 or less.
		pop	ax
		jnbe	NotAN
IsAN:		cmp	al, al
NotAN:		ret
IsAlNum         endp
;
; isWhite	Is AL white space? The comment character ';' counts too.
;
IsWhite         proc	far
		cmp	al, ' '
		je      ItIsWhite
		cmp	al, TAB
		je      ItIsWhite
		cmp	al, CR
		je      ItIsWhite
		cmp	al, LF
		je      ItIsWhite
		cmp	al, chrCOMMENT
		je      ItIsWhite
NotWhite:
		ret
ItIsWhite:
		cmp	al, al			;Sets zero flag.
                ret
IsWhite         endp
;
; isEndBlock	Does the token in AL end a block (ENDxxx, END, ELSE)?
;
isEndBlock         proc	far
		cmp	al, 'e'
		je      ItisEndBlock
		cmp	al, 'l'
		je      ItisEndBlock
		ret
ItisEndBlock:
		cmp	al, al			;Sets zero flag.
                ret
isEndBlock         endp
;
; isOrOp	Recognize a Boolean OR operator: | (or), ~ (xor)
;
isOrOp         proc	far
		cmp	al, '|'
		je      ItisOrOp
		cmp	al, '~'
		je      ItisOrOp
		ret
ItisOrOp:
		cmp	al, al			;Sets zero flag.
                ret
isOrOp         endp
;
; isAddOp	Recognize an add operator: + -
;
isAddop         proc	far
		cmp	al, '+'
		je      ItisAddop
		cmp	al, '-'
		je      ItisAddop
		ret
ItisAddop:
		cmp	al, al			;Sets zero flag.
                ret
isAddop         endp
;
; isMulOp	Recognize a multiply operator: * /
;
isMulOp         proc	far
		cmp	al, '*'
		je      ItisMulOp
		cmp	al, '/'
		je      ItisMulOp
		ret
ItisMulOp:
		cmp	al, al			;Sets zero flag.
                ret
isMulOp         endp
;
; isRelOp	Recognize a relational operator: = < >
;
isRelOp         proc	far
		cmp	al, '='
		je      ItisRelOp
		cmp	al, '<'
		je      ItisRelOp
		cmp	al, '>'
		je      ItisRelOp
		ret
ItisRelOp:
		cmp	al, al			;Sets zero flag.
                ret
isRelOp         endp
; strcmp -	Compares two strings.
;
; inputs:
;		es:di -	First string  (The string to compare)
;		ds:si -	Second string (The string to compare against)
;		e.g., "if (es:di < dx:si) then ..."
; returns: 
;		cx- zero if strings are NOT EQUAL
;                   N if they are equal, N is length
;		Condition codes set according to the string comparison.
;		You should use the unsigned branches (ja, jb, je, etc.)
;		after calling this routine.
strcmp		proc	far
		push	es
		push	ds
		push	bx
		push	ax
		push	si
		push	di
; Swap pointers so they're more convenient for the LODSB/SCASB instrs.
		xor	bx, bx		;Set initial index to zero.
; In order to preserve the direction flag across this call, we have to
; test whether or not it is set here and execute two completely separate
; pieces of code (so we know which state to exit in.  Unfortunately, we
; cannot use pushf to preserve this flag since we need to return status
; info in the other flags.
		pushf
		pop	ax
		test	ah, 4		;Test direction bit.
		jnz	DirIsSet
sclp:		lodsb
		scasb
		jne	scNE		;If strings are <>, quit.
		inc	bx	        ;Increment index into strs.
		cmp	al, 0		;Check for end of strings.
		jne	sclp
		pushf
		dec	bx
		popf
;
scNE:		pop	di
		pop	si
		mov	cx, bx
		pop	ax
		pop	bx
		pop	ds
		pop	es
		ret			;Return with direction flag clear.
DirIsSet:	lodsb
		scasb
		jne	scNE2		 ;If strings are <>, quit.
		inc	bx
		cmp	al, 0		 ;Check for end of strings.
		jne	DirIsSet
		pushf
		dec	bx
		popf
scNE2:		pop	di
		pop	si
		mov	cx, bx
		pop	ax
		pop	bx
		pop	ds
		pop	es
		std			;Return with direction flag set.
                ret
strcmp		endp

; StrCpy    -   Copies string pointed at by es:di to string pointed at by
;               ds:si. (Sorry for the backward use of registers, this
;		matches the rest of the standard library though).
;
; inputs:
;		es:di-	Zero-terminated source string.
;		ds:si-  Buffer for destination string.
;
; outputs:	es:di-	Points at destination string.
;
;
; Note: 	The destination buffer must be large enough to hold the
;		string and zero terminating byte.
StrCpy          proc    far
		;push	ds
		push	cx
		push	ax
		pushf
		push	si

		cld
		mov	al, 0
		mov	cx, 0ffffh
		push	di
	repne	scasb
		pop	di
		neg	cx
		mov	ax, es
		mov	ds, ax

		push	ds
		pop	es

		xchg	si, di
		dec	cx
		shr	cx, 1
		jnc	CpyWrd
		lodsb
		stosb
CpyWrd:	rep	movsw

DidByte:	pop	si
		popf
		pop	ax
		pop	cx
		;pop	ds

		push	ds
		pop	es
		mov	di, si
		ret
StrCpy          endp
;
;       Converts AL to upper case
;
ToUpper	proc	far
		cmp	al, 'a'			;See if we've got a
		jb	NotLower		; lower case character
		cmp	al, 'z'			; to convert.
		ja	NotLower
		and	al, 05fh		;Convert lc -> UC.
NotLower:	ret
ToUpper	endp
;=============================================================================
; PushString and PopString push and pop the zero-terminated string at SI on
; the stack, one character per word. The parser uses them as a string stack
; (names, labels) while it recurses. Both take the return address off the
; stack first and put it back on top before returning.
; They change AX, BX (Push), CX (Pop), DX and DI (Pop).
;=============================================================================
PushString proc   far
                pop bx  ;return offset
                pop dx  ;return segment
                mov cx,0
                mov ah,0
PushStringCount:                ;find the end of the string
                cmp byte ptr [si],0
                je  PushStringWhile
                inc  si
                inc cx
                jmp PushStringCount
PushStringWhile:                ;push it backwards, the 0 first
                mov al,byte ptr [si]
                push ax
                cmp cx,0
                je  PushStringEND
                dec  si
                dec  cx
                jmp PushStringWhile
PushStringEND:
                push dx  ;return segment
                push bx  ;return offset
                ret
PushString endp
;
PopString proc   far
                pop cx  ;return offset
                pop dx  ;return segment
                mov di,si
PopStringWhile:                 ;pop characters up to the 0
                pop ax
                mov [si],al
                cmp al,0
                je  PopStringEND
                inc  si
                jmp PopStringWhile
PopStringEND:
                mov si,di
                push dx  ;return segment
                push cx  ;return offset
                ret
PopString endp
CHARSS      ENDS
