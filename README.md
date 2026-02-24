# precinct
Finding code dependencies in lute

## Usage
```luau
local precinct = require "path to require"
local luau = require("@lute/luau")

local dependencies = precinct([[
require"./module"
require"lib"
]])

-- { luau.AstExpr }
print(dependencies)
```
