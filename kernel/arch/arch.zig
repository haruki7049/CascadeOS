// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz>

//! Defines the interface of the architecture specific code.

const std = @import("std");
const core = @import("core");
const kernel = @import("kernel");

const current = switch (@import("cascade_target").arch) {
    .x64 => @import("x64/interface.zig"),
};

/// Architecture specific per-cpu information.
pub const ArchCpu = current.ArchCpu;

/// Get the current CPU.
///
/// Assumes that `init.loadCpu()` has been called on the currently running CPU.
///
/// It is the callers responsibility to ensure that the current thread is not re-scheduled on to another CPU.
pub inline fn rawGetCpu() *kernel.Cpu {
    checkSupport(current, "getCpu", fn () *kernel.Cpu);

    return current.getCpu();
}

/// Issues an architecture specific hint to the CPU that we are spinning in a loop.
pub inline fn spinLoopHint() void {
    checkSupport(current, "spinLoopHint", fn () void);

    current.spinLoopHint();
}

/// Halts the current processor
pub inline fn halt() void {
    checkSupport(current, "halt", fn () void);

    current.halt();
}

/// Functionality that is used during kernel init only.
pub const init = struct {
    /// Attempt to set up some form of early output.
    pub inline fn setupEarlyOutput() void {
        checkSupport(current.init, "setupEarlyOutput", fn () void);

        current.init.setupEarlyOutput();
    }

    /// Acquire a writer for the early output setup by `setupEarlyOutput`.
    pub inline fn getEarlyOutput() ?std.io.AnyWriter {
        checkSupport(current.init, "getEarlyOutput", fn () ?current.init.EarlyOutputWriter);

        return if (current.init.getEarlyOutput()) |writer| writer.any() else null;
    }

    /// Ensure that any exceptions/faults that occur are handled.
    pub inline fn initInterrupts() void {
        checkSupport(current.init, "initInterrupts", fn () void);

        current.init.initInterrupts();
    }

    /// Prepares the provided `Cpu` for the bootstrap processor.
    pub inline fn prepareBootstrapCpu(
        bootstrap_cpu: *kernel.Cpu,
    ) void {
        checkSupport(current.init, "prepareBootstrapCpu", fn (*kernel.Cpu) void);

        current.init.prepareBootstrapCpu(bootstrap_cpu);
    }

    /// Load the provided `Cpu` as the current CPU.
    pub inline fn loadCpu(cpu: *kernel.Cpu) void {
        checkSupport(current.init, "loadCpu", fn (*kernel.Cpu) void);

        current.init.loadCpu(cpu);
    }

    /// Capture any system information that is required for the architecture.
    ///
    /// For example, on x64 this should capture the CPUID information.
    pub inline fn captureSystemInformation() !void {
        checkSupport(current.init, "captureSystemInformation", fn () anyerror!void);

        return current.init.captureSystemInformation();
    }
};

pub const interrupts = struct {
    /// Disable interrupts and put the CPU to sleep.
    pub inline fn disableInterruptsAndHalt() noreturn {
        checkSupport(current.interrupts, "disableInterruptsAndHalt", fn () noreturn);

        current.interrupts.disableInterruptsAndHalt();
    }

    /// Are interrupts enabled?
    pub inline fn interruptsEnabled() bool {
        checkSupport(current.interrupts, "interruptsEnabled", fn () bool);

        return current.interrupts.interruptsEnabled();
    }

    /// Disable interrupts.
    pub inline fn disableInterrupts() void {
        checkSupport(current.interrupts, "disableInterrupts", fn () void);

        current.interrupts.disableInterrupts();
    }

    /// Enable interrupts.
    pub inline fn enableInterrupts() void {
        checkSupport(current.interrupts, "enableInterrupts", fn () void);

        current.interrupts.enableInterrupts();
    }
};

