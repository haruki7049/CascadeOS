// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz>

const core = @import("core");
const kernel = @import("kernel");
const std = @import("std");

const current = switch (kernel.info.arch) {
    .x86_64 => @import("x86_64/x86_64.zig"),
    .aarch64 => @import("aarch64/aarch64.zig"),
};

/// Issues an architecture specific hint to the CPU that we are spinning in a loop.
pub fn spinLoopHint() callconv(core.inline_in_non_debug_calling_convention) void {
    checkSupport(current, "spinLoopHint", fn () void);

    current.spinLoopHint();
}

/// Architecture specific processor information.
pub const ArchProcessor = current.ArchProcessor;

/// Get the current processor.
///
/// Panics if interrupts are enabled.
pub fn getProcessor() callconv(core.inline_in_non_debug_calling_convention) *kernel.Processor {
    checkSupport(current, "getProcessor", fn () *kernel.Processor);

    core.debugAssert(!interrupts.interruptsEnabled());

    return current.getProcessor();
}

/// Get the current processor, supports returning null for early boot before the processor is set.
///
/// Panics if interrupts are enabled.
pub fn earlyGetProcessor() callconv(core.inline_in_non_debug_calling_convention) ?*kernel.Processor {
    checkSupport(current, "earlyGetProcessor", fn () ?*kernel.Processor);

    core.debugAssert(!interrupts.interruptsEnabled());

    return current.earlyGetProcessor();
}

/// Halts the current processor
pub fn halt() callconv(core.inline_in_non_debug_calling_convention) void {
    checkSupport(current, "halt", fn () void);

    current.halt();
}

/// Functionality that is intended to be used during kernel init only.
pub const init = struct {
    /// Prepares the provided kernel.Processor for the bootstrap processor.
    pub fn prepareBootstrapProcessor(
        bootstrap_processor: *kernel.Processor,
    ) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "prepareBootstrapProcessor", fn (*kernel.Processor) void);

        current.init.prepareBootstrapProcessor(bootstrap_processor);
    }

    /// Prepares the provided kernel.Processor for use.
    ///
    /// **WARNING**: This function will panic if the processor cannot be prepared.
    pub fn prepareProcessor(
        processor: *kernel.Processor,
        processor_descriptor: kernel.boot.ProcessorDescriptor,
    ) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "prepareProcessor", fn (*kernel.Processor, kernel.boot.ProcessorDescriptor) void);

        current.init.prepareProcessor(processor, processor_descriptor);
    }

    /// Performs any actions required to load the provided kernel.Processor for the current execution context.
    pub fn loadProcessor(processor: *kernel.Processor) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "loadProcessor", fn (*kernel.Processor) void);

        current.init.loadProcessor(processor);
    }

    /// Attempt to set up some form of early output.
    pub fn setupEarlyOutput() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "setupEarlyOutput", fn () void);

        current.init.setupEarlyOutput();
    }

    pub const EarlyOutput = struct {
        writer: current.init.EarlyOutputWriter,
        held: kernel.SpinLock.Held,

        pub fn deinit(self: EarlyOutput) callconv(core.inline_in_non_debug_calling_convention) void {
            self.held.unlock();
        }

        pub var lock: kernel.SpinLock = .{};
    };

    pub fn getEarlyOutputNoLock() callconv(core.inline_in_non_debug_calling_convention) ?current.init.EarlyOutputWriter { // TODO: Put in init_code section
        checkSupport(current.init, "getEarlyOutputWriter", fn () ?current.init.EarlyOutputWriter);

        return current.init.getEarlyOutputWriter();
    }

    /// Acquire a `std.io.Writer` for the early output setup by `setupEarlyOutput`.
    pub fn getEarlyOutput() ?EarlyOutput { // TODO: Put in init_code section
        checkSupport(current.init, "getEarlyOutputWriter", fn () ?current.init.EarlyOutputWriter);

        if (current.init.getEarlyOutputWriter()) |early_output_writer| {
            const held = EarlyOutput.lock.lock();

            return .{
                .writer = early_output_writer,
                .held = held,
            };
        }

        return null;
    }

    /// Initialize the architecture specific registers and structures into the state required for early kernel init.
    ///
    /// One of the requirements of this function is to ensure that any exceptions/faults that occur are correctly handled.
    ///
    /// For example, on x86_64 after this function has completed a GDT, TSS and an IDT with a simple handler on every vector
    /// should be in place.
    pub fn earlyArchInitialization() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "earlyArchInitialization", fn () void);

        current.init.earlyArchInitialization();
    }

    /// Capture any system information that is required for the architecture.
    ///
    /// For example, on x86_64 this should capture the CPUID information.
    pub fn captureSystemInformation() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "captureSystemInformation", fn () void);

        current.init.captureSystemInformation();
    }

    /// Configure any global system features.
    pub fn configureGlobalSystemFeatures() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "configureGlobalSystemFeatures", fn () void);

        current.init.configureGlobalSystemFeatures();
    }

    /// Configure any processor local system features.
    pub fn configureSystemFeaturesForCurrentProcessor(processor: *kernel.Processor) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "configureSystemFeaturesForCurrentProcessor", fn (*kernel.Processor) void);

        current.init.configureSystemFeaturesForCurrentProcessor(processor);
    }

    /// Register any architectural time sources.
    ///
    /// For example, on x86_64 this should register the TSC, HPEC, PIT, etc.
    pub fn registerArchitecturalTimeSources() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "registerArchitecturalTimeSources", fn () void);

        current.init.registerArchitecturalTimeSources();
    }

    /// Initialize the local interrupt controller for the provided processor.
    ///
    /// For example, on x86_64 this should initialize the APIC.
    pub fn initLocalInterruptController(processor: *kernel.Processor) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.init, "initLocalInterruptController", fn (*kernel.Processor) void);

        current.init.initLocalInterruptController(processor);
    }
};

