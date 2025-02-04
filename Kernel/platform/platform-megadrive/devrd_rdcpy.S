.globl rd_cpy
        
        .text
rd_cpy:
        movem.l %d2/%a2,-(%sp)           | Save registers we'll use
        
        move.l 12(%sp),%a0               | dst address
        move.l 16(%sp),%a1               | src address
        move.l 20(%sp),%d0               | count

        move.l %d0,%d2                   | Save original count for return
        lsr.l #2,%d0                     | Convert to longwords (divide by 4)
        
        | Copy longwords
.copy_long:
        tst.l %d0                        | Check if any longwords left
        beq .copy_bytes
        subq.l #1,%d0
        move.l (%a1)+,(%a0)+
        bra .copy_long
        
        | Handle remaining bytes
.copy_bytes:
        and.l #3,%d2                     | Get remaining byte count
        beq .done
.byte_loop:
        subq.l #1,%d2
        move.b (%a1)+,(%a0)+
        bne .byte_loop
        
.done:
        move.l 16(%sp),%d0               | Return original count
        movem.l (%sp)+,%d2/%a2           | Restore registers
        rts