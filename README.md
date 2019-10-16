# Typed JSON Parser

Typed JSON Parser (TJP for short) is a Zig library for parsing JSON directly into Zig values, unlike std.json which returns a tree of unions which the user must marshal into their desired type. In fact TJP just provides the final unmarshalling step using a std.json Value tree.

TJP is currently unfinished (see TODOs below), but starting to be functional.

## Example

```zig
    const tjp = @import("tjp");
    const std = @import("std");
    const json = std.json;

    const ExampleStruct = struct {
        an_int: i32,
        a_float: f32,
        optional: ?i32,
        an_array: [4]i32,
        nested_struct: struct {
            another_int: i32,
        },
    };
    var p = json.Parser.init(std.debug.global_allocator, false);
    defer p.deinit();

    const s =
        \\{
        \\ "an_int": 1,
        \\ "a_float": 3.5,
        \\ 
        \\ "an_array": [1, 2, 3, 4],
        \\ "nested_struct": {"another_int": 6}
        \\}
    ;
    var tree = try p.parse(s);
    defer tree.deinit();

    var result = try tjp.unmarshal(ExampleStruct, tree.root, std.debug.global_allocator);
    std.debug.warn("\n{}\n", result);
```

```
ExampleStruct{ .an_int = 1, .a_float = 3.5e+00, .optional = null, .an_array = i32@c6df9ff7a8, .nested_struct = struct:193:24{ .another_int = 6 } }
```

## Usage

Zig's package management is still a WIP at the time of writing. To use this as a package, include the source somewhere (possibly as a git submodule) and add this to your build.zig:

```zig
lib_or_exe.addPackagePath("tjp", "path/to/tjp/src/tjp.zig");
```

Then you can `@import("tjp")` in your source files.

## How it works

TJP uses comptime reflection to inspect the types passed to it, and generate the code needed to traverse the std.json ValueTree at runtime. It uses a recursive function to inspect potentially nested types.

## Type mappings

| Zig Type | JSON Type |
|----------|-----------|
| Any integer | JSON Integer as parsed by std.JSON. Checked to fit in given size/signedness |
| Any float | JSON Integer or Float as parsed by std.JSON. Converted by @intToFloat or @FloatCast respectively |
| Optional | underlying type or null. Key may be omitted from JSON encoded structs (in which case the optional will be null) |
| Struct | JSON Object with keys corresponding to struct fields and correctly typed values |
| Array | JSON Array of correct typed values, with the exact length of the array type. (TODO Array of optionals?) |
| Enum | JSON String of enum case name or integer enum value |
| []const u8 | JSON String (Memory is shared with the original std.json Value) |
| Tagged Union | JSON Object with two fields: "tag", a string with the tag name, or the integer enum value, and "value", the value for that tag |

Types not listed are not supported. Additionally, these standard library containers are also understood as a special case:

| Zig Type | JSON Type |
|----------|-----------|
| ArrayList(T) | As a normal Array, but any size |
| StringHashMap(T) | JSON object with correctly typed values |

## Limitations

1) TJP uses some fairly complex comptime features of Zig. I hit and worked around a number of compiler bugs while writing it. It's quite likely it may break unexpectedly as the compiler evolves. TJP certainly won't be considered stable (1.0) until Zig itself is.

2) Due to the recursive nature of type parsing, recursive types are not supported. Likely you will crash the compiler if you pass one to TJP.

3) Similarly, very deeply nested types may crash the compiler with a stack overflow.

## Extensibility

Since TJP operates on a std.json Value tree, any other data format that could be parsed into that form could be run through TJP to perform final unmarshalling into real Zig types.

## Future Enhancements

* Better error reporting (preferably including the paths through the Zig type and JSON to where the error occurred).
* A JSON writer that writes Zig types out in the format expected by the TJP parser.
* An all-in-one wrapper around std.json that handles the initial JSON parsing too.
