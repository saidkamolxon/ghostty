//! Helpers for translating Win32 keyboard input into Ghostty input.
const std = @import("std");
const input = @import("../../input.zig");
const windows = @import("../../os/main.zig").windows;
const user32 = windows.exp.user32;

/// The physical key for a WM_KEYDOWN/WM_KEYUP lparam. Windows reports
/// the scancode in bits 16-23 and whether it is an extended (0xE0
/// prefixed) key in bit 24. Our keycode table stores the scancode with
/// the 0xE0 prefix for extended keys.
pub fn physicalKey(lparam: windows.LPARAM) input.Key {
    const native = nativeScancode(lparam);
    if (native == 0) return .unidentified;
    for (input.keycodes.entries) |entry| {
        if (entry.native == native) return entry.key;
    }
    return .unidentified;
}

fn nativeScancode(lparam: windows.LPARAM) u32 {
    const bits: usize = @bitCast(lparam);
    const scancode: u32 = @intCast((bits >> 16) & 0xFF);
    const extended = (bits >> 24) & 1 == 1;
    return if (extended) 0xE000 | scancode else scancode;
}

/// The action for a key message.
pub fn action(msg: windows.UINT, lparam: windows.LPARAM) input.Action {
    return switch (msg) {
        windows.WM_KEYUP, windows.WM_SYSKEYUP => .release,
        else => {
            // Bit 30 is the previous key state: 1 if it was already down.
            const bits: usize = @bitCast(lparam);
            return if ((bits >> 30) & 1 == 1) .repeat else .press;
        },
    };
}

/// The currently pressed modifiers, read from the keyboard state of
/// the message being processed.
pub fn currentMods() input.Mods {
    var mods: input.Mods = .{
        .shift = isDown(windows.VK_SHIFT),
        .ctrl = isDown(windows.VK_CONTROL),
        .alt = isDown(windows.VK_MENU),
        .super = isDown(windows.VK_LWIN) or isDown(windows.VK_RWIN),
        .caps_lock = isToggled(windows.VK_CAPITAL),
        .num_lock = isToggled(windows.VK_NUMLOCK),
    };

    if (isDown(windows.VK_RSHIFT)) mods.sides.shift = .right;
    if (isDown(windows.VK_RCONTROL)) mods.sides.ctrl = .right;
    if (isDown(windows.VK_RMENU)) mods.sides.alt = .right;
    if (isDown(windows.VK_RWIN)) mods.sides.super = .right;

    return mods;
}

fn isDown(vk: c_int) bool {
    return user32.GetKeyState(vk) < 0;
}

fn isToggled(vk: c_int) bool {
    return user32.GetKeyState(vk) & 1 == 1;
}

/// The codepoint the virtual key produces with no modifiers.
pub fn unshiftedCodepoint(vk: windows.WPARAM) u21 {
    const raw = user32.MapVirtualKeyW(@truncate(vk), windows.MAPVK_VK_TO_CHAR);

    // The high bit is set for dead keys.
    const cp = raw & 0x7FFF_FFFF;
    if (cp == 0) return 0;

    // MapVirtualKey reports letters in uppercase.
    if (cp >= 'A' and cp <= 'Z') return @intCast(cp + ('a' - 'A'));
    return std.math.cast(u21, cp) orelse 0;
}

/// Accumulates WM_CHAR UTF-16 code units into UTF-8.
pub const TextBuffer = struct {
    buf: [32]u8 = undefined,
    len: usize = 0,
    high_surrogate: ?u16 = null,

    pub fn slice(self: *const TextBuffer) []const u8 {
        return self.buf[0..self.len];
    }

    /// Append a UTF-16 code unit. Control characters are dropped since
    /// the key encoder produces those from the key and modifiers.
    pub fn appendUtf16(self: *TextBuffer, unit: u16) void {
        const cp: u21 = cp: {
            if (std.unicode.utf16IsHighSurrogate(unit)) {
                self.high_surrogate = unit;
                return;
            }

            if (std.unicode.utf16IsLowSurrogate(unit)) {
                const high = self.high_surrogate orelse return;
                self.high_surrogate = null;
                break :cp std.unicode.utf16DecodeSurrogatePair(&.{ high, unit }) catch return;
            }

            self.high_surrogate = null;
            break :cp unit;
        };

        if (cp < 0x20 or cp == 0x7F) return;
        if (self.buf.len - self.len < 4) return;
        self.len += std.unicode.utf8Encode(cp, self.buf[self.len..]) catch return;
    }
};

test "TextBuffer surrogate pairs" {
    const testing = std.testing;
    var buf: TextBuffer = .{};
    buf.appendUtf16('a');
    // U+1F600 GRINNING FACE
    buf.appendUtf16(0xD83D);
    buf.appendUtf16(0xDE00);
    try testing.expectEqualStrings("a\u{1F600}", buf.slice());
}

test "TextBuffer drops control characters" {
    const testing = std.testing;
    var buf: TextBuffer = .{};
    buf.appendUtf16(0x01);
    buf.appendUtf16(0x7F);
    buf.appendUtf16('x');
    try testing.expectEqualStrings("x", buf.slice());
}
