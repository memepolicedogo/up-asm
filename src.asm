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
	deltaNanosec:		times 64 db 0	; 64 byte buffer
				db "ns", 10
	helpMsg:	
			db "Usage: up [options] <dir>",10
			db "Shifts the contents of a directory up one step",10
			db 10
			db 9,"Options:",10
			db 9,"-t(R)",9,"Prints the real world time between calling and exiting of the process",10
			db 9,"-tC",9,"Prints the CPU time of the process",10
			db 9,"-tA",9,"Prints both real time and CPU time",10
			db 9,"-v",9,"Prints information about each file system operation before it executes", 10
	helpLen			equ $-helpMsg
	cpuTimeMsg:		db "CPU time:",10
	cpuTimeLen		equ $-cpuTimeMsg
	realTimeMsg:		db "Real time:",10
	realTimeLen		equ $-realTimeMsg
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
	existErr:		db "New file exists",10
	existLen		equ $-existErr
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
	timerSignal:
		dd 1
		dd 1
		dd 1
		dd 1
	cpuStart:
		dq	0
		dq	0 
	cpuEnd:
		dq 0
		dq 0
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
	inc	rax
	cmp	rax, 0
	jle	unknown
	push	rax	; For checking error
	push	rbx	; For recursion depth
	push	rax	; For printing errno
	printmsg errno
	pop	rax
	mov	rbx, 10
	mov	rcx, writebuffer
	add	rcx, 255
	mov	r8, 0
errnoConvertLoop:
	xor	rdx, rdx
	div	rbx
	add	rdx, 48
	mov	[rcx], dl
	inc	r8
	dec	rcx
	cmp	rax, 0
	jne	errnoConvertLoop
	inc	rcx
	; Print errno
	mov	rax, 1
	mov	rdi, 2
	mov	rsi, rcx
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
; EEXIST
	cmp	rax, 17
	je	exist
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

exist:
	printerr exist
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
	; Check timer type
	inc	rax
	cmp	byte [rax], 0
	je	realTime
	cmp	byte [rax], 82
	je	realTime
	cmp	byte [rax], 67
	je	cpuTime
	cmp	byte [rax], 65
	jne	badArgs
cpuTime:
	push	rax
	; sys_clock_gettime
	mov	rax, 228
	mov	rdi, 2		; CLOCK_PROCESS_CPUTIME_ID
	mov	rsi, cpuStart
	syscall
	cmp	rax, 0
	jne	unknown
	; Arm the timer to expire in 1 microsecond
	pop	rax
	mov	byte [timerRunning], 2
	cmp	byte [rax], 65
	jne	multArgsLoop
	

realTime:
	cmp	byte [rax], 0
	jne	realTimeSkip
	dec	rax
realTimeSkip:
	push	rax
	; sys_gettimeofday
	mov	rax, 96
	mov	rdi, startSeconds
	syscall
	inc	byte [timerRunning]
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
	mov	rax, 96
	mov	rdi, endSeconds
	xor	rsi, rsi
	syscall
	cmp	byte [timerRunning], 1
	je	endRealTime
	mov	rax, 228
	mov	rdi, 2
	mov	rsi, cpuEnd
	syscall
	cmp	byte [timerRunning], 2
	je	endCPUTime
	jg	endBoth

endBoth:
	printmsg cpuTime
endCPUTime:
	; Get time
cpuTimeNano:
	mov	rax, cpuEnd
	add	rax, 8
	mov	rbx, qword [rax]
	push	rbx
	mov	rax, cpuStart
	add	rax, 8
	mov	rbx, qword [rax]
	pop	rax
	sub	rax, rbx
	; Print out
	mov	rbx, 10
	mov	rcx, deltaNanosec
	add	rcx, 64
	mov	r8, 3	; Length counter
cpuNanosecLoop:
	dec	rcx
	xor	rdx, rdx
	div	rbx
	add	dl, 48
	mov	[rcx], dl
	inc	r8
	cmp	rax, 0
	jne	cpuNanosecLoop
	; Print
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, rcx
	mov	rdx, r8
	syscall

	cmp	byte [timerRunning], 3
	jne	exitSuccess
	
	; Clean delta second buffer
	mov	rax, deltaSeconds
dsbuffcleanloop:
	mov	qword [rax], 0
	add	rax, 8
	cmp	rax, deltaSeconds+64
	jl	dsbuffcleanloop

	printmsg realTime

endRealTime:
	; Get end time
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
