--!optimize 2

local parser = require("@std/syntax/parser")
local printer = require("@std/syntax/printer")
local tableext = require("@std/tableext")
local luau = require("@lute/luau")

return function(source: string)
	local parse = parser.parse(source)
	local root = parse.root
	local statements = root.statements

	local function concat_table<T>(...: { T }): { T }
		local res: { T } = {}
		tableext.extend(res, ...)
		return res
	end

	local finder = {}

	function finder.with_expression(expression: luau.AstExpr): { luau.AstExpr }
		if expression.tag == "call" then
			if printer.printnode(expression.func) == "require" then
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
			return concat_table<<luau.AstExpr>>(
				finder.with_expression(expression.condition),
				finder.with_expression(expression.elseexpr),
				concat_table<<luau.AstExpr>>(
					table.unpack(tableext.map<<number, luau.AstElseIfExpr, { luau.AstExpr }>>(
						expression.elseifs, 
						function(else_if)
							return finder.with_expression(else_if.condition)
						end
					))
				)
			)
		elseif expression.tag == "function" then
			return concat_table(
				(table.unpack(tableext.map(expression.body.statements, function(statement: luau.AstStat): { luau.AstExpr }
					return finder.with_statement(statement)
				end)))
			)
		elseif expression.tag == "group" then
			return finder.with_expression(expression.expression)
		elseif expression.tag == "index" then
			return finder.with_expression(expression.index)
		elseif expression.tag == "table" then
			return concat_table((table.unpack(tableext.map(expression.entries, function(entry: luau.AstTableExprItem): { luau.AstExpr }
				if entry.kind == "general" then
					return concat_table(finder.with_expression(entry.key), finder.with_expression(entry.value))
				end
				return finder.with_expression(entry.value)
			end))))
		elseif expression.tag == "unary" then
			return finder.with_expression(expression.operand)
		end
		return {}
	end

	function finder.with_statement(statement: luau.AstStat): { luau.AstExpr }
		if statement.tag == "assign" then
			return concat_table<<luau.AstExpr>>(
				concat_table<<luau.AstExpr>>(
					table.unpack(tableext.map(statement.variables, function(variable)
						return finder.with_expression(variable.node)
					end))
				),
				concat_table<<luau.AstExpr>>(
					table.unpack(tableext.map(statement.values, function(value)
						return finder.with_expression(value.node)
					end))
				)
			)
		elseif statement.tag == "block" then
			return finder.with_statements(statement.statements)
		elseif statement.tag == "conditional" then
			return concat_table(
				finder.with_expression(statement.condition),
				concat_table<<luau.AstExpr>>(
					table.unpack(tableext.map(statement.elseifs, function(else_if)
						return finder.with_expression(else_if.condition)
					end))
				),
				if statement.elseblock then
					finder.with_statements(statement.elseblock.statements)
				else
					{}
			)
		elseif statement.tag == "do" then
			return finder.with_statements(statement.body.statements)
		elseif statement.tag == "for" then
			return concat_table(
				finder.with_expression(statement.from),
				finder.with_expression(statement.to),
				finder.with_statements(statement.body.statements),
				if statement.step then
					finder.with_expression(statement.step)
				else
					{}
			)
		elseif statement.tag == "forin" then
			return concat_table(
				concat_table<<luau.AstExpr>>(
					table.unpack(tableext.map(statement.values, function(value)
						return finder.with_expression(value.node)
					end))
				),
				finder.with_statements(statement.body.statements)
			)
		elseif statement.tag == "expression" then
			return finder.with_expression(statement.expression)
		elseif statement.tag == "function" then
			return finder.with_statements(statement.func.body.statements)
		elseif statement.tag == "local" then
			return concat_table(
				concat_table<<luau.AstExpr>>(
					table.unpack(tableext.map(statement.values, function(value)
						return finder.with_expression(value.node)
					end))
				)
			)
		elseif statement.tag == "localfunction" then
			return finder.with_statements(statement.func.body.statements)
		elseif statement.tag == "repeat" then
			return concat_table(
				finder.with_expression(statement.condition),
				finder.with_statements(statement.body.statements)
			)
		elseif statement.tag == "return" then
			return concat_table(
				concat_table<<luau.AstExpr>>(
					table.unpack(tableext.map(
						statement.expressions,
						function(expression)
							return finder.with_expression(expression.node)
						end
					))
				)
			)
		elseif statement.tag == "while" then
			return concat_table(
				finder.with_expression(statement.condition),
				finder.with_statements(statement.body.statements)
			)
		end

		return {}
	end

	function finder.with_statements(statements: { luau.AstStat }): { luau.AstExpr }
		return concat_table<<luau.AstExpr>>(
				table.unpack(tableext.map(statements, function(statement)
					return finder.with_statement(statement)
				end))
			)
	end

	return finder.with_statements(statements)
end
