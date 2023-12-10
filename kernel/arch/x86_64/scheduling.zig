// SPDX-License-Identifier: MIT

const core = @import("core");
const kernel = @import("kernel");
const PhysicalAddress = kernel.PhysicalAddress;
const Processor = kernel.Processor;
const Stack = kernel.Stack;
const std = @import("std");
const Thread = kernel.Thread;
const VirtualAddress = kernel.VirtualAddress;
const x86_64 = @import("x86_64.zig");

/// Switches to the provided stack and returns.
///
/// It is the caller's responsibility to ensure the stack is valid, with a return address.
pub inline fn changeStackAndReturn(stack_pointer: VirtualAddress) noreturn {
    asm volatile (
        \\  mov %[stack], %%rsp
        \\  ret
        :
        : [stack] "rm" (stack_pointer.value),
        : "memory", "stack"
    );
    unreachable;
}

pub inline fn prepareStackForNewThread(
    stack: *Stack,
    thread: *kernel.Thread,
    context: u64,
    target_function: *const fn (thread: *kernel.Thread, context: u64) noreturn,
) error{StackOverflow}!void {
    const old_stack_pointer = stack.stack_pointer;
    errdefer stack.stack_pointer = old_stack_pointer;

    try stack.pushReturnAddress(VirtualAddress.fromPtr(@ptrCast(&startNewThread)));

    try stack.push(VirtualAddress.fromPtr(@ptrCast(target_function)));
    try stack.push(context);
    try stack.push(VirtualAddress.fromPtr(thread));

    try stack.pushReturnAddress(VirtualAddress.fromPtr(@ptrCast(&_startNewThread)));

    // general purpose registers
    for (0..6) |_| stack.push(@as(u64, 0)) catch unreachable;
}

pub fn switchToThreadFromIdle(processor: *Processor, thread: *Thread) noreturn {
    const process = thread.process;

    if (!process.isKernel()) {
        // If the process is not the kernel we need to switch the page table and privilege stack.

        x86_64.paging.switchToPageTable(process.page_table);

        processor.arch.tss.setPrivilegeStack(.kernel, thread.kernel_stack);
    }

    _switchToThreadFromIdleImpl(thread.kernel_stack.stack_pointer);
    unreachable;
}

fn startNewThread(
    thread: *kernel.Thread,
    context: u64,
    target_function_addr: *const anyopaque,
) callconv(.C) noreturn {
    kernel.scheduler.unsafeUnlockScheduler();

    const target_function: *const fn (thread: *kernel.Thread, context: u64) noreturn = @ptrCast(target_function_addr);

    target_function(thread, context);
    unreachable;
}

// Implemented in 'x86_64/asm/startNewThread.S'
extern fn _startNewThread() callconv(.C) noreturn;

// Implemented in 'x86_64/asm/switchToThreadFromIdleImpl.S'
extern fn _switchToThreadFromIdleImpl(new_kernel_stack_pointer: VirtualAddress) callconv(.C) void;
