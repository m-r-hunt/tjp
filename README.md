# Typed JSON Parser

Typed JSON Parser (TJP for short) is a Zig library for parsing JSON directly into Zig values, unlike std.json which returns a tree of unions which the user must marshal into their desired type. In fact TJP is just a wrapper around std.json.

TJP is currently unfinished (see TODOs below), but starting to be functional.

## Example

```zig
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

    var result = try tsjson(ExampleStruct, tree.root);
    std.debug.warn("\n{}\n", result);
```

```
ExampleStruct{ .an_int = 1, .a_float = 3.5e+00, .optional = null, .an_array = i32@c6df9ff7a8, .nested_struct = struct:193:24{ .another_int = 6 } }
```

## Usage

(TODO Figure out how Zig packages work with the build system and how someone would actually use this)

## How it works

TJP uses comptime reflection to inspect the types passed to it, and generate the code needed to traverse the std.json ValueTree at runtime. It uses a recursive function to inspect potentially nested types.

## Type mappings

| Zig Type | JSON Type |
------------------------
| Any integer | JSON Integer as parsed by std.JSON. Checked to fit in given size/signedness |
| Any float | JSON Integer or Float as parsed by std.JSON. Converted by @intToFloat or @FloatCast respectively |
| Optional | underlying type or null. Key may be omitted from JSON encoded structs (in which case the optional will be null) |
| Struct | JSON Object with keys corresponding to struct fields and correctly typed values |
| Array | JSON Array of correct typed values, with the exact length of the array type. (TODO Array of optionals?) |
| Enum | JSON String of enum case name (TODO) |
| []const u8 | JSON String (TODO Memory) |
| Tagged Union | JSON Object with two fields: "@tagName", a string with the tag name, and "value", the value for that tag (TODO) |

Types not listed are not supported.

## Limitations

1) TJP uses some fairly complex comptime features of Zig. I hit and worked around a number of compiler bugs while writing it. It's quite likely it may break unexpectedly as the compiler evolves. TJP certainly won't be considered stable (1.0) until Zig itself is.

2) Due to the recursive nature of type parsing, recursive types are not supported. Likely you will crash the compiler if you pass one to TJP.

3) Similarly, very deeply nested types may crash the compiler with a stack overflow.

## Future Enhancements

* Better error reporting (preferably including the paths through the Zig type and JSON to where the error occurred).
* Support for ArrayList(T) and StringHashMap(T) as variable length JSON arrays and objects with arbitrary keys respectively. Since these are stdlib types we should be able to detect them and construct them as a special case. This adds a lot of flexibility lacking from the primitive type mappings given above.
* A JSON writer that writes Zig types out in the format expected by the TJP parser