pub const interrupts = struct {
    pub fn panicInterruptOtherCores() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.interrupts, "panicInterruptOtherCores", fn () void);

        current.interrupts.panicInterruptOtherCores();
    }

    /// Disable interrupts and put the CPU to sleep.
    pub fn disableInterruptsAndHalt() callconv(core.inline_in_non_debug_calling_convention) noreturn {
        checkSupport(current.interrupts, "disableInterruptsAndHalt", fn () noreturn);

        current.interrupts.disableInterruptsAndHalt();
    }

    /// Disable interrupts.
    pub fn disableInterrupts() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.interrupts, "disableInterrupts", fn () void);

        current.interrupts.disableInterrupts();
    }

    /// Enable interrupts.
    pub fn enableInterrupts() callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.interrupts, "enableInterrupts", fn () void);

        current.interrupts.enableInterrupts();
    }

    /// Are interrupts enabled?
    pub fn interruptsEnabled() callconv(core.inline_in_non_debug_calling_convention) bool {
        checkSupport(current.interrupts, "interruptsEnabled", fn () bool);

        return current.interrupts.interruptsEnabled();
    }

    pub fn setTaskPriority(priority: kernel.scheduler.Priority) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.interrupts, "setTaskPriority", fn (kernel.scheduler.Priority) void);

        current.interrupts.setTaskPriority(priority);
    }

    pub const InterruptGuard = struct {
        enable_interrupts: bool,

        pub fn release(self: InterruptGuard) callconv(core.inline_in_non_debug_calling_convention) void {
            if (self.enable_interrupts) enableInterrupts();
        }
    };

    pub fn interruptGuard() InterruptGuard {
        const interrupts_enabled = interruptsEnabled();

        if (interrupts_enabled) disableInterrupts();

        return .{
            .enable_interrupts = interrupts_enabled,
        };
    }
};

