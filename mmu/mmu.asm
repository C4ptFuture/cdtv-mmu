           ************************************************************************
           ***                                                                  ***
           ***             -= COMMODORE CDTV ROM OPERATING SYSTEM =-            ***
           ***                                                                  ***
           ************************************************************************
           ***                                                                  ***
           ***     CDTV MMU & Cache Control (mmu)                               ***
           ***     Copyright (c) 2021-2026 CDTV Land. Published under GPLv3.    ***
           ***     Written by Captain Future                                    ***
           ***                                                                  ***
           ************************************************************************


  INCLUDE      exec/exec_lib.i
  INCLUDE      exec/execbase.i
  INCLUDE      exec/resident.i

  INCLUDE      rev.i
  INCLUDE      defs.i


****************************************************************************************************
*                                          INTRODUCTION                                            *
****************************************************************************************************

  ; This resident module is to be included with CDTV OS ROM builds to support CDTV players
  ; with a 68020, 68030, 68040 or 68060 installed. It disables CPU caching on startup which is known to
  ; cause data corruption when reading the CDTV OS ROM addresses on Viper 530 ($F00000-$F7FFFF).
  ; It also prevents caching of the DMAC's and TriPort chip's I/O lines, which the CPU will
  ; happily do unless instructed otherwise. Note: This module on its own is not enough
  ; to fix CD-ROM drive issues with 68030 systems! The cdtv.device driver requires fixing
  ; as well in the way it talks to the DMAC. This fix is implemented in my custom 
  ; CDTV OS ROM v 2.35 and 2.36, but as cdtv.device is closed source, I am sadly not able to
  ; publish the source code.

  ; Notes on DMAC Autoconfig I/O cache inhibit

  ; The Zorro II bus does not have cache inhibit lines, so all the Zorro II Autoconfig I/O
  ; addresses will be cached by the 68030, which includes the DMAC and TriPort (6525) I/O
  ; lines. I have not tested whether cdtv.device operates properly when caching is enabled,
  ; so it _might_ work, but it's generally a "very bad idea"(tm) to cache I/O addresses, because
  ; their contents might change without the CPU knowing it, which can result in invalid
  ; caches and the Earth exploding.

  ; Cache inhibiting using the 68030 MMU can be set up using either a) MMU tables or b)
  ; the Transparent Translation registers (TT1, TT2). MMU tables offer fine grained control,
  ; but require some memory to hold the tables. The more fine grained, the more memory you'll need.
  ; The TTx option requires just one single MMU instruction, but has the disadvantage that the
  ; finest granularity it can work with is 16 MB (24 bits) so we can only turn caching on or off
  ; for the whole 24-bit address range ($000000-$FFFFFF) in its entirety. Any 32-bit Fast RAM
  ; that is present on the system remains cacheable.

  ; Since ROM space is at a premium, we go with the TTx option. This will ensure that every 
  ; system will be able to boot and that the CD-ROM drive will function correctly. More fine
  ; grained configuration over cache inhibit should be configured using proper MMU configuration
  ; tools like mmu.library, which can take over this responsibility once the system has booted.

  ; Notes on 68040, 68060 and PiStorm support

  ; The 68040 and 68060 do not have the 68030 MMU, so PMOVE into TT0 is illegal on them and
  ; must not be executed (doing so traps as an illegal instruction). Instead these CPUs provide
  ; four transparent translation registers - ITT0/ITT1 for instruction accesses and DTT0/DTT1
  ; for data accesses - reached with MOVEC rather than PMOVE. They are independent of the page
  ; tables, so like the 030 TT0 they let us set cache inhibit for a region with no MMU tables.
  ; Their granularity is the same 16 MB minimum as the 030 (base/mask compare A31-A24), so we
  ; again cover the whole 24-bit range with a single register pair. We set ITT0 (the ROM window)
  ; and DTT0 (the DMAC/TriPort I/O lines) to noncachable/serialized - see SetTTR040.

  ; PiStorm: the Emu68 core advertises itself as a 68040 and the Musashi core as a 68020 by
  ; default. Neither emulates the 68040/060 caches in a way that makes cache inhibit necessary
  ; (emulated memory is coherent), and both absorb the MOVEC into the TTRs without faulting.
  ; Emu68 decodes it and shadows the value, Musashi treats an 040-class core's TTR write as a
  ; no-op. So the 040/060 path below is a harmless no-op on PiStorm and does the real work only
  ; on genuine 040/060 silicon. (It stays gated behind the CPU-type check either way.)

  ; Notes on 68020 support

  ; The 68020 has only a 256-byte on-chip instruction cache and no data cache. It also has no
  ; on-chip MMU - transparent translation lives in the external 68851 PMMU, which we cannot assume
  ; is fitted - so there is no way to cache-inhibit a specific address range on a bare 68020 the
  ; way the 030/040/060 paths do. The only cache control available is the global CACR. We disable
  ; the instruction cache outright and clear any lines already cached from the ROM window - see
  ; SetCACR020. With no data cache present the DMAC/TriPort I/O lines are never cached in the first
  ; place, so disabling the instruction cache fully covers the 68020.

  ; This module uses the 68030 on-chip MMU (PMOVE into TT0), so the assembler must target the
  ; 68030 to accept those instructions. This only permits the wider instruction set. The opcodes
  ; emitted for the plain 68000 code below are unchanged, and PMOVE itself is guarded at runtime
  ; by the 68030 check.
  ;
  ; The 68040/68060 cache-inhibit path uses MOVEC into ITT0/DTT0 plus CPUSHA. Those instructions
  ; are illegal in MC68030 mode, and PMOVE is illegal in MC68040 mode, so the two instruction
  ; sets cannot share a single MACHINE directive. Rather than juggle the CPU target mid-file, the
  ; handful of 040/060 opcodes are emitted directly with dc.w and annotated with the mnemonic
  ; they encode (encodings verified with vasm in MC68040 mode). Like PMOVE, they only ever run
  ; behind the runtime CPU-type check.
  ;
  ; The 68020 cache-inhibit path uses MOVEC into CACR, which is valid in MC68030 mode (CACR exists
  ; on the 020 and 030), so it is written as a plain mnemonic rather than dc.w. It too runs only
  ; behind the runtime CPU-type check.




