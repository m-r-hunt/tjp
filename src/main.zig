const std = @import("std");
const testing = std.testing;
const json = std.json;
const ArrayList = std.ArrayList;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn tsjson(comptime T: type, value: json.Value) !T {
    const type_info = @typeInfo(T);
    const ret = try switch (type_info) {
        .Bool => switch (value) {
            .Bool => |b| b,
            else => error.JSONExpectedBool,
        },
        .Struct => |struct_type| switch (value) {
            .Object => |o| blk: {
                var ret: T = undefined;
                inline for (struct_type.fields) |field| {
                    if (o.get(field.name)) |val| {
                        @field(ret, field.name) = try tsjson(field.field_type, val.value);
                    } else {
                        break :blk error.JSONMissingObjectField;
                    }
                }
                break :blk ret;
            },
            else => error.JSONExpectedObject,
        },

        else => error.JSONBadType,
    };
    return ret;
}

const TestStruct = struct {
    image: Image,
};

const Image = struct {
    width: i32,
    height: i32,
    title: []const u8,
    thumbnail: Thumbnail,
    animated: bool,
    ids: ArrayList(i32),
    double: f64,
};

const Thumbnail = struct {
    url: []const u8,
    height: i32,
    width: i32,
};

test "basic add functionality" {
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s = "{\"foo\": 32}";

    var tree = try p.parse(s);
    defer tree.deinit();

    //var result = try tsjson(TestStruct, tree);
    var result = try tsjson(struct {
        foo: bool,
    }, tree.root);
    std.debug.warn("\n{}\n", result);
}
