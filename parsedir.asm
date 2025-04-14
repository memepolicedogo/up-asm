extern verbose
extern nl
extern newPath
extern oldPath
%macro newline 0
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, nl
	mov	rdx, 1
	syscall
%endmacro
section .data
	linkFrom:	db "Moving "
	linkFromLen	equ $-linkFrom
	linkTo:		db " to "
	linkToLen	equ $-linkTo
	unlinkMsg:	db "Removing "
	unlinkLen	equ $-unlinkMsg
	mkdirMsg:	db "Creating directory "
	mkdirLen	equ $-mkdirMsg
	rmdirMsg:	db "Removing directory "
	rmdirLen	equ $-rmdirMsg

section .text
global parsedir
parsedir:
	; Alocate memory for dents
	mov	rax, 9		; sys_mmap
	mov	rdi, 0		; kernel determines addr
	; Push a null value to the stack to help with cleanup
	push	rdi
	mov	rsi, 0x8000	; Length in hex
	mov	rdx, 3		; PROT_READ | PROT_WRITE
	mov	r10, 0x22	; MAP_ANONYMOUS | MAP_PRIVATE
	; Null other fields
	mov	r8, 0
	mov	r9, 0
	syscall
	cmp	rax, 0
	jl	spawnError
	; Save buffer pointer
	push	rax
	mov	r13, rax
	; Get args from stack
	; Open dir
	mov	rax, 257
	mov	rdi, -100	; Relative to current dir
	mov	rsi, oldPath	; dirname
	mov	rdx, 02204000q	; O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_DIRECTORY
	syscall
	cmp	rax, 0
	jl	spawnError
	; Store fd
	mov	r12, rax
	; Get info
newDirent:
	pop	r13
	push	r13
	mov	rax, 217
	mov	rdi, r12
	mov	rsi, r13
	mov	rdx, 0x8000
	syscall
	; Dirent:
	; qword Inode number
	; qword Offset (sequence)
	; word  Length of remaining content
	; byte  File type
	; char* Filename
	; null bytes to align along 8 bytes
	; e.g.
	; All of this is small endian btw
	;0x00 db 12,34,56,78,12,34,56,78	; Inode
	;0x08 db 01,00,00,00,00,00,00,00	; Offset
	;0x10 db 24,00				; Length
	;0x10 db 04				; Type
	;0x10 db 'a','b','c'			; Name
	;0x10 db 00,00				; Padding
	; Technically one byte of the padding is a 
	; null terminator for the filename therefore 
	; if the last char of your filename is at the
	; edge of the 8 byte boundry you'll get a full
	; row of padding after that
	cmp	rax, 0
	jl	spawnError
	je	return
	mov	r14, rax
	add	r14, r13	; end of the thing
direntItr:
	add	r13, 18		; Get to type
	xor	rbx, rbx
	mov	bl, [r13]	; Get type
	; Handle given jit
	cmp	bl, 8
	je	handleFile
	cmp	bl, 4
	je	handleDir
	cmp	bl, 10		; symlink
	jmp	die
handleDir:
	inc	r13	; Get to name
	; Skip '.' and ".."
	cmp	byte [r13], 0x2e
	jne	notdot
	cmp	byte [r13+1], 0
	je	nextDent
	cmp	byte [r13+1], 0x2e
	jne	notdot
	cmp	byte [r13+2], 0
	je	nextDent
notdot:
	; Get to the end of newpath
	mov	rax, newPath
dirNewPathLoop:
	inc	rax
	cmp	byte [rax], 0
	jne	dirNewPathLoop
	; Add filename to the end
	mov	rbx, r13
dirNewFilenameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	dirNewFilenameItr
	mov	byte [rax], 47; dir slash
	inc	rax
	mov	byte [rax], 0; Null term
	; Store end of new path
	push	rax

	; Get to the end of oldpath
	mov	rax, oldPath
dirOldPathLoop:
	inc	rax
	cmp	byte [rax], 0
	jne	dirOldPathLoop

	; Add filename to the end
	mov	rbx, r13
dirOldFilenameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	dirOldFilenameItr
	mov	byte [rax], 47; dir slash
	inc	rax
	mov	byte [rax], 0	; Null terminator
	; Store end of old path
	push	rax

	mov	rax, verbose
	cmp	byte [rax], 0
	je	mkdir
	; Print message
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, mkdirMsg
	mov	rdx, mkdirLen
	syscall
	; Get length of new path
	pop	rdi ; temp
	pop	rdx ; end of new path
	push	rdx 
	push	rdi
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, newPath
	sub	rdx, newPath	; newPathEnd -= newPath
	
	syscall
	newline

mkdir:
	
	; Store important stuff
	push	r14
	push	r12
	push	r13
	; Create new dir
	mov	rax, 83
	mov	rdi, newPath
	mov	rsi, 0xffffffffffffffff
	syscall
	cmp	rax, -17
	je	dirOldFilenameSkipErr
	cmp	rax, 0
	jl	spawnError
