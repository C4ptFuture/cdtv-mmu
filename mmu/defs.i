COPYRIGHT MACRO
  dc.b    "Copyright (c) 2021, 2026 CDTV Land. ",0
  dc.b    "Published under GPLv3 license. ",0
  dc.b    "Written by Captain Future, CDTV Land.",$a,$d,0  
  ENDM


; Define the value that needs to written to TT0 on a 68030

TTX equ $00008507


; Define the value written to ITT0/DTT0 on a 68040/68060. The 040/060 TTR format
; differs from the 030 TT register, so this needs its own constant:
;   E   (bit 15)    = 1  -> transparent translation enabled
;   S   (bits 14-13)= 10 -> ignore FC2, match both user and supervisor accesses
;   CM  (bits 6-5)  = 10 -> noncachable, serialized (precise) - correct for I/O
;   Base/Mask (31-16)= 0 -> matches A31-A24 = 0, i.e. the low 16 MB ($000000-$FFFFFF)
; The 68040 and 68060 share this TTR layout, so the same value is used for both.

TTR040 equ $0000C040


; Define the value written to CACR on a 68020 to disable its cache. The 68020 has only a 256-byte
; on-chip instruction cache and no data cache, so there is no per-region cache-inhibit mechanism and
; no data-cache bits - the global CACR is the only control:
;   EnableI (bit 0) = 0 -> instruction cache disabled
;   ClearI  (bit 3) = 1 -> clear (invalidate) the whole instruction cache
; Writing ClearI with EnableI left clear flushes any ROM lines cached so far and leaves the cache
; off. CACRF_ClearI comes from exec/execbase.i (included before this file).

CACR020 equ CACRF_ClearI


; NDK 3.9 only seems to define the bits up to AFF_68040, so we define the 68060 flag ourselves
; if it is missing.

  IFND AFF_68060
AFF_68060    equ  $0080
  ENDC
