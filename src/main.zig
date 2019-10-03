const std = @import("std");
const testing = std.testing;
const json = std.json;
const ArrayList = std.ArrayList;
const math = std.math;
const TypeInfo = @import("builtin").TypeInfo;

fn i64InIntegerRange(comptime T: type, value: i64) bool {
    return true;
}

fn tsjson_struct(comptime T: type, comptime struct_type: TypeInfo.Struct, value: json.Value) !T {
    std.debug.warn("Got here\n");
    switch (value) {
        .Object => |o| {
            var ret = T{};
            inline for (struct_type.fields) |field| {
                if (o.getValue(field.name)) |val| {
                    @field(ret, field.name) = try tsjson(field.field_type, val);
                } else {
                    return error.JSONMissingObjectField;
                }
            }
            return ret;
        },
        else => return error.JSONExpectedObject,
    }
}

fn tsjson(comptime T: type, value: json.Value) !T {
    std.debug.warn("Actually running tsjson\n");
    const type_info = @typeInfo(T);
    const ret = try switch (type_info) {
        .Bool => switch (value) {
            .Bool => |b| b,
            else => error.JSONExpectedBool,
        },
        .Int => switch (value) {
            .Integer => |i| blk: {
                if (!i64InIntegerRange(T, i)) {
                    break :blk error.JSONIntegerOutOfRange;
                } else {
                    break :blk @intCast(T, i);
                }
            },
            else => error.JSONExpectedInt,
        },
        .Struct => |struct_type| tsjson_struct(T, struct_type, value),
        else => error.JSONBadType,
    };
    return ret;
}

const TestStruct = struct {
    //foo: bool = false,
    bar: i64 = 0,
    baz: i64 = 12,
};

test "basic add functionality" {
    std.debug.warn("Actually running test\n");
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s = "{\"foo\": true, \"barz\": 1}";

    var tree = try p.parse(s);
    defer tree.deinit();

    //var result = try tsjson(TestStruct, tree);
    var result = try tsjson(TestStruct, tree.root);
    std.debug.warn("\n{}\n", result);
}

const TestStruct2 = struct {
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