pub const paging = struct {
    /// The standard page size for the architecture.
    pub const standard_page_size: core.Size = current.paging.standard_page_size;

    /// Returns the largest page size supported by the architecture.
    pub fn largestPageSize() callconv(core.inline_in_non_debug_calling_convention) core.Size {
        checkSupport(current.paging, "largestPageSize", fn () core.Size);

        return current.paging.largestPageSize();
    }

    /// The virtual address of the higher half.
    pub const higher_half: kernel.VirtualAddress = current.paging.higher_half;

    /// The page table type for the architecture.
    pub const PageTable: type = current.paging.PageTable;

    /// Allocates a new page table.
    pub fn allocatePageTable() callconv(core.inline_in_non_debug_calling_convention) error{PageAllocationFailed}!*PageTable {
        checkSupport(current.paging, "allocatePageTable", fn () error{PageAllocationFailed}!*PageTable);

        return current.paging.allocatePageTable();
    }

    pub const MapError = error{
        AlreadyMapped,
        AllocationFailed,
        Unexpected,
    };

    /// Maps the `virtual_range` to the `physical_range` with mapping type given by `map_type`.
    ///
    /// This function will only use the architecture's `standard_page_size`.
    pub fn mapToPhysicalRange(
        page_table: *PageTable,
        virtual_range: kernel.VirtualRange,
        physical_range: kernel.PhysicalRange,
        map_type: kernel.memory.virtual.MapType,
    ) callconv(core.inline_in_non_debug_calling_convention) MapError!void {
        checkSupport(current.paging, "mapToPhysicalRange", fn (
            *PageTable,
            kernel.VirtualRange,
            kernel.PhysicalRange,
            kernel.memory.virtual.MapType,
        ) MapError!void);

        return current.paging.mapToPhysicalRange(page_table, virtual_range, physical_range, map_type);
    }

    /// Unmaps the `virtual_range`.
    ///
    /// This function assumes only the architecture's `standard_page_size` is used for the mapping.
    pub fn unmap(
        page_table: *PageTable,
        virtual_range: kernel.VirtualRange,
    ) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.paging, "unmap", fn (*PageTable, kernel.VirtualRange) void);

        current.paging.unmap(page_table, virtual_range);
    }

    /// Maps the `virtual_range` to the `physical_range` with mapping type given by `map_type`.
    ///
    /// This function is allowed to use all page sizes available to the architecture.
    pub fn mapToPhysicalRangeAllPageSizes(
        page_table: *PageTable,
        virtual_range: kernel.VirtualRange,
        physical_range: kernel.PhysicalRange,
        map_type: kernel.memory.virtual.MapType,
    ) callconv(core.inline_in_non_debug_calling_convention) MapError!void {
        checkSupport(current.paging, "mapToPhysicalRangeAllPageSizes", fn (
            *PageTable,
            kernel.VirtualRange,
            kernel.PhysicalRange,
            kernel.memory.virtual.MapType,
        ) MapError!void);

        return current.paging.mapToPhysicalRangeAllPageSizes(page_table, virtual_range, physical_range, map_type);
    }

    /// Switches to the given page table.
    pub fn switchToPageTable(page_table: *const PageTable) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.paging, "switchToPageTable", fn (*const PageTable) void);

        current.paging.switchToPageTable(page_table);
    }

    pub const init = struct {
        /// This function is only called during kernel init, it is required to:
        ///   1. search the higher half of the *top level* of the given page table for a free entry
        ///   2. allocate a backing frame for it
        ///   3. map the free entry to the fresh backing frame and ensure it is zeroed
        ///   4. return the `kernel.VirtualRange` representing the entire virtual range that entry covers
        pub fn getTopLevelRangeAndFillFirstLevel(
            page_table: *PageTable,
        ) callconv(core.inline_in_non_debug_calling_convention) MapError!kernel.VirtualRange {
            checkSupport(current.paging.init, "getTopLevelRangeAndFillFirstLevel", fn (*PageTable) MapError!kernel.VirtualRange);

            return current.paging.init.getTopLevelRangeAndFillFirstLevel(page_table);
        }
    };
};

