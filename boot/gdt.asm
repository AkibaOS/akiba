;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  AkibaOS GDT Loader
;;
;;  This file contains the assembly function that loads a new GDT from C++.
;;  
;;  The GDT (Global Descriptor Table) is a data structure used by x86 CPUs
;;  to define memory segments and their protection levels. Even in 64-bit
;;  mode where segmentation is largely replaced by paging, the GDT is still
;;  necessary for defining code and data segments with different privilege
;;  levels.
;;
;;  Function Signature:
;;  void load_gdt(GDT::Pointer* gdt_pointer);
;;
;;  Notes:
;;  - Loading a new GDT doesn't automatically update segment registers
;;  - We must explicitly reload segment registers with appropriate selectors
;;  - The code segment (CS) can only be reloaded using a far jump/return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

global load_gdt            ; Export the function symbol for linking

section .text
bits 64                    ; Specify 64-bit instructions

;;
;; void load_gdt(GDT::Pointer* gdt_pointer)
;;
;; Loads a new GDT and updates all segment registers.
;; Parameter:
;;   rdi = Pointer to GDT::Pointer structure containing GDT size and address
;;
load_gdt:
    ;; Load the GDT using the LGDT instruction
    ;; The pointer parameter is passed in RDI according to System V AMD64 ABI
    lgdt [rdi]             ; Load new GDT using the pointer in RDI
    
    ;; Update all data segment registers with the data segment selector
    ;; 0x10 = 16 bytes into GDT = 3rd entry (0 = null, 8 = code, 16 = data)
    mov ax, 0x10           ; Data segment selector (3rd GDT entry)
    mov ds, ax             ; Data Segment
    mov es, ax             ; Extra Segment
    mov fs, ax             ; F Segment (often used for thread-local storage)
    mov gs, ax             ; G Segment (often used for CPU-local storage)
    mov ss, ax             ; Stack Segment
    
    ;; The Code Segment (CS) register cannot be directly modified
    ;; We must use a far return (or far jump) to reload CS
    push 0x08              ; Push code segment selector (2nd GDT entry)
    push .reload_cs        ; Push return address
    retfq                  ; Far return - pops RIP and CS
    
.reload_cs:
    ret                    ; Return to caller