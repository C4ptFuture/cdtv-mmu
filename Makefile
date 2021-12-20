#
#   Note:
#	Set VERSION and REVISION numbers in VERSION file. The date and version string for the
#   resident module will be automatically generated.
#
#    Build mmu:
#		ENVIRONMENT=develop make mmu
#
PROJECT=mmu
VASM=vasmm68k_mot
VLINK=vlink -s
INCLUDE=include_i
SRC=src/$(PROJECT)
BUILD=build/$(PROJECT)
LIB=-Llib
BUILDSUFFIX=$(VERSION).$(REVISION)-$(ENVIRONMENT)
AFLAGS=-DVERSION=$(VERSION) -DREVISION=$(REVISION) -m68030 -no-opt -kick1hunks -Fhunk
DATESTRING := $(shell date +'%-d.%-m.%y')
VERSION = $(shell grep VERSION VERSION|cut -d= -f2)
REVISION = $(shell grep REVISION VERSION|cut -d= -f2)

.PHONY: clean deps check-env

mmu: deps
	$(VASM) -DCDTV $(AFLAGS) -I$(INCLUDE) $(SRC)/mmu.asm -o $(BUILD)/CDTV-mmu-$(BUILDSUFFIX).o
	$(VASM) -DA570 $(AFLAGS) -I$(INCLUDE) $(SRC)/mmu.asm -o $(BUILD)/A570-mmu-$(BUILDSUFFIX).o
	$(VASM) -DA690 $(AFLAGS) -I$(INCLUDE) $(SRC)/mmu.asm -o $(BUILD)/A690-mmu-$(BUILDSUFFIX).o
	$(VLINK) -bamigahunk ${LIB} -lamiga -Bstatic $(BUILD)/CDTV-mmu-$(BUILDSUFFIX).o -o $(BUILD)/CDTV-mmu-$(BUILDSUFFIX).ld
	$(VLINK) -bamigahunk ${LIB} -lamiga -Bstatic $(BUILD)/A570-mmu-$(BUILDSUFFIX).o -o $(BUILD)/A570-mmu-$(BUILDSUFFIX).ld
	$(VLINK) -bamigahunk ${LIB} -lamiga -Bstatic $(BUILD)/A690-mmu-$(BUILDSUFFIX).o -o $(BUILD)/A690-mmu-$(BUILDSUFFIX).ld

# build dependencies
deps: check-env createrev

# make sure all required env vars are set
check-env:
ifndef VERSION
	$(error VERSION is undefined)
endif
ifndef REVISION
	$(error REVISION is undefined)
endif
ifndef ENVIRONMENT
	$(error ENVIRONMENT is undefined)
endif

# creates the version string include according to Commodore standard
createrev:
	echo "VSTRING	MACRO" > $(SRC)/rev.i
	echo "  dc.b   '$(PROJECT) $(VERSION).$(REVISION) ($(DATESTRING))',13,10,0" >> $(SRC)/rev.i
	echo "  CNOP   0,2" >> $(SRC)/rev.i
	echo "  ENDM" >> $(SRC)/rev.i

# delete all build artifacts
clean:
	find $(BUILD) -name "*.o" -exec rm {} \;
	find $(BUILD) -name "*.ld" -exec rm {} \;
