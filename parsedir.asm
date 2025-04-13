section .text
global parsedir
parsedir:
	; void parsedir(char[] *dirname, char[] *newpath)
	; Alocate memory for dents
	mov	rax, 9		; sys_mmap
	mov	rdi, 0		; kernel determines addr
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
	; dirname
	mov	r14, qword [rsp+16]
	; newpath
	mov	r15, qword [rsp+24]
	; Open dir
	mov	rax, 257
	mov	rdi, -100	; Relative to current dir
	mov	rsi, r14	; dirname
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
	mov	r11, rax
	add	r11, r13	; end of the thing
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
	mov	rax, r15
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
	mov	rax, r14
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
	
	; Store important stuff
	push	r11
	push	r12
	push	r13
	; Args
	push	r15	; newpath
	push	r14	; dirname
	; Create new dir
	mov	rax, 83
	mov	rdi, r15
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
	; Restore args
	pop	r14
	pop	r15
	; Delete old dir
	mov	rax, 84
	mov	rdi, r14
	syscall
	cmp	rax, -39
	je	dirDeleteOldDirSkipErr
	cmp	rax, 0
	jl	spawnError
dirDeleteOldDirSkipErr:
	; Restore regs
	pop	r13
	pop	r12
	pop	r11
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
	mov	rax, r14
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
	mov	rax, r15
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

	; Link to new file
	mov	rax, 86
	mov	rdi, r14	; Link oldpath
	mov	rsi, r15	; To newpath
	syscall
	cmp	rax, 0
	jl	spawnError
	; Delete old file
	mov	rax, 87
	; Old path is alread in rdi
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
	cmp	r13, r11	; are we at the end of the jit
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
	mov	rax, 0
	ret

spawnError:
	mov	rbx, 1
	ret

bubbleError:
	inc	rbx
	ret
die:
	mov	rax, 60
	mov	rdi, 1
	syscall
