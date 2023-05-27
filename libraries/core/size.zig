// SPDX-License-Identifier: MIT

const std = @import("std");
const core = @import("core");

pub const Size = extern struct {
    bytes: usize,

    pub const Unit = enum(usize) {
        byte = 1,
        kib = 1024,
        mib = 1024 * 1024,
        gib = 1024 * 1024 * 1024,
        tib = 1024 * 1024 * 1024 * 1024,
    };

    pub const zero: Size = .{ .bytes = 0 };

    pub fn from(size: usize, unit: Unit) Size {
        return .{
            .bytes = size * @enumToInt(unit),
        };
    }

    pub fn isAligned(self: Size, alignment: Size) bool {
        return std.mem.isAligned(self.bytes, alignment.bytes);
    }

    pub fn alignForward(self: Size, alignment: Size) Size {
        return .{ .bytes = std.mem.alignForward(self.bytes, alignment.bytes) };
    }

    pub fn alignBackward(self: Size, alignment: Size) Size {
        return .{ .bytes = std.mem.alignBackward(self.bytes, alignment.bytes) };
    }

    pub fn add(self: Size, other: Size) Size {
        return .{ .bytes = self.bytes + other.bytes };
    }

    pub fn addInPlace(self: *Size, other: Size) void {
        self.bytes += other.bytes;
    }

    pub fn subtract(self: Size, other: Size) Size {
        return .{ .bytes = self.bytes - other.bytes };
    }

    pub fn subtractInPlace(self: *Size, other: Size) void {
        self.bytes -= other.bytes;
    }

    pub fn multiply(self: Size, value: usize) Size {
        return .{ .bytes = self.bytes * value };
    }

    pub fn multiplyInPlace(self: *Size, value: usize) void {
        self.bytes *= value;
    }

    pub fn lessThan(self: Size, other: Size) bool {
        return self.bytes < other.bytes;
    }

    pub fn lessThanOrEqual(self: Size, other: Size) bool {
        return self.bytes <= other.bytes;
    }

    pub fn greaterThan(self: Size, other: Size) bool {
        return self.bytes > other.bytes;
    }

    pub fn greaterThanOrEqual(self: Size, other: Size) bool {
        return self.bytes >= other.bytes;
    }

    pub fn equal(self: Size, other: Size) bool {
        return self.bytes == other.bytes;
    }

    comptime {
        std.debug.assert(@sizeOf(Size) == @sizeOf(usize));
        std.debug.assert(@bitSizeOf(Size) == @bitSizeOf(usize));
    }
};

comptime {
    refAllDeclsRecursive(@This());
}

fn refAllDeclsRecursive(comptime T: type) void {
    comptime {
        if (!@import("builtin").is_test) return;

        inline for (std.meta.declarations(T)) |decl| {
            if (!decl.is_pub) continue;

            defer _ = @field(T, decl.name);

            if (@TypeOf(@field(T, decl.name)) != type) continue;

            switch (@typeInfo(@field(T, decl.name))) {
                .Struct, .Enum, .Union, .Opaque => refAllDeclsRecursive(@field(T, decl.name)),
                else => {},
            }
        }
        return;
    }
}
