# CDTV MMU Cache Inhibit

This repo contains the source code to the CDTV MMU cache inhibit resident module that is part of the CDTV OS 2.36 update.

## Background
This resident module configures CPU caches at startup for CDTV players upgraded with a 68020, 68030, 68040 or 68060, protecting the CDTV OS ROM and the DMAC and TriPort I/O registers from inappropriate caching.

On a 68020 it clears and disables the instruction cache; on a 68030, 68040 or 68060 it uses transparent translation registers to inhibit caching across the entire 24-bit address range ($000000–$FFFFFF), leaving 32-bit Fast RAM outside that range cacheable. No MMU tables are needed, and tools such as mmu.library can provide finer control after boot. 

This module alone does not resolve CD-ROM drive issues with accelerators: it also requires the cdtv.device fixes included in CDTV OS 2.35 and 2.36. Written in 68k assembly by CDTV Land. The source is released under GPLv3.