pub const scheduling = struct {
    /// Switches to the provided stack and returns.
    ///
    /// It is the caller's responsibility to ensure the stack is valid, with a return address.
    pub fn changeStackAndReturn(
        stack_pointer: kernel.VirtualAddress,
    ) callconv(core.inline_in_non_debug_calling_convention) noreturn {
        checkSupport(current.scheduling, "changeStackAndReturn", fn (kernel.VirtualAddress) noreturn);

        try current.scheduling.changeStackAndReturn(stack_pointer);
    }

    pub fn switchToThreadFromIdle(
        processor: *kernel.Processor,
        thread: *kernel.scheduler.Thread,
    ) callconv(core.inline_in_non_debug_calling_convention) noreturn {
        checkSupport(current.scheduling, "switchToThreadFromIdle", fn (*kernel.Processor, *kernel.scheduler.Thread) noreturn);

        current.scheduling.switchToThreadFromIdle(processor, thread);
    }

    pub fn switchToThreadFromThread(
        processor: *kernel.Processor,
        old_thread: *kernel.scheduler.Thread,
        new_thread: *kernel.scheduler.Thread,
    ) callconv(core.inline_in_non_debug_calling_convention) void {
        checkSupport(current.scheduling, "switchToThreadFromThread", fn (*kernel.Processor, *kernel.scheduler.Thread, *kernel.scheduler.Thread) void);

        current.scheduling.switchToThreadFromThread(processor, old_thread, new_thread);
    }

    /// It is the caller's responsibility to ensure the stack is valid, with a return address.
    pub fn switchToIdle(
        processor: *kernel.Processor,
        stack_pointer: kernel.VirtualAddress,
        opt_old_thread: ?*kernel.scheduler.Thread,
    ) callconv(core.inline_in_non_debug_calling_convention) noreturn {
        checkSupport(current.scheduling, "switchToIdle", fn (*kernel.Processor, kernel.VirtualAddress, ?*kernel.scheduler.Thread) noreturn);

        current.scheduling.switchToIdle(processor, stack_pointer, opt_old_thread);
    }

    pub fn prepareStackForNewThread(
        thread: *kernel.scheduler.Thread,
        context: u64,
        target_function: *const fn (thread: *kernel.scheduler.Thread, context: u64) noreturn,
    ) callconv(core.inline_in_non_debug_calling_convention) error{StackOverflow}!void {
        checkSupport(current.scheduling, "prepareStackForNewThread", fn (
            *kernel.scheduler.Thread,
            u64,
            *const fn (thread: *kernel.scheduler.Thread, context: u64) noreturn,
        ) error{StackOverflow}!void);

        return current.scheduling.prepareStackForNewThread(thread, context, target_function);
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
        core.panic("`" ++ @tagName(kernel.info.arch) ++ "` does not implement `" ++ name ++ "`");
    }

    const DeclT = @TypeOf(@field(Container, name));

    const mismatch_type_msg =
        comptime "Expected `" ++ name ++ "` to be compatible with `" ++ @typeName(TargetT) ++
        "`, but it is `" ++ @typeName(DeclT) ++ "`";

    const decl_type_info = @typeInfo(DeclT).Fn;
    const target_type_info = @typeInfo(TargetT).Fn;

    if (decl_type_info.return_type != target_type_info.return_type) @compileError(mismatch_type_msg);

    if (decl_type_info.params.len != target_type_info.params.len) @compileError(mismatch_type_msg);

    inline for (decl_type_info.params, target_type_info.params) |decl_param, target_param| {
        if (decl_param.type != target_param.type) @compileError(mismatch_type_msg);
    }
}
