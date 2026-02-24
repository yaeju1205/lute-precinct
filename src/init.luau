--!optimize 2

local parser = require("@std/syntax/parser")
local luau = require("@lute/luau")

return function(source: string)
    local parse = parser.parse(source)
    local root = parse.root
    local statements = root.statements
    local lines = string.split(source, "\n")
    
    local function concat_table<T>(...: { T }): { T }
        local args = table.pack(...)
        local res: { T } = {}
        for i=1, args.n do
            for j=1, #args[i] do
                table.insert(res, args[i][j])
            end
        end
        return res
    end

    local function map<T, U>(tab: { T }, callback: (T) -> U): { U }
        local res = {}
        for i=1, #tab do
            table.insert(res, callback(tab[i]))
        end
        return res
    end

    local function map_unpack<T, U>(tab: { T }, callback: (T) -> U): ...U
        return table.unpack(map(tab, callback))
    end

    local finder = {}

    function finder.with_expression(expression: luau.AstExpr): { luau.AstExpr }
        if expression.tag == "call" then
            local line = lines[expression.func.location.beginline]
            local funclocation = expression.func.location
            local funcname = string.sub(line, funclocation.begincolumn, funclocation.endcolumn - 1)
            if funcname == "require" then
                if expression.self then
                    return {}
                end
                if #expression.arguments > 1 then
                    return {}
                end
                
                return { expression.arguments[1].node }
            end
        elseif expression.tag == "binary" then
            return concat_table(
                finder.with_expression(expression.lhsoperand),
                finder.with_expression(expression.rhsoperand)
            )
        elseif expression.tag == "conditional" then
            return concat_table(
                finder.with_expression(expression.condition),
                finder.with_expression(expression.elseexpr),
                concat_table(map_unpack(
                    expression.elseifs,
                    function(else_if: luau.AstElseIfExpr): { luau.AstExpr }
                        return finder.with_expression(else_if.condition)
                    end
                )) :: { luau.AstExpr }
            )
        elseif expression.tag == "function" then
            return concat_table((map_unpack(
                expression.body.statements,
                function(statement: luau.AstStat): { luau.AstExpr }
                    return finder.with_statement(statement)
                end
            ))) :: { luau.AstExpr }
        elseif expression.tag == "group" then
            return finder.with_expression(expression.expression)
        elseif expression.tag == "index" then
            return finder.with_expression(expression.index)
        elseif expression.tag == "table" then
            return concat_table((map_unpack(
                expression.entries,
                function(entry: luau.AstTableExprItem): { luau.AstExpr }
                    if entry.kind == "general" then
                        return concat_table(
                            finder.with_expression(entry.key),
                            finder.with_expression(entry.value)
                        )
                    end
                    return finder.with_expression(entry.value)
                end
            )))
        elseif expression.tag == "unary" then
            return finder.with_expression(expression.operand)
        end
        return {}
    end

    function finder.with_statement(statement: luau.AstStat): { luau.AstExpr }
        if statement.tag == "assign" then
            return concat_table(
                concat_table(map_unpack(
                    statement.variables,
                    function(variable: luau.Pair<luau.AstExpr, ",">): { luau.AstExpr }
                        return finder.with_expression(variable.node)
                    end
                )) :: { luau.AstExpr },
                concat_table(map_unpack(
                    statement.values,
                    function(value: luau.Pair<luau.AstExpr, ",">): { luau.AstExpr }
                        return finder.with_expression(value.node)
                    end
                )) :: { luau.AstExpr }
            )
        elseif statement.tag == "block" then
            return finder.with_statements(statement.statements)
        elseif statement.tag == "conditional" then
            return concat_table(
                finder.with_expression(statement.condition),
                if statement.elseblock then
                    finder.with_statements(statement.elseblock.statements)
                else
                    {},
                concat_table(map_unpack(
                    statement.elseifs,
                    function(else_if: luau.AstElseIfStat): { luau.AstExpr }
                        return finder.with_expression(else_if.condition)
                    end
                )) :: { luau.AstExpr }
            )
        elseif statement.tag == "do" then
            return finder.with_statements(statement.body.statements)
        elseif statement.tag == "for" then
            return concat_table(
                finder.with_expression(statement.from),
                finder.with_expression(statement.to),
                if statement.step then
                    finder.with_expression(statement.step)
                else
                    {},
                finder.with_statements(statement.body.statements)
            )
        elseif statement.tag == "forin" then
            return concat_table(
                concat_table(map_unpack(statement.values, function(value: luau.Pair<luau.AstExpr, ",">): { luau.AstExpr }
                    return finder.with_expression(value.node)
                end)) :: { luau.AstExpr },
                finder.with_statements(statement.body.statements)
            )
        elseif statement.tag == "expression" then
            return finder.with_expression(statement.expression)
        elseif statement.tag == "function" then
            return finder.with_statements(statement.func.body.statements)
        elseif statement.tag == "local" then
            return concat_table((
                concat_table(map_unpack(statement.values, function(value: luau.Pair<luau.AstExpr, ",">): { luau.AstExpr }
                    return finder.with_expression(value.node)
                end)) :: { luau.AstExpr }
            ))
        elseif statement.tag == "localfunction" then
            return finder.with_statements(statement.func.body.statements)
        elseif statement.tag == "repeat" then
            return concat_table(
                finder.with_expression(statement.condition),
                finder.with_statements(statement.body.statements)
            )
        elseif statement.tag == "return" then
            return concat_table((
                concat_table(map_unpack(statement.expressions, function(expression: luau.Pair<luau.AstExpr, ",">): { luau.AstExpr }
                    return finder.with_expression(expression.node)
                end)) :: { luau.AstExpr }
            ))
        elseif statement.tag == "while" then
            return concat_table(
                finder.with_expression(statement.condition),
                finder.with_statements(statement.body.statements)
            )
        end

        return {}
    end

    function finder.with_statements(statements: { luau.AstStat }): { luau.AstExpr }
        return concat_table(map_unpack(
            statements,
            function(statement: luau.AstStat)
                return finder.with_statement(statement)
            end
        )) :: { luau.AstExpr }
    end

    return finder.with_statements(statements)
end
