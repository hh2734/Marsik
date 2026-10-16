# Marsik

A tiny scripting language that helps different languages talk to each other

Marsik is a small, complete mini-language you can embed into other programming languages. It's much smaller than Lua and leans on the host language to do the heavy lifting. Think of it as a little *lingua franca* between runtimes. More host languages are planned

---

## What it's for

Marsik isn't meant to be used on its own. You drop it into an existing app so the host program can:

- run small, sandboxed user scripts,
- pass data between systems written in different languages,
- offer the same tiny scripting layer across multiple runtimes

The whole language - parser, interpreter, standard library - fits in one file per host language

---

## Quick start

Each interpreter has one main entry point. The name is slightly different depending on the host:


```lua 
-- Lua
local globals = run_marsik_code('var = 1; print(var)')
-- globals.var -> 1
```

```js
// JavaScript
const globals = run_marsik_code(`var = 1; print(var)`);
-- globals.var -> 1
```

The return value is the script's **global environment table**. You can read variables from it directly:

```js
const g = run_marsik_code(`x = 17; marsik = "Marsik"`);
console.log(g.x);        // 17
console.log(g.marsik);   // "Marsik"
```

---

## Language basics

### Comments

Nestable block comments use `<<<` and `>>>`:

```marsik
<<< this is a comment >>>

<<< outer
    <<< inner? >>>
>>>
```

### Values and literals

| Literal     | Example                       |
|-------------|-------------------------------|
| Integer     | `17`                          |
| Float       | `6.3248`                      |
| Hexadecimal | `0x17`, `0xFfA13`             |
| String      | `"hello"`, `'world'`          |
| Boolean     | `true`, `false`               |
| Null        | `null`                        |
| Table       | `{1; 2; 3}`, `{name = "x"}`   |

### Variables

```lua
x = 10              <<< global >>>
local y = 20        <<< local to current scope >>>
a, b, c = 1, 2, 3   <<< multiple assignment >>>
```

`local` keeps a variable inside the current function or block. Assignment without `local` writes to the nearest enclosing scope, falling back to globals

### Operators

| Category   | Operators                              |
|------------|----------------------------------------|
| Arithmetic | `+`, `-`, `*`, `/`, `%`, `^`           |
| Comparison | `==`, `!=`, `<`, `>`, `<=`, `>=`       |
| Logical    | `and`, `or`, `not`                     |
| Bitwise    | `~`, `&`, `\|`, `<<`, `>>`             |
| Concat     | `..` (strings, tables, numbers)        |
| Length     | `#`                                    |
| Unary      | `-`, `#`, `~`, `not`                   |
| Assignment | `=`                                    |

### Control flow

```lua
if x > 5 do
    print("big")
elseif x > 0 do
    print("small")
else
    print("negative")
end

while x < 10 do
    x = x + 1
end

for i = 1, 10 do print(i) end
for j = 10, 1, -1 do print(j) end <<< with step >>>

while true do break end
```

### Functions

Named functions:

```lua
func add(a, b) do
    return a + b
end
```

Anonymous functions:

```lua
local f = func(x) do return x * 2 end
```

Multiple return values:

```lua
func swap(a, b) do
    return b, a
end

x, y = swap(1, 2)
```

### Tables

Tables are the only compound data structure. They map keys to values and also work as arrays

```lua
arr = {1; 2; 3; 4; 5}
print(arr[1], #arr)          <<< 1   5 >>>

obj = {name = "Raymond"; age = 23}
print(obj.name, obj.age)

mixed = {1; 2; key = "value"; ["computed"] = 100}
```

### Methods

Functions can be attached directly to table keys:

```lua
obj = {}

func obj.method(a, b) do
    return a + b
end

func obj["another"]() do
    print("called")
end

print(obj.method(3, 4))     <<< 7 >>>
obj.another()
```

---

## Built-in functions

### Globals

| Name              | What it does                                                                   |
|-------------------|--------------------------------------------------------------------------------|
| `print(…)`        | Prints arguments separated by tabs                                             |
| `type(v)`         | Returns `"null"`, `"boolean"`, `"number"`, `"string"`, `"table"`, `"function"` |
| `tonumber(v)`     | Converts to a number or returns `null`                                         |
| `tostring(v)`     | Converts to a string                                                           |
| `rawequal(a, b)`  | Strict equality without metamethods                                            |
| `rawget(t, k)`    | Table lookup without metamethods                                               |
| `rawset(t, k, v)` | Table store without metamethods                                                |
| `select(idx, …)`  | Returns arguments from position `idx`                                          |
| `pairs(t)`        | Iterator over all key/value pairs                                              |
| `ipairs(t)`       | Iterator over 1-based integer keys                                             |
| `next(t, k)`      | Low-level iterator                                                             |

### `math`

`abs, acos, asin, atan, atan2, ceil, cos, cosh, deg, exp, floor, fmod, frexp, ldexp, log, log10, max, min, modf, pow, rad, random, randomseed, sin, sinh, sqrt, tan, tanh`

Plus constants `pi` and `huge`

### `string`

`byte, char, find, format, gmatch, gsub, len, lower, match, rep, reverse, sub, upper`

### `table`

`insert, remove, concat, sort, pack, unpack`

### `os`

`clock, date, difftime, time, tmpname`

### `io`

`write, read, type`

---

## Example

```lua
<<< comment >>>
print("Hello, world!")

func factorial(n) do
    local result = 1
    for i = 1, n do
        result = result * i
    end
    return result
end

print("5! =", factorial(5))

arr = {1; 2; 3; 4; 5}
sum = 0
for i = 1, #arr do
    sum = sum + arr[i]
end
print("Array sum =", sum)

var = {lang = "Marsik"; v = 1}
print("Lang:", var.lang, "| v:", var.)
```

---

## Design notes

- **Small.** The whole interpreter is one file per host language
- **No VM, no bytecode.** It's a direct tree-walking interpreter that uses the host runtime for numbers, strings, containers, and closures
- **Host-friendly.** `run_marsik_code` returns the globals table, so the host can read and write script variables directly
- **Same behavior everywhere.** All hosts aim to run the same script the same way

---

## Status

| Host           | File           | Status |
|----------------|----------------|--------|
| Lua (main)     | `marsik.lua`   | ✅     |
| JavaScript     | `marsik.js`    | ✅     |
| Python         | `marsik.py`    | NEXT   |
| Ruby           | `marsik.rb`    | SOON   |
| Haxe           | SOON           | SOON   |
| Web (browser)  | SOON           | SOON   |


## License

See the repository for license details
