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
	jl	error
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
	jl	error
	; Store fd
	mov	r12, rax
	; Get info
	mov	rax, 217
	mov	rdi, r12
	mov	rsi, r13
	mov	rdx, 0x8000
	syscall
	cmp	rax, 0
	jl	error
	; i dont wanna have to write shit for big ass mfs I'm so tired
	cmp	rax, 0x8000
	je	error
	mov	r11, rax
	add	r11, r13	; end of the thing
direntItr:
	inc	r11
	add	r13, 18		; Get to type
	xor	rbx, rbx
	mov	bl, [r13]	; Get type
	; Handle given jit
	cmp	bl, 8
	je	handleFile
	cmp	bl, 4
	je	handleDir
	cmp	bl, 10
	je	handleFile
	jmp	error
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
	; newpath
	mov	rax, 9
	mov	rdi, 0
	mov	rsi, 0x1000
	mov	rdx, 3
	mov	r10, 0x22	; MAP_ANONYMOUS | MAP_PRIVATE
	mov	r8, 0
	mov	r9, 0
	syscall
	cmp	rax, 0
	jl	error
	push	rax	; Store new arg
	mov	rbx, r15; Build from newpath
dirNewNewpathItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	dirNewNewpathItr
	mov	rbx, r13; Build from filename
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

	; oldpath
	mov	rax, 9		; sys_mmap
	mov	rdi, 0		; kernel determines addr
	mov	rsi, 0x1000	; Length in hex
	mov	rdx, 3		; PROT_READ | PROT_WRITE
	mov	r10, 0x22	; MAP_ANONYMOUS | MAP_PRIVATE
	; Null other fields
	mov	r8, 0
	mov	r9, 0
	syscall
	cmp	rax, 0
	jl	error
	; build old path
	push	rax	; Save old path start
	mov	rbx, r14
dirOldDirnameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	dirOldDirnameItr
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
	
	pop	rdi	; old
	pop	rsi	; new
	; Store important stuff
	push	r11
	push	r12
	push	r13
	push	r14
	push	r15
	; Args
	push	rsi
	push	rdi
	; Create new dir
	mov	rax, 83
	mov	rdi, rsi
	mov	rsi, 0xffffffffffffffff
	syscall
	cmp	rax, -17
	je	dirOldFilenameSkipErr
	cmp	rax, 0
	jl	error
dirOldFilenameSkipErr:
	call	parsedir	; WTF?????? RECURSION???
	; Delete old dir
	mov	rax, 84
	pop	rdi
	syscall
	cmp	rax, -39
	je	dirDeleteOldDirSkipErr
	cmp	rax, 0
	jl	error
dirDeleteOldDirSkipErr:
	; Free
	mov	rax, 11
	mov	rsi, 0x1000
	syscall
	mov	rax, 11
	pop	rdi	; new
	mov	rsi, 0x1000
	syscall
	xor	rdi, rdi
	; Restore regs
	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	r11
	jmp	nextDent


handleFile:
	push	rbx
	inc	r13	; Get to name
	; oldpath
	mov	rax, 9		; sys_mmap
	mov	rdi, 0		; kernel determines addr
	mov	rsi, 0x1000	; Length in hex
	mov	rdx, 3		; PROT_READ | PROT_WRITE
	mov	r10, 0x22	; MAP_ANONYMOUS | MAP_PRIVATE
	; Null other fields
	mov	r8, 0
	mov	r9, 0
	syscall
	cmp	rax, 0
	jl	error
	; build old path
	push	rax	; Save old path start
	mov	rbx, r14
fileOldDirnameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	fileOldDirnameItr
	mov	rbx, r13
fileOldFilenameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	fileOldFilenameItr
	mov	byte [rax], 0	; Null terminator
	; Do some stupid shit for symlinks fuck
	mov	rbx, [rsp+8]	; get tha jit
	cmp	rbx, 10		; we linky?
	jne	fileNewDirnameNotItr
	; Make buffer for link read
	mov	rax, 9		; sys_mmap
	mov	rdi, 0		; kernel determines addr
	mov	rsi, 0x1000	; Length in hex
	mov	rdx, 3		; PROT_READ | PROT_WRITE
	mov	r10, 0x22	; MAP_ANONYMOUS | MAP_PRIVATE
	; Null other fields
	mov	r8, 0
	mov	r9, 0
	syscall
	cmp	rax, 0
	jl	error
	mov	rsi, rax	; New mem we just alloc'd
	mov	rax, 89		; Readlink
	pop	rdi		; previous mem we alloc'd
	mov	rdx, 0x1000
	syscall
	cmp	rax, 0
	jl	error
	push	rsi		; Store new mem we alloc'd on the stack
	add	rsi, rax	; Get to the end of the string
	mov	byte [rsi], 0	; Add null term (Its probably 0 already but the manpage scared me)
	; free
	mov	rax, 11
	mov	rsi, 0x1000
	syscall

	
fileNewDirnameNotItr:

	; newpath
	mov	rax, 9		; sys_mmap
	mov	rdi, 0		; kernel determines addr
	mov	rsi, 0x1000	; Length in hex
	mov	rdx, 3		; PROT_READ | PROT_WRITE
	mov	r10, 0x22	; MAP_ANONYMOUS | MAP_PRIVATE
	; Null other fields
	mov	r8, 0
	mov	r9, 0
	syscall
	cmp	rax, 0
	jl	error
	; build new path
	push	rax	; Save new path start
	mov	rbx, r15
fileNewDirnameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	fileNewDirnameItr
	mov	rbx, r13
fileNewFilenameItr:
	mov	cl, [rbx]
	mov	[rax], cl
	inc	rbx
	inc	rax
	cmp	byte [rbx], 0
	jne	fileNewFilenameItr
	mov	byte [rax], 0	; Null terminator

	; Link to new file
	mov	rax, 86
	pop	rsi	; Pop new into arg 2
	pop	rdi	; Pop old into arg 1
	pop	rbx	; its the type again
	cmp	rbx, 10	; linky poo
	jne	fileStooopppid911
	add	rax, 2	; sys_link -> sys_symlink
fileStooopppid911:
	syscall
	cmp	rax, 0
	jl	error
	; Save newpath
	push	rsi
	; Delete old file
	mov	rax, 87
	; Old path is alread in rdi
	syscall
	cmp	rax, 0
	jl	error
	; Free oldpath
	mov	rax, 11
	; Address still in rdi
	mov	rsi, 0x1000
	syscall
	; Free newpath
	mov	rax, 11
	pop	rdi
	syscall
	xor	rsi, rsi
	xor	rdi, rdi
nextDent:
	; Reset for next dent
	sub	r13, 3	; Gets to reclen
	xor	rax, rax
	mov	al, byte [r13]
	sub	rax, 16
	add	r13, rax	; Gets to end of the line
	cmp	qword [r13], 0	; I hope this is chill
	jne	direntItr

return:
	; free memory
	mov	rax, 11
	pop	rdi		; Get mem address off the stack
	mov	rsi, 0x8000
	syscall
	ret

error:
	; Kill the whole jit
	mov	rax, 60
	mov	rdi, 1
	syscall
