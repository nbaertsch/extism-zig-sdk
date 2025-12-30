const c = @import("extism_c");
const Self = @This();

handle: ?*const c.ExtismCancelHandle,

pub fn cancel(self: *Self) bool {
    return c.extism_plugin_cancel(self.handle);
}
