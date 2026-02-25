--!nocheck

local tableext = require("@std/tableext")
local printer = require("@std/syntax/printer")
local luau = require("@lute/luau")
local precinct = require("./precinct")

local source = [[
require("./call")
if require("./cond") then
end
while require("./while") do
end
for i=1, require("./for") do
end
for i in require("./forin") do
end
repeat
until require("./repeat")
do
    require("./do")
end
local _ = require("./local")
local _ = {
    a = require("./table")
}
_ = require("./assing")
local _ = require(game.GetService)
_.require("./index")
_:require("./self")
_["require"]("./index")
_ = if require("./condexpr") then
    1
else
    0
]]

tableext.map(precinct(source), function(expression: luau.AstExpr)
    print(`require to\n    => {printer.printnode(expression)}`)
end)