****************************************************************************************************
*                                             ROM TAG                                              *
****************************************************************************************************

ROMTag:
  dc.w         RTC_MATCHWORD
  dc.l         ROMTag
  dc.l         EndSkip
  dc.b         RTF_COLDSTART
  dc.b         VERSION
  dc.b         NT_UNKNOWN
  dc.b         100
  dc.l         Name
  dc.l         IDString
  dc.l         rtInit

Name:
  dc.b         "CDTV MMU & Cache Control",0
  CNOP 0,2
  
  COPYRIGHT

IDString:
  VSTRING

  CNOP 0,2

****************************************************************************************************
*                                             FUNCTION                                             *
****************************************************************************************************
rtInit:

  ; Determine the CPU family and configure cache inhibit for the 24-bit
  ; ($000000-$FFFFFF) address range accordingly:
  ;
  ;   genuine 68020   -> movec into the CACR to disable the instruction cache (SetCACR020)
  ;   genuine 68030   -> pmove into the on-chip MMU TT0 register  (SetTT0)
  ;   68040 / 68060   -> movec into the ITT0/DTT0 registers       (SetTTR040)
  ;   anything older  -> nothing to do, return immediately
  ;
  ; AFF_68030 is also set on the 68040/060, so it only means "030 or better". The 040/060 use a
  ; different MMU - the pmove-to-TT0 form does not exist there, they use movec with the transparent
  ; translation registers instead - so we test the 68040/68060 flags to pick the correct path.
  ; Likewise AFF_68020 is set on the 030/040/060 too, so we only treat the CPU as a genuine 68020
  ; (the CACR-only path) when AFF_68030 is clear.

  ; Note: we lazily assume an MMU is present. This could be a problem for systems with a
  ; 68EC030/68EC040/68EC060 or a full CPU with a mal/non-functional MMU, but it requires a lot of
  ; code to try to detect the MMU which is beyond the scope of this module's intended use.
  ; Power users with such a use case can drop this resident altogether and roll their own ROMs
  ; without it.

  MACHINE      MC68000

  IFND         release

  clr.w        $100                          ; trip debugger

  ENDC

  move.l       4.w,a6                        ; get ExecBase
  move.w       AttnFlags(a6),d0              ; get attention flags
  btst         #AFB_68030,d0                 ; is this at least an 030?
  bne.s        .cpu030                       ; yes -> 030/040/060 handling below
  btst         #AFB_68020,d0                 ; no - is it a genuine 68020?
  beq.s        .done                         ; no -> 68000/68010, nothing to do
  bsr.s        SetCACR020                    ; genuine 68020 -> disable I-cache via CACR
  bra.s        .done
