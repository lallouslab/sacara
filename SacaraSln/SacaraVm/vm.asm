; *****************************
; arguments: vm context, var index, imm
; *****************************
vm_local_var_set PROC
	push ebp
	mov ebp, esp

	; get the local var buffer
	mov eax, [ebp+arg0]
	mov eax, [eax+vm_sp]
	mov eax, [eax+vm_local_vars]

	; go to the given offset
	mov ebx, [ebp+arg1]
	lea eax, [eax+TYPE DWORD*ebx]

	; set the value
	mov ebx, [ebp+arg2]
	mov [eax], ebx

	mov ebp, esp
	pop ebp
	ret 0Ch
vm_local_var_set ENDP

; *****************************
; arguments: vm context, var index
; *****************************
vm_local_var_get PROC
	push ebp
	mov ebp, esp

	; get the local var buffer
	mov eax, [ebp+arg0]
	mov eax, [eax+vm_sp]
	mov eax, [eax+vm_local_vars]

	; go to the given offset
	mov ebx, [ebp+arg1]
	lea eax, [eax+TYPE DWORD*ebx]

	; read the value
	mov eax, [eax]

	mov ebp, esp
	pop ebp
	ret 8h
vm_local_var_get ENDP


; *****************************
; arguments: vm context, imm
; *****************************
vm_stack_push PROC
	push ebp
	mov ebp, esp

	; read stack frame header
	mov ebx, [ebp+arg0]
	mov ebx, [ebx+vm_sp] 
	
	; increment stack by 1
	inc dword ptr [ebx+vm_stack_top]
	
	; set value on top of the stack	
	mov eax, [ebp+arg1]
	mov [ebx+vm_stack_top], eax

	mov ebp, esp
	pop ebp
	ret 8h
vm_stack_push ENDP

; *****************************
; arguments: vm context
; *****************************
vm_stack_pop PROC
	push ebp
	mov ebp, esp

	; read stack frame header
	mov ebx, [ebp+arg0]
	mov ebx, [ebx+vm_sp] 

	; read value
	mov eax, [ebx+vm_stack_top]	
	mov dword ptr [ebx+vm_stack_top], 0h ; zero the value

	; decrement stack by 1
	dec dword ptr [ebx+vm_stack_top]

	mov ebp, esp
	pop ebp
	ret 4h
vm_stack_pop ENDP

; *****************************
; arguments: stack memory, previous stack frame pointer
; *****************************
vm_init_stack_frame PROC
	push ebp
	mov ebp, esp
	mov eax, [ebp+arg0] ; read stack base
	mov edx, [ebp+arg1] ; previous stack frame pointer

	; fill stack frame header
	lea ebx, [eax+TYPE DWORD*4 ]
	mov dword ptr [eax+vm_stack_previous_frame], edx
	mov [eax+vm_stack_base], ebx
	mov [eax+vm_stack_top], ebx

	; allocate space for local vars
	push vm_stack_vars_size
	call heap_alloc
	mov ebx, [ebp+arg0]
	mov [ebx+vm_local_vars], eax

	mov ebp, esp
	pop ebp
	ret 8h
vm_init_stack_frame ENDP


; *****************************
; arguments: vm_context, vm_code, vm_code_size
; *****************************
vm_init PROC
	push ebp
	mov ebp, esp
	mov eax, [ebp+arg0]
	mov [eax+vm_ip], dword ptr 0h	; zero VM ip
	mov [eax+vm_flags], dword ptr 0h; zero flags

	; allocate space for the stack
	push vm_stack_size
	call heap_alloc
	
	; save the stack pointer
	mov ecx, [ebp+arg0]
	mov [ecx+vm_sp], eax

	; init stack frame
	push 0h ; no previous stack frame
	push eax
	call vm_init_stack_frame
		
	; set the code pointer
	mov ebx, [ebp+arg1]
	mov ecx, [ebp+arg0]
	mov [ecx+vm_code], ebx

	; set the code size
	mov ebx, [ebp+arg2]
	mov [ecx+vm_code_size], ebx

	mov ebp, esp
	pop ebp
	ret 0Ch
vm_init ENDP

; *****************************
; arguments: vm_context
; *****************************
vm_free PROC
	push ebp
	mov ebp, esp

	; get stack pointer addr
	mov eax, [ebp+arg0]
	mov eax, [eax+vm_sp]

	; free vars buffer
	push [eax+vm_local_vars]
	call heap_free

	; free stack frame	
	mov eax, [ebp+arg0]
	push [eax+vm_sp]
	call heap_free
	
	mov ebp, esp
	pop ebp
	ret 4h
