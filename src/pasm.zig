const std = @import("std");
const main = @import("main.zig");

pub const PasmError = error{
    InvalidCharacter,
    Overflow,
    InvalidDirective,
    InvalidInstruction,
    OutOfMemory,
    Py16OutOfMemory,
    ExpectedAddress,
    ExpectedWord,
    LabelRedefinition,
    UndefinedLabel,
    OriginNotFirst,
    ExpectedInstructionOrDirective,
};

const TokenType = enum {
    directive,
    instruction,
    label_definition,
    label_reference,
    word,
};

const Directive = enum {
    origin,
    data,
};

const Token = union(TokenType) {
    directive: Directive,
    instruction: u16,
    label_definition: []const u8,
    label_reference: []const u8,
    word: u16,
};

const Pasm = struct {
    const Self = @This();

    directive_lookup: std.StringHashMap(Directive),
    instruction_lookup: std.StringHashMap(u16),

    program: []const u8,
    index: usize,

    tokens: std.ArrayList(Token),
    token_index: usize,
    labels: std.StringHashMap(u12),

    code: std.ArrayList(u16),
    addr: u12,
    org: u12,

    fn getChar(self: *Self) u8 {
        if (self.index < self.program.len) return self.program[self.index];
        return 0;
    }

    fn getToken(self: *Self) ?Token {
        if (self.token_index < self.tokens.items.len) return self.tokens.items[self.token_index];
        return null;
    }

    fn getTokenString(self: *Self, isValidChar: fn (u8) bool) []const u8 {
        const start = self.index;

        while (isValidChar(self.getChar())) {
            self.index += 1;
        }

        return self.program[start..self.index];
    }

    fn consumeDirective(self: *Self) PasmError!void {
        self.index += 1;

        const directive = self.directive_lookup.get(self.getTokenString(std.ascii.isAlpha));

        if (directive) |d| {
            try self.tokens.append(Token{ .directive = d });
        } else {
            return PasmError.InvalidDirective;
        }
    }

    fn consumeInstruction(self: *Self) PasmError!void {
        const instruction = self.instruction_lookup.get(self.getTokenString(std.ascii.isAlpha));

        if (instruction) |i| {
            try self.tokens.append(Token{ .instruction = i });
        } else {
            return PasmError.InvalidInstruction;
        }
    }

    fn consumeLabelDefinition(self: *Self) PasmError!void {
        self.index += 1;
        try self.tokens.append(Token{ .label_definition = self.getTokenString(std.ascii.isAlpha) });
    }

    fn consumeLabelReference(self: *Self) PasmError!void {
        self.index += 1;
        try self.tokens.append(Token{ .label_reference = self.getTokenString(std.ascii.isAlpha) });
    }

    fn consumeDecimalWord(self: *Self) PasmError!void {
        try self.tokens.append(Token{ .word = try std.fmt.parseInt(u16, self.getTokenString(std.ascii.isDigit), 10) });
    }

    fn consumeHexWord(self: *Self) PasmError!void {
        self.index += 1;
        try self.tokens.append(Token{ .word = try std.fmt.parseInt(u16, self.getTokenString(std.ascii.isXDigit), 16) });
    }

    fn tokenize(self: *Self) PasmError!void {
        while (true) {
            while (std.ascii.isSpace(self.getChar())) {
                self.index += 1;
            }

            const c = self.getChar();

            switch (c) {
                0 => break,

                '.' => try self.consumeDirective(),
                ':' => try self.consumeLabelDefinition(),
                '@' => try self.consumeLabelReference(),
                '$' => try self.consumeHexWord(),

                else => if (std.ascii.isDigit(c)) {
                    try self.consumeDecimalWord();
                } else if (std.ascii.isAlpha(c)) {
                    try self.consumeInstruction();
                } else {
                    return PasmError.InvalidCharacter;
                },
            }
        }
    }

    fn index_labels(self: *Self) PasmError!void {
        if (self.getToken()) |t| {
            switch (t) {
                TokenType.directive => |d| if (d == Directive.origin) {
                    self.token_index += 1;

                    const addr_token = self.getToken() orelse return PasmError.ExpectedAddress;
                    switch (addr_token) {
                        TokenType.word => |w| if (w < 0x1000) {
                            self.addr = @truncate(u12, w);
                            self.org = self.addr;
                            self.token_index += 1;
                        } else {
                            return PasmError.Overflow;
                        },
                        else => return PasmError.ExpectedAddress,
                    }
                },
                else => {},
            }
        }

        for (self.tokens.items[self.token_index..]) |t| {
            switch (t) {
                TokenType.directive => |d| if (d == Directive.data) {
                    self.addr += 1;
                } else {
                    return PasmError.OriginNotFirst;
                },
                TokenType.instruction => self.addr += 1,
                TokenType.label_definition => |label| {
                    const res = try self.labels.getOrPut(label);

                    if (!res.found_existing) {
                        res.value_ptr.* = self.addr;
                    } else {
                        return PasmError.LabelRedefinition;
                    }
                },
                else => {},
            }
        }
    }

    fn assemble(self: *Self) PasmError!void {
        while (self.getToken()) |t| {
            switch (t) {
                TokenType.directive => |d| if (d == Directive.data) {
                    self.token_index += 1;

                    const data_token = self.getToken() orelse return PasmError.ExpectedWord;
                    switch (data_token) {
                        TokenType.word => |w| try self.code.append(w),
                        TokenType.label_reference => |l| try self.code.append(self.labels.get(l) orelse return PasmError.UndefinedLabel),
                        else => return PasmError.ExpectedWord,
                    }
                },

                TokenType.instruction => |i| if (i != self.instruction_lookup.get("HALT")) {
                    self.token_index += 1;

                    const data_token = self.getToken() orelse return PasmError.ExpectedAddress;
                    const data = switch (data_token) {
                        TokenType.word => |w| if (w < 0x1000) w else return PasmError.Overflow,
                        TokenType.label_reference => |l| @as(u16, self.labels.get(l) orelse return PasmError.UndefinedLabel),
                        else => return PasmError.ExpectedAddress,
                    };

                    try self.code.append((i << 12) | data);
                } else {
                    try self.code.append(i << 12);
                },

                TokenType.label_definition => {},

                else => return PasmError.ExpectedInstructionOrDirective,
            }

            self.token_index += 1;
        }
    }
};

