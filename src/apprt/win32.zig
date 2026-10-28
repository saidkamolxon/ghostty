//! Native Win32 application runtime.
//!
//! This is a deliberately small apprt: every surface is its own top-level
//! window (no tabs or splits yet) and frames rendered by the OpenGL
//! renderer are read back to the CPU and blitted with GDI.

// The required comptime API for any apprt.
pub const App = @import("win32/App.zig");
pub const Surface = @import("win32/Surface.zig");
pub const resourcesDir = @import("../os/main.zig").resourcesDir;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("win32/key.zig");
}