vm_free ENDP

; *****************************
; arguments: vm_context
; *****************************
vm_is_stack_empty PROC
	push ebp
	mov ebp, esp

	; get stack pointer addr
	mov ecx, [ebp+arg0]
	mov ecx, [ecx+vm_sp]

	mov ebx, [ecx+vm_stack_base]
	xor eax, eax
	cmp [ecx+vm_stack_top], ebx	
	jz equals
	jmp finish

equals:
	inc eax
finish:
	mov ebp, esp
	pop ebp
	ret 4h
vm_is_stack_empty ENDP

; *****************************
; arguments: vm_context, increment size
; *****************************
vm_increment_ip PROC
	push ebp
	mov ebp, esp
	mov ecx, [ebp+arg1]
	mov eax, [ebp+arg0]
	mov ebx, [eax]
	lea ebx, [ebx+vm_ip+ecx]
	mov [eax+vm_ip], ebx
	mov ebp, esp
	pop ebp
	ret 8
vm_increment_ip ENDP

; *****************************
; arguments: vm_context, size
; *****************************
vm_read_code PROC
	push ebp
	mov ebp, esp

	; read vm ip
	mov ebp, esp
	mov eax, [ebp+arg0]
	mov ebx, [eax+vm_ip]

	; read word opcode
	mov esi, [eax+vm_code]
	lea esi, [esi+ebx]
	xor eax, eax

	cmp dword ptr [ebp+arg1], TYPE DWORD
	je read_four_bytes
	mov ax, word ptr [esi]
	jmp finish

read_four_bytes:
	mov eax, dword ptr [esi]

finish:
	push eax
	; increment the VM ip
	push [ebp+arg1]
	push [ebp+arg0]
	call vm_increment_ip
	pop eax

	mov ebp, esp
	pop ebp
	ret 8
vm_read_code ENDP

; *****************************
; arguments: vm_context, extracted opcode
; return: 0 on success, opcode index on error
; *****************************
vm_execute PROC
	push ebp
	mov ebp, esp		
	
	; find the handler
	mov ebx, [ebp+arg0]
	push [ebp+arg1]	
	push vm_instructions_size
	push start_vm_instructions
	call find_vm_handler

	; invoke the handler if found
	test eax, eax
	je error

	push [ebp+arg0] ; all handlers take 1 argument which is the VM context
	call eax
	add esp, 4
	xor eax, eax
	jmp end_execution

error:
	; invalid opcode, set the halt flag and error flag
	mov eax, [ebp+arg0]
	mov ebx, [eax+vm_flags]
	or ebx, 0C0000000h
	mov [eax+vm_flags], ebx

	; set eax to the offset of the opcode that generated the error
	mov eax, [eax+vm_ip]

end_execution:	
	mov ebp, esp
	pop ebp
	ret 8
vm_execute ENDP

; *****************************
; arguments: vm_context, opcode
; *****************************
vm_decode_opcode PROC
	push ebp
	mov ebp, esp

	; check if the encrypt flag is set
	mov eax, [ebp+arg1]
	test eax, 08000h
	jz clear_flags

	; decrypt the opcode
	mov eax, [ebp+arg1]	
	xor eax, INIT_OPCODE_XOR_KEY

	mov ebx, [ebp+arg0]
	xor eax, [ebx+vm_ip]

clear_flags:
	; clear first 4 bits since they are flags and save the result
	and eax, 0FFFh

	mov ebp, esp
	pop ebp
	ret 8h
vm_decode_opcode ENDP

; *****************************
; arguments: vm_context
; return: 0 on success, opcode index on error
; *****************************
vm_main PROC
	push ebp
	mov ebp, esp
	
vm_loop:		
	; read the opcode to execute	
	push 2
	push [ebp+arg0]
	call vm_read_code

	; decode opcode
	push eax
	push [ebp+arg0]
	call vm_decode_opcode

	; execute the VM instruction
	push eax
	push [ebp+arg0]
	call vm_execute
		
	; check the finish flag in the context
	mov ebx, [ebp+arg0]
	mov ebx, [ebx+vm_flags]
	test ebx, 80000000h
	je vm_loop
	
	mov ebp, esp
	pop ebp
	ret 8
vm_main ENDP