const std = @import("std");
const Py16 = @import("py16.zig");
const pasm = @import("pasm.zig");

const test_program =
    \\ OUT 0
;

test "TEST" {
    const pasmOut = pasm.assemble(test_program.*[0..]) catch unreachable;
    defer pasmOut.code.deinit();

    std.log.info("{}", .{pasmOut.addr});
}

extern fn input() u16;
extern fn output(u16) void;
extern fn err([*]u8, usize) void;

export fn run(code: [*]u16, len: usize, origin: u16) void {
    var py16 = Py16.init();

    py16.ram[Py16.RESET_VECTOR] = origin;
    py16.reset();

    for (py16.ram[origin .. origin + len]) |*w, i| {
        w.* = code[i];
    }

    while (true) {
        py16.clock();

        switch (py16.syscall) {
            Py16.Syscall.halt => break,
            Py16.Syscall.in => py16.ram[py16.io.in] = input(),
            Py16.Syscall.out => output(py16.ram[py16.io.out]),
            Py16.Syscall.none => {},
        }
    }
}

fn genError(comptime string: anytype) void {
    var errMsg: [string.len:0]u8 = string.*;
    err(@ptrCast([*]u8, &errMsg), errMsg.len);
}

export fn assemble(program: [*]u8, len: usize, outCode: [*]u16) u32 {
    const pasmOutWithErr = pasm.assemble(program[0..len]);

    if (pasmOutWithErr) |pasmOut| {
        defer pasmOut.code.deinit();

        if (pasmOut.code.items.len > 0x1000) {
            genError("Generated code too long");
            return 0xFFFF;
        }

        for (pasmOut.code.items) |w, i| {
            outCode[i] = w;
        }

        return (@as(u32, @truncate(u16, pasmOut.code.items.len)) << 16) | @as(u32, pasmOut.addr);
    } else |e| {
        var errMsg = std.fmt.allocPrint(std.testing.allocator, "{}", .{e});
        if (errMsg) |em| {
            err(@ptrCast([*]u8, em), em.len);
        } else |_| {
            genError("There was an error but insufficient memory to report it");
        }

        return 0xFFFF;
    }
}
