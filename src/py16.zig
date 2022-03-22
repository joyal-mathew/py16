pub const RESET_VECTOR: u16 = 0xFFF;

const Self = @This();

pub const Syscall = enum {
    none,
    halt,
    in,
    out,
};

const instructions = [_]fn (*Self) void{
    load,
    store,
    clear,
    add,
    increment,
    subtract,
    decrement,
    compare,
    jump,
    jumpgt,
    jumpeq,
    jumplt,
    jumpneq,
    in,
    out,
    halt,
};

// state

pc: u12,
oprand: u12,

r: u16,
ram: [0x1000]u16,

syscall: Syscall,

flags: struct {
    gt: bool,
    eq: bool,
    lt: bool,
},

io: struct {
    in: u16,
    out: u16,
},

pub fn init() Self {
    return Self{ .pc = 0, .oprand = 0, .r = 0, .ram = [_]u16{0} ** 0x1000, .syscall = Syscall.none, .flags = .{
        .gt = false,
        .eq = false,
        .lt = false,
    }, .io = .{
        .in = 0,
        .out = 0,
    } };
}

pub fn reset(self: *Self) void {
    self.pc = @truncate(u12, self.ram[RESET_VECTOR]);
    self.syscall = Syscall.none;
}

pub fn clock(self: *Self) void {
    const word = self.ram[self.pc];

    self.syscall = Syscall.none;
    self.oprand = @truncate(u12, word);
    self.pc +%= 1;

    instructions[word >> 12](self);
}

// instructions

fn load(self: *Self) void {
    self.r = self.ram[self.oprand];
}

fn store(self: *Self) void {
    self.ram[self.oprand] = self.r;
}

fn clear(self: *Self) void {
    self.ram[self.oprand] = 0;
}

fn add(self: *Self) void {
    self.r +%= self.ram[self.oprand];
}

fn increment(self: *Self) void {
    self.ram[self.oprand] +%= 1;
}

fn subtract(self: *Self) void {
    self.r -%= self.ram[self.oprand];
}

fn decrement(self: *Self) void {
    self.ram[self.oprand] -%= 1;
}

fn compare(self: *Self) void {
    const x: i16 = @bitCast(i16, self.ram[self.oprand]);
    const r: i16 = @bitCast(i16, self.r);

    self.flags.gt = x > r;
    self.flags.eq = x == r;
    self.flags.lt = x < r;
}

fn jump(self: *Self) void {
    self.pc = self.oprand;
}

fn jumpgt(self: *Self) void {
    if (self.flags.gt) self.pc = self.oprand;
}

fn jumpeq(self: *Self) void {
    if (self.flags.eq) self.pc = self.oprand;
}

fn jumplt(self: *Self) void {
    if (self.flags.lt) self.pc = self.oprand;
}

fn jumpneq(self: *Self) void {
    if (!self.flags.eq) self.pc = self.oprand;
}

fn in(self: *Self) void {
    self.io.in = self.oprand;
    self.syscall = Syscall.in;
}

fn out(self: *Self) void {
    self.io.out = self.oprand;
    self.syscall = Syscall.out;
}

fn halt(self: *Self) void {
    self.syscall = Syscall.halt;
}
