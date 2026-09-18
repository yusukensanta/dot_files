# Lua Basics for Neovim

**Target:** Beginners to Lua scripting in Neovim
**Neovim Version:** 0.11+
**Last Updated:** 2025-10-12

---

## Table of Contents

1. [Introduction](#introduction)
2. [Lua Fundamentals](#lua-fundamentals)
3. [Tables - The Core Data Structure](#tables---the-core-data-structure)
4. [Functions](#functions)
5. [Modules](#modules)
6. [Scoping and Closures](#scoping-and-closures)
7. [Error Handling](#error-handling)
8. [Iterators and Loops](#iterators-and-loops)
9. [Metatables and Metamethods](#metatables-and-metamethods)
10. [Best Practices](#best-practices)

---

## Introduction

### Why Lua?

Neovim uses **Lua 5.1** (via LuaJIT) as its embedded scripting language because:
- **Fast:** LuaJIT provides near-C performance
- **Simple:** Minimal syntax, easy to learn
- **Embeddable:** Designed for integration
- **Powerful:** Tables, closures, and coroutines provide sophisticated capabilities

### Your First Lua Script

Create a simple Lua script in Neovim:

```lua
-- Type this in Neovim command mode:
:lua print("Hello from Lua!")

-- Or save to a file and source it:
:luafile ~/.config/nvim/hello.lua
```

---

## Lua Fundamentals

### Data Types

Lua has 8 basic types:

```lua
-- 1. nil - represents absence of value
local nothing = nil

-- 2. boolean - true or false
local is_enabled = true
local is_disabled = false

-- 3. number - all numbers are doubles (includes integers and floats)
local integer = 42
local float = 3.14159
local scientific = 1.5e-10

-- 4. string - immutable text
local single = 'single quotes'
local double = "double quotes"
local multiline = [[
  This is a
  multiline string
]]

-- 5. function - first-class values
local add = function(a, b)
  return a + b
end

-- 6. table - THE fundamental data structure
local array = { 1, 2, 3 }
local object = { name = "Neovim", version = 0.11 }

-- 7. userdata - for C data structures (rarely used directly)
-- 8. thread - for coroutines
```

### Variables

```lua
-- Global variables (avoid in modules!)
GlobalVar = "accessible everywhere"

-- Local variables (preferred!)
local localVar = "scoped to block or file"

-- Multiple assignment
local x, y, z = 1, 2, 3

-- Swap values
x, y = y, x

-- Nil for missing values
local a, b = 1  -- a=1, b=nil
```

### Comments

```lua
-- Single-line comment

--[[
  Multi-line comment
  Can span multiple lines
]]

---
--- Triple-dash comments are often used for documentation
--- @param name string The name to greet
--- @return string The greeting message
---
local function greet(name)
  return "Hello, " .. name
end
```

### Operators

```lua
-- Arithmetic
local sum = 10 + 5      -- 15
local diff = 10 - 5     -- 5
local product = 10 * 5  -- 50
local quotient = 10 / 5 -- 2
local modulo = 10 % 3   -- 1
local power = 2 ^ 3     -- 8
local negate = -10      -- -10

-- Relational
local eq = 10 == 10     -- true
local neq = 10 ~= 5     -- true (not equal)
local lt = 5 < 10       -- true
local gt = 10 > 5       -- true
local lte = 5 <= 5      -- true
local gte = 10 >= 5     -- true

-- Logical
local and_op = true and false  -- false
local or_op = true or false    -- true
local not_op = not true        -- false

-- String concatenation
local greeting = "Hello, " .. "World!"  -- "Hello, World!"

-- Length operator
local str_len = #"Hello"       -- 5
local array_len = #{ 1, 2, 3 } -- 3
```

### Control Structures

```lua
-- If-else
local age = 25

if age < 18 then
  print("Minor")
elseif age < 65 then
  print("Adult")
else
  print("Senior")
end

-- Ternary-style (using 'and' and 'or')
local status = (age >= 18) and "adult" or "minor"

-- While loop
local count = 0
while count < 5 do
  print(count)
  count = count + 1
end

-- Repeat-until loop
local num = 0
repeat
  print(num)
  num = num + 1
until num >= 5

-- For loop (numeric)
for i = 1, 10 do
  print(i)  -- 1, 2, 3, ..., 10
end

-- For loop with step
for i = 10, 1, -2 do
  print(i)  -- 10, 8, 6, 4, 2
end

-- For loop (generic - iterators)
local colors = { "red", "green", "blue" }
for index, color in ipairs(colors) do
  print(index, color)
end

-- Break (no continue in Lua)
for i = 1, 10 do
  if i == 5 then
    break
  end
  print(i)
end
```

---

## Tables - The Core Data Structure

Tables are Lua's **only** data structure. They can represent:
- Arrays
- Dictionaries/Maps
- Objects
- Classes
- Modules

### Creating Tables

```lua
-- Empty table
local empty = {}

-- Array-style (1-indexed!)
local fruits = { "apple", "banana", "cherry" }
print(fruits[1])  -- "apple" (NOT 0!)

-- Dictionary-style
local person = {
  name = "John",
  age = 30,
  city = "Tokyo"
}

-- Mixed keys
local mixed = {
  "first",      -- [1] = "first"
  "second",     -- [2] = "second"
  key = "value",
  [10] = "tenth position",
  ["key-with-dash"] = "special key"
}

-- Nested tables
local config = {
  ui = {
    theme = "dark",
    font_size = 14
  },
  plugins = { "telescope", "treesitter" }
}
```

### Accessing Tables

```lua
local person = {
  name = "Alice",
  age = 30,
  ["full-name"] = "Alice Smith"
}

-- Dot notation (for valid identifiers)
print(person.name)  -- "Alice"
person.age = 31

-- Bracket notation (for any key)
print(person["name"])  -- "Alice"
print(person["full-name"])  -- "Alice Smith"

-- Dynamic keys
local key = "age"
print(person[key])  -- 31

-- Nested access
local config = { ui = { theme = "dark" } }
print(config.ui.theme)  -- "dark"
```

### Table Operations

```lua
-- Add elements
local array = { 1, 2, 3 }
table.insert(array, 4)       -- append: { 1, 2, 3, 4 }
table.insert(array, 2, 999)  -- insert at position 2: { 1, 999, 2, 3, 4 }

-- Remove elements
table.remove(array)     -- remove last: { 1, 999, 2, 3 }
table.remove(array, 2)  -- remove at position 2: { 1, 2, 3 }

-- Concatenate array elements
local str = table.concat(array, ", ")  -- "1, 2, 3"

-- Sort
local numbers = { 3, 1, 4, 1, 5, 9 }
table.sort(numbers)  -- { 1, 1, 3, 4, 5, 9 }

-- Custom sort
table.sort(numbers, function(a, b) return a > b end)  -- descending

-- Length
local len = #array  -- number of elements with integer keys from 1..n
```

### Iterating Tables

```lua
local person = {
  name = "Bob",
  age = 25,
  city = "NYC"
}

-- pairs() - iterate all keys (unordered)
for key, value in pairs(person) do
  print(key, value)
end

-- ipairs() - iterate array part (ordered, stops at first nil)
local colors = { "red", "green", "blue" }
for index, color in ipairs(colors) do
  print(index, color)  -- 1 red, 2 green, 3 blue
end

-- Numeric for loop (if you know the length)
for i = 1, #colors do
  print(colors[i])
end
```

**Important:** Arrays in Lua are **1-indexed**, not 0-indexed!

---

## Functions

Functions are **first-class values** in Lua - they can be stored in variables, passed as arguments, and returned from other functions.

### Function Syntax

```lua
-- Function declaration (syntactic sugar)
function greet(name)
  return "Hello, " .. name
end

-- Function expression (what actually happens)
local greet = function(name)
  return "Hello, " .. name
end

-- Call the function
local message = greet("World")  -- "Hello, World"
```

### Parameters and Return Values

```lua
-- Multiple parameters
function add(a, b)
  return a + b
end

-- Multiple return values
function divide(a, b)
  if b == 0 then
    return nil, "division by zero"
  end
  return a / b, nil
end

local result, err = divide(10, 2)
if err then
  print("Error:", err)
else
  print("Result:", result)  -- 5
end

-- Variable number of arguments (varargs)
function sum(...)
  local args = { ... }
  local total = 0
  for _, num in ipairs(args) do
    total = total + num
  end
  return total
end

print(sum(1, 2, 3, 4, 5))  -- 15

-- Named parameters using tables
function create_window(opts)
  local width = opts.width or 80
  local height = opts.height or 24
  local title = opts.title or "Window"
  -- create window...
end

create_window({ width = 100, title = "My Window" })
```

### Default Parameters

```lua
-- Lua doesn't have built-in default parameters, but you can use 'or'
function greet(name)
  name = name or "Guest"  -- default to "Guest" if name is nil
  return "Hello, " .. name
end

print(greet())        -- "Hello, Guest"
print(greet("Alice")) -- "Hello, Alice"
```

### Higher-Order Functions

```lua
-- Functions that take functions as arguments
function map(array, func)
  local result = {}
  for i, value in ipairs(array) do
    result[i] = func(value)
  end
  return result
end

local numbers = { 1, 2, 3, 4, 5 }
local squared = map(numbers, function(x) return x * x end)
-- { 1, 4, 9, 16, 25 }

-- Functions that return functions
function multiplier(factor)
  return function(x)
    return x * factor
  end
end

local double = multiplier(2)
local triple = multiplier(3)

print(double(5))  -- 10
print(triple(5))  -- 15
```

### Method Syntax

```lua
-- Define methods using colon syntax
local person = {
  name = "Alice",
  age = 30
}

-- Function as method (explicit self)
function person.greet(self)
  return "Hello, I'm " .. self.name
end

-- Method syntax (implicit self)
function person:introduce()
  return "I'm " .. self.name .. ", " .. self.age .. " years old"
end

-- Call methods
print(person.greet(person))      -- Explicit self
print(person:introduce())        -- Implicit self (syntactic sugar)
```

---

## Modules

Modules allow you to organize code into reusable components.

### Creating a Module

```lua
-- File: lua/mymodule.lua

-- Create module table (local to avoid polluting global scope)
local M = {}

-- Private function (not exported)
local function private_helper()
  return "I'm private"
end

-- Public function
function M.public_function()
  return "I'm public"
end

-- Public data
M.version = "1.0.0"

-- Another public function using private helper
function M.use_helper()
  return private_helper()
end

-- Return the module table
return M
```

### Using a Module

```lua
-- Load the module
local mymodule = require("mymodule")

-- Use public functions
print(mymodule.public_function())  -- "I'm public"
print(mymodule.version)            -- "1.0.0"
print(mymodule.use_helper())       -- "I'm private"

-- Cannot access private functions
-- print(mymodule.private_helper())  -- ERROR!
```

### Module Organization Patterns

```lua
-- Pattern 1: Simple module (shown above)
local M = {}
M.foo = function() end
return M

-- Pattern 2: Direct table construction
return {
  foo = function() end,
  bar = function() end,
  version = "1.0"
}

-- Pattern 3: Module with setup function
local M = {}
local config = {}

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

function M.get_config()
  return config
end

return M

-- Usage:
-- require("mymodule").setup({ theme = "dark" })
```

### Submodules

```lua
-- Directory structure:
-- lua/
--   mymodule/
--     init.lua
--     utils.lua
--     config.lua

-- File: lua/mymodule/init.lua
local M = {}

M.utils = require("mymodule.utils")
M.config = require("mymodule.config")

function M.run()
  M.utils.helper()
end

return M

-- Usage:
local mymodule = require("mymodule")
mymodule.run()
```

---

## Scoping and Closures

### Variable Scoping

```lua
-- Global scope (avoid!)
GlobalVar = "I'm accessible everywhere"

-- File/module scope
local moduleVar = "I'm accessible in this file"

-- Function scope
function myFunction()
  local funcVar = "I'm accessible only in this function"
  print(moduleVar)  -- Can access outer scope
end

-- Block scope
if true then
  local blockVar = "I'm accessible only in this block"
end
-- print(blockVar)  -- ERROR! Out of scope

-- Loop scope
for i = 1, 5 do
  local loopVar = "I'm accessible only in this loop iteration"
end
```

### Closures

A closure is a function that captures variables from its enclosing scope:

```lua
-- Basic closure
function counter()
  local count = 0
  return function()
    count = count + 1
    return count
  end
end

local c1 = counter()
print(c1())  -- 1
print(c1())  -- 2
print(c1())  -- 3

local c2 = counter()  -- Independent counter
print(c2())  -- 1

-- Practical example: Configuration with closure
function create_logger(prefix)
  local log_level = "INFO"

  return {
    set_level = function(level)
      log_level = level
    end,

    log = function(message)
      print(string.format("[%s] [%s] %s", prefix, log_level, message))
    end
  }
end

local logger = create_logger("MyPlugin")
logger.log("Starting")  -- [MyPlugin] [INFO] Starting
logger.set_level("DEBUG")
logger.log("Debug info")  -- [MyPlugin] [DEBUG] Debug info
```

---

## Error Handling

### pcall() - Protected Call

```lua
-- pcall() catches errors and returns status + result
local success, result = pcall(function()
  return 10 / 2
end)

if success then
  print("Result:", result)  -- 5
else
  print("Error:", result)   -- error message
end

-- Common pattern for optional module loading
local ok, module = pcall(require, "optional_module")
if not ok then
  print("Module not found, using defaults")
  module = { default = true }
end
```

### error() - Raising Errors

```lua
function divide(a, b)
  if b == 0 then
    error("division by zero", 2)  -- 2 = error level
  end
  return a / b
end

-- This will raise an error
local success, err = pcall(divide, 10, 0)
if not success then
  print("Caught error:", err)
end
```

### assert() - Assertions

```lua
-- assert() raises error if condition is false
function process_config(config)
  assert(config, "config is required")
  assert(type(config.name) == "string", "config.name must be a string")
  -- continue processing...
end

-- Neovim pattern: result-or-message
local file = assert(io.open("file.txt", "r"), "Failed to open file")
```

---

## Iterators and Loops

### Built-in Iterators

```lua
-- pairs() - iterate all key-value pairs
local config = { name = "Neovim", version = 0.11 }
for key, value in pairs(config) do
  print(key, value)
end

-- ipairs() - iterate array indices
local colors = { "red", "green", "blue" }
for index, color in ipairs(colors) do
  print(index, color)
end
```

### Custom Iterators

```lua
-- Simple iterator
function range(from, to)
  local current = from - 1
  return function()
    current = current + 1
    if current <= to then
      return current
    end
  end
end

-- Usage
for num in range(1, 5) do
  print(num)  -- 1, 2, 3, 4, 5
end

-- Stateful iterator
function lines_from_string(str)
  local pos = 1
  return function()
    if pos > #str then
      return nil
    end
    local line_end = string.find(str, "\n", pos, true) or #str + 1
    local line = string.sub(str, pos, line_end - 1)
    pos = line_end + 1
    return line
  end
end

-- Usage
local text = "line1\nline2\nline3"
for line in lines_from_string(text) do
  print(line)
end
```

---

## Metatables and Metamethods

Metatables allow you to change the behavior of tables.

### Basic Metatables

```lua
-- Create a table with custom behavior
local vec = { x = 1, y = 2 }

-- Create a metatable
local vec_mt = {
  -- __add metamethod for '+' operator
  __add = function(a, b)
    return { x = a.x + b.x, y = a.y + b.y }
  end,

  -- __tostring for print()
  __tostring = function(v)
    return string.format("Vec(%d, %d)", v.x, v.y)
  end,

  -- __index for missing keys
  __index = function(t, key)
    if key == "length" then
      return math.sqrt(t.x^2 + t.y^2)
    end
  end
}

-- Set the metatable
setmetatable(vec, vec_mt)

-- Use custom behavior
local vec2 = { x = 3, y = 4 }
setmetatable(vec2, vec_mt)

local vec3 = vec + vec2  -- { x = 4, y = 6 }
print(vec)               -- Vec(1, 2)
print(vec.length)        -- 2.236...
```

### Common Metamethods

```lua
local mt = {
  __add = function(a, b) end,      -- a + b
  __sub = function(a, b) end,      -- a - b
  __mul = function(a, b) end,      -- a * b
  __div = function(a, b) end,      -- a / b
  __mod = function(a, b) end,      -- a % b
  __pow = function(a, b) end,      -- a ^ b
  __unm = function(a) end,         -- -a
  __concat = function(a, b) end,   -- a .. b
  __len = function(a) end,         -- #a
  __eq = function(a, b) end,       -- a == b
  __lt = function(a, b) end,       -- a < b
  __le = function(a, b) end,       -- a <= b
  __index = function(t, k) end,    -- t[k] when k doesn't exist
  __newindex = function(t, k, v) end, -- t[k] = v when k doesn't exist
  __call = function(t, ...) end,   -- t(...)
  __tostring = function(t) end,    -- tostring(t)
}
```

---

## Best Practices

### 1. Always Use Local Variables

```lua
-- BAD: Global variable
function calculate()
  result = 10 + 20  -- Pollutes global scope!
end

-- GOOD: Local variable
function calculate()
  local result = 10 + 20
  return result
end
```

### 2. Use Descriptive Names

```lua
-- BAD
local x = 5
local function f(a, b)
  return a + b
end

-- GOOD
local retry_count = 5
local function calculate_sum(left, right)
  return left + right
end
```

### 3. Validate Function Arguments

```lua
-- Use vim.validate() in Neovim
function setup(opts)
  vim.validate({
    theme = { opts.theme, 'string', true },
    width = { opts.width, 'number', true },
    enabled = { opts.enabled, 'boolean', true },
  })
  -- ... rest of function
end
```

### 4. Return Early

```lua
-- BAD: Deep nesting
function process(data)
  if data then
    if data.valid then
      if data.ready then
        -- do work
      end
    end
  end
end

-- GOOD: Early returns
function process(data)
  if not data then return end
  if not data.valid then return end
  if not data.ready then return end
  -- do work
end
```

### 5. Use Tables for Named Parameters

```lua
-- BAD: Positional parameters
function create_window(width, height, title, border, shadow)
  -- Hard to remember order
end
create_window(100, 50, "My Window", true, false)

-- GOOD: Named parameters via table
function create_window(opts)
  local width = opts.width or 80
  local height = opts.height or 24
  local title = opts.title or "Window"
  -- ...
end
create_window({
  title = "My Window",
  width = 100
})
```

### 6. Document Your Functions

```lua
--- Calculates the sum of two numbers
--- @param a number First number
--- @param b number Second number
--- @return number Sum of a and b
local function add(a, b)
  return a + b
end
```

### 7. Use vim.tbl_* Utilities

```lua
-- Merge tables
local defaults = { width = 80, height = 24 }
local user_opts = { width = 100 }
local config = vim.tbl_extend("force", defaults, user_opts)
-- { width = 100, height = 24 }

-- Deep merge
local config = vim.tbl_deep_extend("force", defaults, user_opts)

-- Filter table
local numbers = { 1, 2, 3, 4, 5 }
local evens = vim.tbl_filter(function(v) return v % 2 == 0 end, numbers)
-- { 2, 4 }

-- Map table
local doubled = vim.tbl_map(function(v) return v * 2 end, numbers)
-- { 2, 4, 6, 8, 10 }
```

---

## Next Steps

Now that you understand Lua basics, continue to:
- **[Module Organization](module-organization.md)** - Structure your Neovim config
- **[Neovim Lua API](neovim-lua-api.md)** - Learn Neovim-specific APIs
- **[Lua Recipes](lua-recipes.md)** - Practical examples and patterns

---

## Quick Reference

### Key Differences from Other Languages

| Feature | Lua | JavaScript | Python |
|---------|-----|------------|--------|
| Arrays start at | 1 | 0 | 0 |
| Not equal | `~=` | `!==` | `!=` |
| String concatenation | `..` | `+` | `+` |
| Boolean operators | `and`, `or`, `not` | `&&`, `\|\|`, `!` | `and`, `or`, `not` |
| Function definition | `function()` | `function()` | `def` |
| Comments | `--` | `//` | `#` |
| Nil/null/None | `nil` | `null`, `undefined` | `None` |

### Common Patterns

```lua
-- Ternary operator
local result = condition and value_if_true or value_if_false

-- Default value
local value = user_value or default_value

-- Safe navigation (check before access)
local value = obj and obj.property and obj.property.nested

-- Module pattern
local M = {}
function M.exported() end
local function private() end
return M

-- Error handling
local ok, result = pcall(function() return risky_operation() end)
if not ok then handle_error(result) end
```

---

*Tutorial Version: 1.0*
*Last Updated: 2025-10-12*