pub const paging = struct {
    /// The standard page size for the architecture.
    pub const standard_page_size: core.Size = current.paging.standard_page_size;

    /// The virtual address of the higher half.
    pub const higher_half: core.VirtualAddress = current.paging.higher_half;

    /// All the page sizes supported by the architecture in order of smallest to largest.
    pub const all_page_sizes: []const core.Size = current.paging.all_page_sizes;

    /// The page table type for the architecture.
    pub const PageTable: type = current.paging.PageTable;

    /// Switches to the given page table.
    pub inline fn switchToPageTable(page_table_address: core.PhysicalAddress) void {
        checkSupport(current.paging, "switchToPageTable", fn (core.PhysicalAddress) void);

        current.paging.switchToPageTable(page_table_address);
    }

    pub const MapError = error{
        AlreadyMapped,

        /// This is used to surface errors from the underlying paging implementation that are architecture specific.
        MappingNotValid,
    } || kernel.pmm.AllocateError;

    pub const init = struct {
        /// Maps the `virtual_range` to the `physical_range` with mapping type given by `map_type`.
        ///
        /// Caller must ensure:
        ///  - the virtual range address and size are aligned to the standard page size
        ///  - the physical range address and size are aligned to the standard page size
        ///  - the virtual range size is equal to the physical range size
        ///  - the virtual range is not already mapped
        ///
        /// This function:
        ///  - uses all page sizes available to the architecture
        ///  - does not flush the TLB
        ///  - on error is not required to roll back any modifications to the page tables
        pub inline fn mapToPhysicalRangeAllPageSizes(
            page_table: *PageTable,
            virtual_range: core.VirtualRange,
            physical_range: core.PhysicalRange,
            map_type: kernel.vmm.MapType,
        ) MapError!void {
            checkSupport(current.paging.init, "mapToPhysicalRangeAllPageSizes", fn (
                *PageTable,
                core.VirtualRange,
                core.PhysicalRange,
                kernel.vmm.MapType,
            ) MapError!void);

            return current.paging.init.mapToPhysicalRangeAllPageSizes(page_table, virtual_range, physical_range, map_type);
        }
    };
};

pub const scheduling = struct {
    /// Switches to the provided stack and returns.
    ///
    /// It is the caller's responsibility to ensure the stack is valid, with a return address.
    pub inline fn changeStackAndReturn(
        stack_pointer: core.VirtualAddress,
    ) noreturn {
        checkSupport(current.scheduling, "changeStackAndReturn", fn (core.VirtualAddress) noreturn);

        try current.scheduling.changeStackAndReturn(stack_pointer);
    }
};

/// Checks if the current architecture implements the given function.
///
/// If it is unimplemented, this function will panic at runtime.
///
/// If it is implemented, this function will validate it's signature at compile time and do nothing at runtime.
inline fn checkSupport(comptime Container: type, comptime name: []const u8, comptime TargetT: type) void {
    if (comptime name.len == 0) @compileError("zero-length name");

    if (comptime !@hasDecl(Container, name)) {
        // core.panic("`" ++ @tagName(@import("cascade_target").arch) ++ "` does not implement `" ++ name ++ "`");
        @compileError("`" ++ @tagName(@import("cascade_target").arch) ++ "` does not implement `" ++ name ++ "`");
    }

    const DeclT = @TypeOf(@field(Container, name));

    const mismatch_type_msg =
        comptime "Expected `" ++ name ++ "` to be compatible with `" ++ @typeName(TargetT) ++
        "`, but it is `" ++ @typeName(DeclT) ++ "`";

    const decl_type_info = @typeInfo(DeclT).Fn;
    const target_type_info = @typeInfo(TargetT).Fn;

    if (decl_type_info.return_type != target_type_info.return_type) {
        const DeclReturnT = decl_type_info.return_type.?;
        const TargetReturnT = target_type_info.return_type.?;

        const target_return_type_info = @typeInfo(TargetReturnT);
        if (target_return_type_info != .ErrorUnion) @compileError(mismatch_type_msg);

        const target_return_error_union = target_return_type_info.ErrorUnion;
        if (target_return_error_union.error_set != anyerror) @compileError(mismatch_type_msg);

        // the target return type is an error union with anyerror, so the decl return type just needs to be an
        // error union with the right child type.

        const decl_return_type_info = @typeInfo(DeclReturnT);
        if (decl_return_type_info != .ErrorUnion) @compileError(mismatch_type_msg);

        const decl_return_error_union = decl_return_type_info.ErrorUnion;
        if (decl_return_error_union.payload != target_return_error_union.payload) @compileError(mismatch_type_msg);
    }

    if (decl_type_info.params.len != target_type_info.params.len) @compileError(mismatch_type_msg);

    inline for (decl_type_info.params, target_type_info.params) |decl_param, target_param| {
        if (decl_param.type != target_param.type) @compileError(mismatch_type_msg);
    }
}
