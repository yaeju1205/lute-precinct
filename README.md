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

https://github.com/yaeju1205/lute-precinct
luau-precinct version of lute 

use lute
