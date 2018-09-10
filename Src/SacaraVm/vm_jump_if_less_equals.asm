header_VmJumpIfLessEquals
vm_jump_if_less_equals PROC
	push ebp
	mov ebp, esp	
	
	; pop the value
	push [ebp+arg0]
	call vm_stack_pop_enc

	; test the carry flag
	mov ebx, [ebp+arg0]
	mov ebx, [ebx+vm_flags]
	test ebx, VM_CARRY_FLAG
	jnz modify_ip

	; test the zero flag
	mov ebx, [ebp+arg0]
	mov ebx, [ebx+vm_flags]
	test ebx, VM_ZERO_FLAG
	jz finish

modify_ip:
	; modify the vm IP
	mov ebx, [ebp+arg0]
	mov [ebx+vm_ip], eax

finish:	
	mov ebp, esp
	pop ebp
	ret
vm_jump_if_less_equals ENDP
header_end