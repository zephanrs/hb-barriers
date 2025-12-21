//  AMOADD barrier

//  a0 = amo lock addr (in DRAM). Initialized to 0
//  a1 = sense word addr (in DMEM).  Initialized to 1

//  void bsg_barrier_amoadd(int*, int*);

.text
.globl bsg_barrier_amoadd
bsg_barrier_amoadd:
  // t0 - sense val
  // t1 - amo result
  // t2 - check val
  // t3 - wakeup val

  // send amoadd
  lw t0, 0(a1)
  amoadd.w t1, t0, 0(a0)
  li t5, 0x20000000

  // is sense -1 or +1?
  // set wakeup val
  sub t3, x0, t0
 
  // set check val
  li t2, 1
  bge x0, t0, bsg_barrier_amoadd_check

  // +1 case
  li t2, (bsg_tiles_X*bsg_tiles_Y)-1

bsg_barrier_amoadd_check:
  bne t2, t1, bsg_barrier_amoadd_sleep
  // wakeup core 0
  add t6, t5, a1
  sw  t3, 0(t6)

bsg_barrier_amoadd_sleep:
  lr.w t0, 0(a1)
  beq t3, t0, bsg_barrier_amoadd_wakeup
  // we need to check this, in order to support the reservation
  // being cleared by a context switch
  lr.w.aq t0, 0(a1)
  beq t3, t0, bsg_barrier_amoadd_sleep
  ret

bsg_barrier_amoadd_wakeup:
  // t0 - x addr
  // t1 - y addr
  // t2 - base address
  lw  t0, __bsg_x
  lw  t1, __bsg_y

  slli t6, t1, 24
  add  t2, t5, t6
  slli t6, t0, 18
  add  t2, t2, t6
  add  t2, t2, a1

  // t0 - dim addr
  // t4 - shamt
  // t5 - dim dist
  // t6 - temp reg
  ori t0, t0, bsg_tiles_X
  li  t4, 18

  // if y=0, wake-up in x dim
  beq  x0, t1, bsg_barrier_start_dim

bsg_barrier_wakeup_y:
  // wake-up in y dim
  ori t0, t1, bsg_tiles_Y
  li  t4, 24

bsg_barrier_start_dim:
  li t5, 1

bsg_barrier_setup:
  slli t5, t5, 0x1
  andi t6, t0, 0x1
  srli t0, t0, 0x1
  beq  t6, x0, bsg_barrier_setup
  srli t5, t5, 0x2

bsg_barrier_wakeup:
  sll  t6, t5, t4
  add  t6, t2, t6
  sw   t3, 0(t6)
  srli t5, t5, 0x1
  bne  t5, x0, bsg_barrier_wakeup
  
  li   t6, 18
  beq  t4, t6, bsg_barrier_wakeup_y
  ret