.cpu030:
  and.w        #AFF_68040|AFF_68060,d0       ; is it really a 040 or 060?
  bne.s        .cpu040                       ; yes -> use the 040/060 TTR path
  bsr.s        SetTT0                        ; genuine 030 -> pmove into TT0
  bra.s        .done
.cpu040:
  bsr.s        SetTTR040                     ; 040/060 -> movec into ITT0/DTT0
.done:
  rts

****************************************************************************************************
*                                             FUNCTION                                             *
****************************************************************************************************
SetTT0:

  ; Configure the 68030 TT0 register to cache-inhibit the 24-bit address range ($000000-$FFFFFF).

  MACHINE 68030

  lea.l        TT0_(pc),a0                   ; the TT0 value
  lea.l        .super(pc),a5                 ; the supervisor fragment to run
  bra.s        CallSuper                     ; run it in supervisor mode, then return to caller

.super:
  pmove.l      (a0),tt0                      ; set the TT0 register
  rte

TT0_:
  dc.l         TTX

 CNOP 0,2

****************************************************************************************************
*                                             FUNCTION                                             *
****************************************************************************************************
SetTTR040:

  ; Configure the 68040/68060 transparent translation registers to cache-inhibit the 24-bit
  ; address range ($000000-$FFFFFF). ITT0 covers instruction accesses (the ROM window) and DTT0
  ; covers data accesses (the DMAC/TriPort I/O lines); both get the noncachable/serialized value
  ; TTR040. A CPUSHA (push + invalidate both caches) follows so that any lines cached before this
  ; ran are not left stale for the now cache-inhibited range, and a NOP synchronizes the pipeline
  ; and waits for the push to complete.

  MACHINE 68040

  move.l       #TTR040,d0                    ; the ITT0/DTT0 cache-inhibit value
  lea.l        .super(pc),a5                 ; the supervisor fragment to run
  bra.s        CallSuper                     ; run it in supervisor mode, then return to caller

.super:
  movec d0,itt0                              ; instruction transparent translate 0
  movec d0,dtt0                              ; data transparent translate 0
  cpusha bc                                  ; push + invalidate both caches
  nop                                        ; sync pipeline, wait for push to complete
  rte


****************************************************************************************************
*                                             FUNCTION                                             *
****************************************************************************************************
SetCACR020:

  ; Disable the 68020's on-chip instruction cache. The 68020 has only a 256-byte instruction cache,
  ; no data cache and no on-chip MMU, so there is no per-region cache-inhibit here (the global CACR
  ; is the only control). We write CACR020 (ClearI set, EnableI left clear), which invalidates any
  ; ROM lines cached so far and leaves the instruction cache off. The nonexistent data cache means
  ; the DMAC/TriPort I/O lines were never cached to begin with.

  move.l       #CACR020,d0                   ; ClearI, EnableI clear -> clear + disable I-cache
  lea.l        .super(pc),a5                 ; the supervisor fragment to run
  bra.s        CallSuper                     ; run it in supervisor mode, then return to caller

.super:
  movec        d0,cacr                       ; clear and disable the instruction cache
  rte



****************************************************************************************************
*                                             FUNCTION                                             *
****************************************************************************************************
CallSuper:

  ; Shared tail for the Set* routines above: run the rte-terminated supervisor fragment pointed
  ; to by a5 via exec/Supervisor, then rts back to whoever called the Set* routine. The fragment
  ; receives the caller's registers unchanged (a0 for SetTT0, d0 for SetTTR040), so each Set*
  ; routine loads its data before branching here.

  movem.l      a5/a6,-(sp)                   ; save regs
  move.l       4.w,a6                        ; get ExecBase
  jsr          _LVOSupervisor(a6)            ; run (a5) in supervisor mode
  movem.l      (sp)+,a5/a6                   ; restore regs
  rts


EndSkip:

  END