dirOldFilenameSkipErr:
	call	parsedir
	cmp	rax, 0
	jl	bubbleError
	; Restore regs
	pop	r13
	pop	r12
	pop	r14

	mov	rax, verbose
	cmp	byte [rax], 0
	je	rmdir
	; Print message
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, rmdirMsg
	mov	rdx, rmdirLen
	syscall
	; Get length of old path
	pop	rdx ; end of old path
	push	rdx 
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, oldPath
	sub	rdx, oldPath	; oldPathEnd -= oldPath
	
	syscall
	newline

rmdir:
	; Delete old dir
	mov	rax, 84
	mov	rdi, oldPath
	syscall
	cmp	rax, -39
	je	dirDeleteOldDirSkipErr
	cmp	rax, 0
	jl	spawnError
dirDeleteOldDirSkipErr:
	; Clean old path
	pop	rax
	dec	rax	; Already ends with null
dirOldPathCleanLoop:
	; Edit before check to remove the / we added
	mov	byte [rax], 0
	dec	rax
	cmp	byte [rax], 47
	jne	dirOldPathCleanLoop
	; Clean new path
	pop	rax
	dec	rax
dirNewPathCleanLoop:
	mov	byte [rax], 0
	dec	rax
	cmp	byte [rax], 47
	jne	dirNewPathCleanLoop
	jmp	nextDent


handleFile:
	inc	r13	; Get to name
	; get to the end of oldpath
	mov	rax, oldPath
fileOldDirnameItr:
	inc	rax
	cmp	byte [rax], 0
	jne	fileOldDirnameItr

	; Add the filename to the end of oldpath
	mov	rbx, r13
fileOldFilenameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	fileOldFilenameItr
	mov	byte [rax], 0	; Null terminator
	push	rax	; Store the end of the path
	
	; Get to end of newpath
	mov	rax, newPath
fileNewDirnameItr:
	inc	rax
	cmp	byte [rax], 0
	jne	fileNewDirnameItr

	; Add filename to end of newpath
	mov	rbx, r13
fileNewFilenameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	fileNewFilenameItr
	mov	byte [rax], 0	; Null terminator
	push	rax	; Store the end of the path

	mov	rax, verbose
	cmp	byte [rax], 0
	je	link
	; Print message
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, linkFrom
	mov	rdx, linkFromLen
	syscall
	; Get length of old path
	pop	rdi ; temp
	pop	rdx ; end of old path
	push	rdx 
	push	rdi ; restore the stack
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, oldPath
	sub	rdx, oldPath	; oldPathEnd -= oldPath
	
	syscall
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, linkTo
	mov	rdx, linkToLen
	syscall
	; Get length of new path
	pop	rdx ; end of new path
	push	rdx ; restore the stack
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, newPath
	sub	rdx, newPath	; newPathEnd -= newPath
	
	syscall
	newline

link:
	; Link to new file
	mov	rax, 86
	mov	rdi, oldPath	; Link oldpath
	mov	rsi, newPath	; To newpath
	syscall
	cmp	rax, 0
	jl	spawnError

	mov	rax, verbose
	cmp	byte [rax], 0
	je	unlink
	; Print message
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, unlinkMsg
	mov	rdx, unlinkLen
	syscall
	; Get length of old path
	pop	rdi ; temp
	pop	rdx ; end of old path
	push	rdx 
	push	rdi ; restore the stack
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, oldPath
	sub	rdx, oldPath	; oldPathEnd -= oldPath
	
	syscall
	newline

unlink:
	; Delete old file
	mov	rax, 87
	mov	rdi, oldPath
	syscall
	cmp	rax, 0
	jl	spawnError
	; Clean up paths
	pop	rax	; Get the end of oldpath
	dec	rax	; end is alread null
fileCleanOldPathLoop:
	mov	byte [rax], 0
	dec	rax
	cmp	byte [rax], 47
	jne	fileCleanOldPathLoop

	pop	rax	; Get the end of newpath
	dec	rax	; end is alread null
fileCleanNewPathLoop:
	mov	byte [rax], 0
	dec	rax
	cmp	byte [rax], 47
	jne	fileCleanNewPathLoop
nextDent:
	; Reset for next dent
	sub	r13, 3	; Gets to reclen
	xor	rax, rax
	mov	al, byte [r13]
	sub	rax, 16
	add	r13, rax	; Gets to end of the line
	cmp	r13, r14	; are we at the end of the jit
	jl	direntItr
	jge	newDirent

return:
	; Close fd
	mov	rax, 3
	mov	rdi, r12
	syscall
	; Free memory
	mov	rax, 11
	pop	rdi		; Get mem address off the stack
	mov	rsi, 0x8000
	syscall
	pop	rax	; Remove null delimnator and set errno to 0
	ret

spawnError:
	mov	rbx, 1
cleanStack:
	pop	rcx
	cmp	rcx, 0
	jne	cleanStack
	ret

bubbleError:
	inc	rbx
	jmp	cleanStack
die:
	mov	rax, 60
	mov	rdi, 1
	syscall