pub const PasmOutput = struct {
    code: std.ArrayList(u16),
    addr: u12,
};

pub fn assemble(program: []const u8) PasmError!PasmOutput {
    var pasm = Pasm{
        .program = program,
        .index = 0,
        .token_index = 0,
        .addr = 0,
        .org = 0,
        .tokens = std.ArrayList(Token).init(std.testing.allocator),
        .code = std.ArrayList(u16).init(std.testing.allocator),
        .directive_lookup = std.StringHashMap(Directive).init(std.testing.allocator),
        .instruction_lookup = std.StringHashMap(u16).init(std.testing.allocator),
        .labels = std.StringHashMap(u12).init(std.testing.allocator),
    };

    try pasm.directive_lookup.put("ORIGIN", Directive.origin);
    try pasm.directive_lookup.put("DATA", Directive.data);

    try pasm.instruction_lookup.put("LOAD", 0);
    try pasm.instruction_lookup.put("STORE", 1);
    try pasm.instruction_lookup.put("CLEAR", 2);
    try pasm.instruction_lookup.put("ADD", 3);
    try pasm.instruction_lookup.put("INCREMENT", 4);
    try pasm.instruction_lookup.put("SUBTRACT", 5);
    try pasm.instruction_lookup.put("DECREMENT", 6);
    try pasm.instruction_lookup.put("COMPARE", 7);
    try pasm.instruction_lookup.put("JUMP", 8);
    try pasm.instruction_lookup.put("JUMPGT", 9);
    try pasm.instruction_lookup.put("JUMPEQ", 10);
    try pasm.instruction_lookup.put("JUMPLT", 11);
    try pasm.instruction_lookup.put("JUMPNEQ", 12);
    try pasm.instruction_lookup.put("IN", 13);
    try pasm.instruction_lookup.put("OUT", 14);
    try pasm.instruction_lookup.put("HALT", 15);

    try pasm.tokenize();
    try pasm.index_labels();
    try pasm.assemble();

    pasm.instruction_lookup.deinit();
    pasm.directive_lookup.deinit();
    pasm.labels.deinit();
    pasm.tokens.deinit();

    return PasmOutput {
        .code = pasm.code,
        .addr = pasm.org,
    };
}
