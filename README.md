# CDTV MMU Cache Inhibit

This repo contains the source code to the CDTV MMU cache inhibit resident module that is part of the CDTV OS 2.35 update.

## Background
This resident module is to be included with CDTV OS ROM builds to support CDTV players with a 68030 installed. It disables CPU caching on startup which is known to cause data corruption when reading the CDTV OS ROM addresses on Viper 530 (F00000-F7FFFF). It also prevents caching of the DMAC's and TriPort chip's I/O lines, which the 68030 will happily do unless instructed otherwise. 

Note: This module on its own is not enough to fix CD-ROM drive issues with 68030 systems! The cdtv.device driver requires fixing as well in the way it talks to the DMAC. This fix is implemented in my custom CDTV OS ROM v 2.35, but as this is closed source, I am sadly not able to publish the source code.

## How to build

You need vasm and the Amiga NDK. To build the resident module issue the following command:

```sh
ENVIRONMENT=release make mmu    
```
