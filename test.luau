--!nocheck

local precinct = require("./precinct")
local result = precinct([[
require("call")
if require("if") then
end
while require("while") do
end
for i=1, require("for") do
end
for i in require("forin") do
end
repeat
until require("repeat")
do
    require("do")
end
local _ = require("local")
local _ = {
    a = require("table")
}
_ = require("assing")
]])

local function tableToString(tbl, depth)
    depth = depth or 0
    local indent = string.rep("\t", depth)
    local nextIndent = string.rep("\t", depth + 1)

    local result = indent .. "{\n"

    for k, v in pairs(tbl) do
        result ..= nextIndent .. tostring(k) .. " = "

        if type(v) == "table" then
            result ..= tableToString(v, depth + 1)
        elseif type(v) == "string" then
            result ..= '"' .. v .. '"'
        else
            result ..= tostring(v)
        end

        result ..= ",\n"
    end

    result ..= indent .. "}"
    return result
end

print(tableToString(result))
