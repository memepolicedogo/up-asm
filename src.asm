section .data
	; Messages
	deltaSeconds:		times 64 db 0	; 64 byte buffer
				db "s",10
	deltaMicroseconds:	times 64 db 0	; 64 byte buffer
				db "us", 10
	helpMsg:	
			db "Usage: up [options] <dir>",10
			db "Shifts the contents of a directory up one step",10
			db 10
			db 9,"Options:",10
			db 9,"-t",9,"Prints the execution time in microseconds after execution",10
	helpLen			equ $-helpMsg
	tooManyArgsErr:		db "Too many args were passed",10
				db "Use -h for help",10
	tooManyArgsLen		equ $-tooManyArgsErr
	insideTargetErr:	db "Up cannot be called from inside the target",10
	insideTargetLen		equ $-insideTargetErr
	badArgsErr:		db "Invalid argument(s) were passed",10
				db "Use -h for help",10
	badArgsLen		equ $-badArgsErr
	unknownErr:		db "An unexpected error has occured",10
	unknownLen		equ $-unknownErr
	; Error message template
	Err:			db "Message",10
	Len			equ $-Err
	; Timer memory
	startSeconds:
		dq	0
	startMicroseconds:
		dq	0
	endSeconds:
		dq	0
	endMicroseconds:
		dq	0
	timerRunning:	db 0
	; Path memory
	newPath:	db "./",0
		times 4096-$+newPath db 0 ; Adds null bytes to newPath till it reaches 4096 bytes
section .bss
	oldPath:	resb 4069
	argc		resq 1
	writebuffer	resb 265
section .text
extern parsedir
;----Errors/Messages----;
template:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, Err
	mov	rdx, Len
	syscall
	jmp	exitError
help:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, helpMsg
	mov	rdx, helpLen
	syscall
	jmp	exitSuccess
tooManyArgs:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, tooManyArgsErr
	mov	rdx, tooManyArgsLen
	syscall
	jmp	exitError
insideTarget:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, insideTargetErr
	mov	rdx, insideTargetLen
	syscall
	jmp	exitError
badArgs:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, badArgsErr
	mov	rdx, badArgsLen
	syscall
	jmp	exitError
unknown:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, unknownErr
	mov	rdx, unknownLen
	syscall
	jmp	exitError
;---------Main----------;
global _start
_start:
	; Get argc
	pop	rbx
	cmp	rbx, 1	; Give help if no args
	je	help
	cmp	rbx, 2
	je	oneArg
	cmp	rbx, 3
	jg	tooManyArgs
	; Handle multiple args
	pop	rax	; Get argv
multArgsLoop:
	inc	rax
	cmp	byte [rax], 0
	jne	multArgsLoop
	dec	rbx
	cmp	rbx, 2
	je	parseOption
	cmp	rbx, 1
	je	parsePath
	jl	badArgs
parseOption:
	; Parse first argument
	inc	rax
	cmp	byte [rax], 45	; if (argv[1][0] == '-')
	jne	badArgs
	inc	rax
	cmp	byte [rax], 45	; for --
	jne	checkOption
	inc	rax
checkOption:
	;Flag---Option--ASCII
	;-h   |	help  |	104
	;-t   |	timer |	116

	mov	cl, [rax]	; Get char
	or	cl, 10000b	; Make lowercase
	cmp	cl, 104
	je	help
	cmp	cl, 116
	je	startTimer
	jmp	badArgs
startTimer:
	push	rax
	; sys_gettimeofday
	mov	rax, 96
	mov	rdi, startSeconds
	syscall
	mov	byte [timerRunning], 1
	pop	rax
	jmp	multArgsLoop

oneArg:
	; Handle one arg
	pop	rax
oneArgLoop:
	inc	rax
	cmp	byte [rax], 0
	jne	oneArgLoop
parsePath:
	inc	rax
	cmp	byte [rax], 46	; Check if we're in the target
	jne	safePath
	inc	rax
	cmp	byte [rax], 46	; If it starts with .. we probably don't want to be there
	je	insideTarget
	cmp	byte [rax], 47
	jne	parsePathBackOne; Target just starts with .
	inc	rax
	cmp	byte [rax], 0	; if full target path is './'
	je	insideTarget
	dec	rax
parsePathBackOne:
	dec	rax
safePath:
	; Store target path in our jit
	; Use cl for intermediary storage
	; Use rdx for oldPath
	mov	rdx, oldPath
	xor	rcx, rcx
safePathLoop:
	mov	cl, [rax]
	mov	[rdx], cl
	inc	rax
	inc	rdx
	cmp	byte [rax], 0
	jne	safePathLoop
	; Check for trailing /
	dec	rax
	cmp	byte [rax], 47
	je	startMove
	mov	byte [rdx], 47
startMove:
	; Call the function
	push	newPath
	push	oldPath
	call	parsedir
	; Remove the base of the old structure
	mov	rax, 84
	mov	rdi, oldPath
	syscall
	cmp	rax, -20
	jne	wasDir
	; If ENOTDIR was returned, use unlink instead
	mov	rax, 87
	mov	rdi, oldPath
	syscall
wasDir:
	cmp	rax, -39
	je	cleanUp
	cmp	rax, 0
	jl	unknown


;-----Exit/Clean-up-----;
cleanUp:
	cmp	byte [timerRunning], 0
	je	exitSuccess
	jne	endTimer


endTimer:
	; Get end time
	mov	rax, 96
	mov	rdi, endSeconds
	syscall
	; Compare seconds
	mov	rax, qword [endSeconds]
	mov	rbx, qword [startSeconds]
	sub	rax, rbx
	cmp	rax, 0
	je	compareMicroseconds
	; Print seconds
	mov	rbx, 10
	mov	rcx, deltaSeconds
	add	rcx, 64
	mov	r8, 2	; Length counter
secondsLoop:
	dec	rcx
	xor	rdx, rdx
	div	rbx
	add	dl, 48
	mov	[rcx], dl
	inc	r8
	cmp	rax, 0
	jne	secondsLoop
	; Print
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, rcx
	mov	rdx, r8
	syscall

compareMicroseconds:
	mov	rax, qword [endMicroseconds]
	mov	rbx, qword [startMicroseconds]
	sub	rax, rbx
	; Print microseconds
	mov	rbx, 10
	mov	rcx, deltaMicroseconds
	add	rcx, 64
	mov	r8, 3	; Length counter
microsecondsLoop:
	dec	rcx
	xor	rdx, rdx
	div	rbx
	add	dl, 48
	mov	[rcx], dl
	inc	r8
	cmp	rax, 0
	jne	microsecondsLoop
	; Print
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, rcx
	mov	rdx, r8
	syscall
	
exitSuccess:
	mov	rax, 60
	mov	rdi, 0
	syscall
exitError:
	mov	rax, 60
	mov	rdi, 1
	syscall
