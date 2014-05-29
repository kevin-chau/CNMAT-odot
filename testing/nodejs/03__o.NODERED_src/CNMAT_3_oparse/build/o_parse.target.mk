# This file is generated by gyp; do not edit.

TOOLSET := target
TARGET := o_parse
DEFS_Debug := \
	'-D_DARWIN_USE_64_BIT_INODE=1' \
	'-D_LARGEFILE_SOURCE' \
	'-D_FILE_OFFSET_BITS=64' \
	'-DBUILDING_NODE_EXTENSION' \
	'-DDEBUG' \
	'-D_DEBUG'

# Flags passed to all source files.
CFLAGS_Debug := \
	-O0 \
	-gdwarf-2 \
	-mmacosx-version-min=10.5 \
	-arch x86_64 \
	-Wall \
	-Wendif-labels \
	-W \
	-Wno-unused-parameter

# Flags passed to only C files.
CFLAGS_C_Debug := \
	-fno-strict-aliasing

# Flags passed to only C++ files.
CFLAGS_CC_Debug := \
	-fno-rtti \
	-fno-exceptions \
	-fno-threadsafe-statics \
	-fno-strict-aliasing

# Flags passed to only ObjC files.
CFLAGS_OBJC_Debug :=

# Flags passed to only ObjC++ files.
CFLAGS_OBJCC_Debug :=

INCS_Debug := \
	-I/var/folders/x5/fl_jxpmn1_n8f18n75j05my00000gn/T/.node-gyp/0.10.28/src \
	-I/var/folders/x5/fl_jxpmn1_n8f18n75j05my00000gn/T/.node-gyp/0.10.28/deps/uv/include \
	-I/var/folders/x5/fl_jxpmn1_n8f18n75j05my00000gn/T/.node-gyp/0.10.28/deps/v8/include \
	-I$(srcdir)/include

DEFS_Release := \
	'-D_DARWIN_USE_64_BIT_INODE=1' \
	'-D_LARGEFILE_SOURCE' \
	'-D_FILE_OFFSET_BITS=64' \
	'-DBUILDING_NODE_EXTENSION'

# Flags passed to all source files.
CFLAGS_Release := \
	-Os \
	-gdwarf-2 \
	-mmacosx-version-min=10.5 \
	-arch x86_64 \
	-Wall \
	-Wendif-labels \
	-W \
	-Wno-unused-parameter

# Flags passed to only C files.
CFLAGS_C_Release := \
	-fno-strict-aliasing

# Flags passed to only C++ files.
CFLAGS_CC_Release := \
	-fno-rtti \
	-fno-exceptions \
	-fno-threadsafe-statics \
	-fno-strict-aliasing

# Flags passed to only ObjC files.
CFLAGS_OBJC_Release :=

# Flags passed to only ObjC++ files.
CFLAGS_OBJCC_Release :=

INCS_Release := \
	-I/var/folders/x5/fl_jxpmn1_n8f18n75j05my00000gn/T/.node-gyp/0.10.28/src \
	-I/var/folders/x5/fl_jxpmn1_n8f18n75j05my00000gn/T/.node-gyp/0.10.28/deps/uv/include \
	-I/var/folders/x5/fl_jxpmn1_n8f18n75j05my00000gn/T/.node-gyp/0.10.28/deps/v8/include \
	-I$(srcdir)/include

OBJS := \
	$(obj).target/$(TARGET)/o_parse.o

# Add to the list of files we specially track dependencies for.
all_deps += $(OBJS)

# CFLAGS et al overrides must be target-local.
# See "Target-specific Variable Values" in the GNU Make manual.
$(OBJS): TOOLSET := $(TOOLSET)
$(OBJS): GYP_CFLAGS := $(DEFS_$(BUILDTYPE)) $(INCS_$(BUILDTYPE))  $(CFLAGS_$(BUILDTYPE)) $(CFLAGS_C_$(BUILDTYPE))
$(OBJS): GYP_CXXFLAGS := $(DEFS_$(BUILDTYPE)) $(INCS_$(BUILDTYPE))  $(CFLAGS_$(BUILDTYPE)) $(CFLAGS_CC_$(BUILDTYPE))
$(OBJS): GYP_OBJCFLAGS := $(DEFS_$(BUILDTYPE)) $(INCS_$(BUILDTYPE))  $(CFLAGS_$(BUILDTYPE)) $(CFLAGS_C_$(BUILDTYPE)) $(CFLAGS_OBJC_$(BUILDTYPE))
$(OBJS): GYP_OBJCXXFLAGS := $(DEFS_$(BUILDTYPE)) $(INCS_$(BUILDTYPE))  $(CFLAGS_$(BUILDTYPE)) $(CFLAGS_CC_$(BUILDTYPE)) $(CFLAGS_OBJCC_$(BUILDTYPE))

# Suffix rules, putting all outputs into $(obj).

$(obj).$(TOOLSET)/$(TARGET)/%.o: $(srcdir)/%.cc FORCE_DO_CMD
	@$(call do_cmd,cxx,1)

# Try building from generated source, too.

$(obj).$(TOOLSET)/$(TARGET)/%.o: $(obj).$(TOOLSET)/%.cc FORCE_DO_CMD
	@$(call do_cmd,cxx,1)

$(obj).$(TOOLSET)/$(TARGET)/%.o: $(obj)/%.cc FORCE_DO_CMD
	@$(call do_cmd,cxx,1)

# End of this set of suffix rules
### Rules for final target.
LDFLAGS_Debug := \
	-Wl,-search_paths_first \
	-mmacosx-version-min=10.5 \
	-arch x86_64 \
	-L$(builddir)

LIBTOOLFLAGS_Debug := \
	-Wl,-search_paths_first

LDFLAGS_Release := \
	-Wl,-search_paths_first \
	-mmacosx-version-min=10.5 \
	-arch x86_64 \
	-L$(builddir)

LIBTOOLFLAGS_Release := \
	-Wl,-search_paths_first

LIBS := \
	-undefined dynamic_lookup \
	/usr/local/lib/libo.a

$(builddir)/o_parse.node: GYP_LDFLAGS := $(LDFLAGS_$(BUILDTYPE))
$(builddir)/o_parse.node: LIBS := $(LIBS)
$(builddir)/o_parse.node: GYP_LIBTOOLFLAGS := $(LIBTOOLFLAGS_$(BUILDTYPE))
$(builddir)/o_parse.node: TOOLSET := $(TOOLSET)
$(builddir)/o_parse.node: $(OBJS) FORCE_DO_CMD
	$(call do_cmd,solink_module)

all_deps += $(builddir)/o_parse.node
# Add target alias
.PHONY: o_parse
o_parse: $(builddir)/o_parse.node

# Short alias for building this executable.
.PHONY: o_parse.node
o_parse.node: $(builddir)/o_parse.node

# Add executable to "all" target.
.PHONY: all
all: $(builddir)/o_parse.node

