global verbose
global nl
global newPath
global oldPath
section .data
	; Options
	verbose:		db 0
	; Messages
	nl:			db 10
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
			db 9,"-v",9,"Prints information about each file system operation before it executes", 10
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
	accesErr:		db "Permission denied",10
	accesLen		equ $-accesErr
	againErr:		db "Resource temporarily unavailable",10
	againLen		equ $-againErr
	invalErr:		db "Invalid argument",10
	invalLen		equ $-invalErr
	noMemErr:		db "Cannot allocate memory",10
	noMemLen		equ $-noMemErr
	mFileErr:		db "Too many open files",10
	mFileLen		equ $-mFileErr
	nameTooLongErr:		db "File name too long (buffer overflow?)",10
	nameTooLongLen		equ $-nameTooLongErr
	notDirErr:		db "Not a directory",10
	notDirLen		equ $-notDirErr
	badFErr:		db "Bad file descriptor",10
	badFLen			equ $-badFErr
	faultErr:		db "Bad address",10
	faultLen		equ $-faultErr
	noEntErr:		db "No such file or directory",10
	noEntLen		equ $-noEntErr
	; Error message template
	Err:			db "Message",10
	Len			equ $-Err
	; Error context messages
	errnoMsg:		db "Error Number: "
	errnoLen		equ $-errnoMsg
	recurrsionMsg:		db "Recursion Depth: "
	recurrsionLen:		equ $-recurrsionMsg
	newPathMsg:		db "New Path: "
	newPathLen		equ $-newPathMsg
	oldPathMsg:		db "Old Path: "
	oldPathLen		equ $-oldPathMsg
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
%macro newline 0
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, nl
	mov	rdx, 1
	syscall
%endmacro

%macro printmsg	1
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, %1Msg
	mov	rdx, %1Len
	syscall
%endmacro

%macro printerr 1
	mov	rax, 1
	mov	rdi, 2
	mov	rsi, %1Err
	mov	rdx, %1Len
	syscall
%endmacro
extern parsedir
;----Errors/Messages----;
parsedirError:
	; Print context
	; Convert errno to positive
	xor	rax, 0xFFFFFFFFFFFFFFFF
	cmp	rax, 0
	jne	unknown
	push	rax	; For checking error
	push	rbx	; For recursion depth
	push	rax	; For printing errno
	printmsg errno
	pop	rax
	mov	rbx, 10
	mov	rcx, writebuffer
	mov	r8, 0
errnoConvertLoop:
	xor	rdx, rdx
	div	rbx
	add	rdx, 48
	mov	[rcx], dl
	inc	r8
	inc	rcx
	cmp	rax, 0
	jne	errnoConvertLoop
	; Print errno
	mov	rax, 1
	mov	rdi, 2
	mov	rsi, writebuffer
	mov	rdx, r8
	syscall
	newline
%ifdef DEBUG
	; Print recursion depth
	printmsg recurrsion
	pop	rax
	mov	rbx, 10
	mov	rcx, writebuffer
	mov	r8, 0
recurrsionConvertLoop:
	xor	rdx, rdx
	div	rbx
	add	rdx, 48
	mov	[rcx], dl
	inc	r8
	inc	rcx
	cmp	rax, 0
	jne	recurrsionConvertLoop
	; Print depth
	mov	rax, 1
	mov	rdi, 2
	mov	rsi, writebuffer
	mov	rdx, r8
	syscall
	newline
	; Print newpath
	printmsg newPath
	mov	rsi, newPath
newPathPrintLoop:
	mov	rax, 1
	mov	rdi, 2
	mov	rdx, 1
	syscall
	inc	rsi
	cmp	byte [rsi], 0
	jne	newPathPrintLoop
	newline
	; Print oldpath
	printmsg oldPath
	mov	rsi, oldPath
oldPathPrintLoop:
	mov	rax, 1
	mov	rdi, 2
	mov	rdx, 1
	syscall
	inc	rsi
	cmp	byte [rsi], 0
	jne	oldPathPrintLoop
	newline
%else
	pop	rax	; Clear recursion depth from the stack
%endif
; Parsedir errors by syscall
	pop	rax
; mmap
; EACCES
	cmp	rax, 13
	je	noPerm
; EAGAIN
	cmp	rax, 11
	je	unavaliable
; EINVAL
	cmp	rax, 22
	je	invalid
; ENOMEM
	cmp	rax, 12
	je	noMem
; openat
; EMFILE
	cmp	rax, 24
	je	noFiles
; ENAMETOOLONG
	cmp	rax, 36
	je	passedFileNameWasTooLongForTheKernelToHandleProbablyBecausePathBufferOverflowed
; ENOTDIR
	cmp	rax, 20
	je	noDir
; getdents64
; EBADF
	cmp	rax, 9
	je	badFile
; EFAULT
	cmp	rax, 14
	je	badMem
; ENOENT
	cmp	rax, 2
	je	noEnt
	jne	unknown
noPerm:
	printerr acces
	jmp	exitError

unavaliable:
	printerr again
	jmp	exitError

invalid:
	printerr inval
	jmp	exitError

noMem:
	printerr noMem
	jmp	exitError

noFiles:
	printerr mFile
	jmp	exitError

passedFileNameWasTooLongForTheKernelToHandleProbablyBecausePathBufferOverflowed:
	printerr nameTooLong
	jmp	exitError

noDir:
	printerr notDir
	jmp	exitError

badFile:
	printerr badF
	jmp	exitError

badMem:
	printerr fault
	jmp	exitError

noEnt:
	printerr noEnt
	jmp	exitError

help:
	printmsg help
	jmp	exitSuccess
tooManyArgs:
	printerr tooManyArgs
	jmp	exitError
insideTarget:
	printerr insideTarget
	jmp	exitError
badArgs:
	printerr badArgs
	jmp	exitError
unknown:
	printerr unknown
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
	;-h   |	help    |	104
	;-t   |	timer   |	116
	;-v   |	verbose |	118

	mov	cl, [rax]	; Get char
	or	cl, 10000b	; Make lowercase
	cmp	cl, 104
	je	help
	cmp	cl, 116
	je	startTimer
	cmp	cl, 118
	je	verboseMode
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
verboseMode:
	push	rax
	mov	rax, verbose
	mov	byte [rax], 1
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
	call	parsedir
	cmp	rax, 0
	jne	parsedirError
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
	xor	rsi, rsi
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
