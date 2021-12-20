           ************************************************************************
           ***                                                                  ***
           ***             -= COMMODORE CDTV ROM OPERATING SYSTEM =-            ***
           ***                                                                  ***
           ************************************************************************
           ***                                                                  ***
           ***     CDTV MMU                                                     ***
           ***     Copyright (c) 2021 CDTV Land. Published under GPLv3.         ***
           ***     Written by Captain Future                                    ***
           ***                                                                  ***
           ************************************************************************


  INCLUDE      exec/funcdef.i
  INCLUDE      exec/exec_lib.i
  INCLUDE      exec/execbase.i
  INCLUDE      exec/resident.i
  INCLUDE      rev.i
  INCLUDE      defs.i


  ; This resident module is to be included with CDTV OS ROM builds to support CDTV players
  ; with a 68030 installed. It disables CPU caching on startup which is known to cause
  ; data corruption when reading the CDTV OS ROM addresses on Viper 530 ($F00000-$F7FFFF). It also
  ; prevents caching of the DMAC's and TriPort chip's I/O lines, which the 68030 will
  ; happily do unless instructed otherwise. Note: This module on its own is not enough
  ; to fix CD-ROM drive issues with 68030 systems! The cdtv.device driver requires fixing
  ; as well in the way it talks to the DMAC. This fix is implemented in my custom 
  ; CDTV OS ROM v 2.35, but as this is closed source, I am sadly not able to publish the
  ; source code.

  ; DMAC Autoconfig I/O cache inhibit

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


;************************************************************************************************
;*                                           ROM TAG                                            *
;************************************************************************************************

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
  dc.b         "CDTV MMU cache-inhibit",0
  COPYRIGHT

IDString:
  VSTRING

  CNOP 0,2

;************************************************************************************************
;*                                           FUNCTION                                           *
;************************************************************************************************
rtInit:

  ; Check for presence of a 68030. If no 68030 is found we do nothing and return
  ; immediately, otherwise we go ahead and configure cache inhibit using the TT0
  ; register of the MMU.

  ; Note: we lazily assume an MMU is present. This could be a problem for systems with
  ; a 68EC030 or a 68030 with mal/non-functional MMU, but it requires a lot of
  ; code to try to detect the MMU which is beyond the scope of this module's intended use.
  ; Power users with such a use case can drop this resident altogether and roll their own ROMs
  ; without it.

  clr.w        $100                          ; trip debugger
  move.l       4.w,a6                        ; get ExecBase
  move.w       AttnFlags(a6),d0              ; get attention flags
  and.w        #AFF_68030,d0                 ; is this an 030?
  beq.s        .done                         ; nope
  bsr.s        SetTT0                        ; yep, do our thing
.done:
  rts

;************************************************************************************************
;*                                           FUNCTION                                           *
;************************************************************************************************
SetTT0:

  ; Configure the TT0 register to enable transparent translation and cache inhibit for
  ; the 24-bit address range ($000000-$FFFFFF).

  lea.l        TT0_(pc),a0                   ; the TT0 value

  movem.l      a5/a6,-(sp)                   ; save regs
  move.l       4.w,a6                        ; get ExecBase
  lea.l        .super,a5                     ; get start of supervisor code
  jsr          _LVOSupervisor(a6)            ; run supervisor code
  movem.l      (sp)+,a5/a6                   ; restore regs
  rts

.super:
  pmove.l      (a0),tt0                      ; set the TT0 register
  rte

TT0_:
  dc.l         TTX

 CNOP 0,2

EndSkip:

  END
