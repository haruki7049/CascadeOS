// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2024 Lee Cannon <leecannon@leecannon.xyz>

const core = @import("core");
const kernel = @import("kernel");
const std = @import("std");
const x86_64 = @import("../x86_64.zig");

const log = kernel.debug.log.scoped(.interrupt);

pub fn nonMaskableInterrupt(interrupt_frame: *const x86_64.interrupts.InterruptFrame) void {
    _ = interrupt_frame;

    log.debug("non-maskable interrupt", .{});
}

/// Handles unhandled interrupts by printing the vector and then panicking.
pub fn unhandledInterrupt(interrupt_frame: *const x86_64.interrupts.InterruptFrame) void {
    const idt_vector = interrupt_frame.getIdtVector();

    if (idt_vector.isException()) {
        core.panicFmt("exception: {s}", .{@tagName(idt_vector)}) catch unreachable;
    }

    core.panicFmt("interrupt {d}", .{@intFromEnum(idt_vector)}) catch unreachable;
}
