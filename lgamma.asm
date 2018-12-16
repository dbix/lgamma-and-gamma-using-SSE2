; Below are routines to approximate the lgamma and gamma functions. It took a
; lot of time to learn how to use sse2.

segment .data
	fmt_request_val	db   "Compute lgamma and gamma(x) of x: ", 0
	fmt_scan_val    db   " %lf", 0
	fmt_print_val   db   "lgamma(%lf)=%lf", 10, "gamma(%lf)=%lf", 10, 0

	LGAM_COF 		dq   57.156235665862923500, -59.597960355475491200,  14.136097974741747100, -0.4919138160976201990,  0.3399464998481188e-4,  0.4652362892704857e-4, -0.9837447530487956e-4,  0.1580887032249124e-3, -0.2102644417241048e-3, 0.2174396181152126e-3, -0.1643181065367638e-3,  0.8441822398385274e-4, -0.2619083840158140e-4,  0.3689918265953162e-5
	ZERO			dq   0.0
	COEF 			dq   5.2421875
	ZERO_5			dq   0.5
	ONE 			dq   1.0
	SER      		dq 	 0.999999999999997092
	TWO_FIVE        dq   2.5066282746310005
	NAN             dq   7FF8000000000000H

segment .bss
	j             	resq 1
	x			  	resq 1
	y			  	resq 1
	z 			  	resq 1
	tmp			  	resq 1
	ser 	      	resq 1
	g_output 		resq 1
	lg_output       resq 1
	input 			resq 1
	return 		  	resq 1

segment .text
	extern printf
	extern scanf
	extern log
	extern exp
	global main

main:
	push	rbp
	mov		rbp, rsp
	; ********** CODE STARTS HERE **********

	; request floating point value from user
	mov rdi, fmt_request_val
	call printf

	; scanf floating point value from user
	mov rdi, fmt_scan_val
	lea rsi, [input]
	call scanf

	; get gamma result
	movsd xmm0, qword [input]
	call gamma
	movsd qword [g_output], xmm0

	; get lgamma result
	movsd xmm0, qword [input]
	call lgamma
	movsd qword [lg_output], xmm0

	; printf("lgamma(%lf)=%lf \ngamma(%lf)=%lf",input, lg_output, g_output);
	mov rdi, fmt_print_val
	movsd xmm0, [input]
	movsd xmm1, [lg_output]
	movsd xmm2, [input]
	movsd xmm3, [g_output]
	mov rax, 4
	call printf

	; ; printf("%lf", z);
	; mov rdi, fmt_print_val
	; movsd xmm1, xmm0		; xmm1 = lgamma result
	; movsd xmm0, [z]			; xmm0 = z
	; mov rax, 2				; tell printf that there is one fp value
	; call printf

	; *********** CODE ENDS HERE ***********
	mov		rax, 0
	mov		rsp, rbp
	pop		rbp
	ret

; c-ish version:
; gamma(z):
;	int j;
;	double x, tmp, y, ser;
;	if (z <= 0) return NAN;
;	y = x = z;
;	tmp = x + 5.2421875;
;	tmp = (x + 0.5) * log(tmp) - tmp;
;	ser = 0.999999999999997092;
;	for (int j = 0; j < 14; j++) ser += cof[j] / ++y;
;	return tmp + log(2.5066282746310005 * ser / x);
lgamma:
	; z = xmm0
	movsd qword [z], xmm0			; z = xmm0
	pxor xmm0, xmm0					; xmm0 = 0
	movsd xmm1, qword [z]			; xmm1 = z
	ucomisd xmm0, xmm1				; if (z >= 0)
	jc lgamma_z_gte_zero			; continue
		movsd xmm0, qword [NAN]		; else return NaN
		jmp lgamma_return
	lgamma_z_gte_zero:
	; x = y = z
	movsd xmm0, qword [z]			; xmm0 = z
	movsd qword [x], xmm0			; x = z
	movsd qword [y], xmm0			; y = z

	; tmp = x + 5.2421875
	movsd qword [tmp], xmm0			; tmp = z = x
	movsd xmm0, qword [COEF]		; xmm0 = 5.2421875
	movsd xmm1, qword [tmp]			; xmm1 = tmp
	addsd xmm0, xmm1				; xmm0 = tmp + 5.2421875
	movsd qword [tmp], xmm0			; tmp = tmp + 5.2421875 = x + 5.2421875

	; tmp = (x + 0.5) * log(tmp) - tmp
	movsd xmm0, qword [tmp]
	call log						; xmm0 = log(tmp)
	movsd xmm1, qword [ZERO_5]
	movsd xmm2, qword [x]
	addsd xmm1, xmm2				; xmm1 = x + 0.5
	movsd xmm2, qword [tmp]			; xmm2 = tmp
	mulsd xmm0, xmm1				; xmm0 = log(tmp) * (x + 0.5)
	subsd xmm0, xmm2				; xmm0 = (x + 0.5) * log(tmp) - tmp
	movsd qword [tmp], xmm0			; tmp  = (x + 0.5) * log(tmp) - tmp

	mov dword [j], 0				; j = 0
	movsd xmm0, qword [SER]			; xmm0 = SER = 0.999999999999997092
	movsd qword [ser], xmm0			; ser = 0.999999999999997092
	; for (int j = 0; j < 14; j++) ser += cof[j] / ++y;
	lgamma_for:
	mov rax, qword [j]
	cmp rax, 14
	je lgamma_return
		; ser += cof[j]/++y;
		lea rdx, [rax*8]
		lea rax, [LGAM_COF]
		movsd xmm0, qword [rdx+rax]	; xmm0 = LGAM_COF[j]
		movsd xmm1, qword [ONE]		; xmm1 = 1.0
		movsd xmm2, qword [y]		; xmm2 = y
		addsd xmm1, xmm2			; xmm1 = y + 1.0
		movsd qword [y], xmm1		; ++y
		divsd xmm0, xmm1			; xmm0 = LGAM_COF[j] / ++y
		movsd xmm1, qword [ser]		; xmm1 = ser
		addsd xmm0, xmm1			; xmm0 = LGAM_COF[j] / ++y
		movsd qword [ser], xmm0		; ser += LGAM_COF[j] / ++y
		add qword [j], 1			; j++
		jmp lgamma_for

	lgamma_return:
	; return tmp + log(2.5066282746310005 * ser / x)
	movsd xmm0, qword [ser]			; xmm0 = ser
	movsd xmm1, qword [x]			; xmm1 = x
	divsd xmm0, xmm1				; xmm0 = ser / x
	movsd xmm1, qword [TWO_FIVE]	; xmm1 = 2.5066282746310005
	mulsd xmm0, xmm1				; xmm0 = 2.5066282746... * ser / x
	call log						; xmm0 = log(xmm0)
	movsd xmm1, qword [tmp]			; xmm1 = tmp
	addsd xmm0, xmm1
	ret

; gamma(x) = e^lgamma(x)
gamma:
	call lgamma
	call exp
	ret
