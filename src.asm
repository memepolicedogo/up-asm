section .data
	newpath:	db "./",0
	helpmsg:	
		db "Usage: up [options] <dir>",10
		db "Shifts the contents of a directory up one step",10,10
		db 9,"Options:",10
		db 9,"-t",9,"Prints the execution time in microseconds after execution",10
	helplen		equ $-helpmsg
	nodoterr:	db "up cannot be called on the current directory",10
	nodotlen	equ $-nodoterr
	starttime:
		dq	0
		dq	0
	endtime:
		dq	0
		dq	0
section .bss
	printtime	resb 1
	argc		resq 1
	dirname		resq 1
	dirfd		resq 1
	dentread	resq 1
	writebuffer	resb 265
section .text
extern parsedir
global _start
_start:
	; Get start time
	mov	rax, 96
	mov	rdi, starttime
	mov	rsi, 0
	syscall
	pop	rbx
	cmp	rbx, 1
	je	help
	cmp	rbx, 2
	jg	timer
	mov	byte [printtime], 1
timer:
	pop	rax
arg1loop:
	inc	rax
	cmp	byte [rax], 0
	jne	arg1loop
	dec	rbx
	inc	rax
	cmp	rbx, 1
	jne	arg1loop
	mov	qword [dirname], rax
	; Check if arg is '.'
	cmp	word [rax], 0x2e00; ascii for '.' plus null term
	je	nodot
	cmp	dword [rax], 0x2e2f0000; ascii for './' plus null term
	je	nodot

arg2loop:
	inc	rax
	cmp	byte [rax], 0
	jne	arg2loop
	dec	rax
	cmp	byte [rax], 47
	je	skipTrailingSlash
	inc	rax
	mov	byte [rax], 47
	inc	rax
	mov	byte [rax], 0
skipTrailingSlash:
	push	newpath	; arg 2
	mov	rax, qword [dirname]
	push	rax	; arg 1
	call	parsedir
	; Remove base dir
	mov	rax, 84
	mov	rdi, qword [dirname]
	syscall
	jmp	exit
	
	


nodot:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, nodoterr
	mov	rdx, nodotlen
	syscall

help:
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, helpmsg
	mov	rdx, helplen
	syscall
exit:
	mov	al, byte [printtime]
	cmp	al, 0
	jne	skipprint
	mov	rax, 96
	mov	rdi, endtime
	mov	rsi, 0
	syscall
	mov	rbx, qword [starttime+8]
	mov	rax, qword [endtime+8]
	sub	rax, rbx
	mov	rbx, 10
	mov	r11, writebuffer
	add	r11, 255
	mov	byte [r11], 10
	dec	r11
convertLoop:
	xor	rdx, rdx
	div	rbx
	add	rdx, 48
	mov	[r11], dl
	dec	r11
	cmp	rax, 0
	jne	convertLoop
	inc	r11
	mov	rdx, writebuffer
	add	rdx, 256
	sub	rdx, r11
	mov	rax, 1
	mov	rdi, 1
	mov	rsi, r11
	syscall
skipprint:	
	mov	rax, 60
	mov	rdi, 0
	syscall
