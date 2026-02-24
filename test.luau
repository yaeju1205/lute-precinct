--!nocheck

local precinct = require("./src")
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

local function tableToString(tbl)
    local result = "{ " .. "\n"

    for k, v in pairs(tbl) do
        result ..= tostring(k) .. " = "

        if type(v) == "table" then
            result ..= tableToString(v)
        elseif type(v) == "string" then
            result ..= '"' .. v .. '"'
        else
            result ..= tostring(v)
        end

        result ..= ", " .. "\n"
    end

    return result .. "}"
end

print(tableToString(result))
