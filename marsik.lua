function err(_err, token, source)
	local line, col
	if token and token.line then
		line = token.line
		col = token.col
	elseif token and type(token) == "number" then
		line, col = get_line_col_from_pos(token)
	else
		print("Error: ".._err)
		os.exit(1)
	end

	print(string.format("Error at line %d, column %d: %s", line, col, _err))

	if source and line then
		local src_lines = {}
		for l in string.gmatch(source, "([^\n]*)\n?") do
			table.insert(src_lines, l)
		end
		if line <= #src_lines then
			local err_line = src_lines[line]
			print(err_line)
			local arrow = string.rep(" ", col - 1).."^"
			print(arrow)
		end
	end
	os.exit(1)
end

local d = 0
function debug(arg)
	d = d + 1
	print("DEBUG: "..d..(arg and " - "..tostring(arg) or ""))
end

table.unpack = unpack or table.unpack
local unpack = function(t)
	if type(t) == "table" and type(t.n) == "number" then
		return table.unpack(t, 1, t.n)
	end
	local i = 0
	for k, v in pairs(t) do
		if i < k then i = k end
	end
	return table.unpack(t, 1, i)
end
local pack = table.pack or function(...)
	return { n = select("#", ...), ... }
end

local bit={}if _VERSION=="Lua 5.1"or _VERSION=="Lua 5.2"then local floor=math.floor local function t32(n)return n%4294967296 end function bit.bnot(n)n=n%0x100000000 local r=0xFFFFFFFF-n if r>=0x80000000 then r=r-0x100000000 end return r end function bit.band(a,b)a,b=t32(a),t32(b)local r=0 local b=1 while a>0 and b>0 do if a%2==1 and b%2==1 then r=r+b end a=floor(a/2)b=floor(b/2)b=b*2 end return r end function bit.bor(a,b)a,b=t32(a),t32(b)local r=0 local v=1 while a>0 or b>0 do if a%2==1 or b%2==1 then r=r+v end a=floor(a/2)b=floor(b/2)v=v*2 end return r end function bit.bxor(a,b)a,b=t32(a),t32(b)local r=0 local v=1 while a>0 or b>0 do if(a%2==1)~=(b%2==1)then r=r+v end a=floor(a/2)b=floor(b/2)v=v*2 end return r end function bit.lshift(a,s)if s<0 then return bit.rshift(a,-s)end if s>=32 then return 0 end return t32(t32(a)*(2^s))end function bit.rshift(a,s)if s<0 then return bit.lshift(a,-s)end if s>=32 then return 0 end return floor(t32(a)/(2^s))end else bit=load([[local t={band=function(a,b)return a&b end,bor=function(a,b)return a|b end,bxor=function(a,b)return a~b end,bnot=function(a)return ~a end,lshift=function(a,b)return a<<b end,rshift=function(a,b)return a>>b end,}return t]])()end

function parser(code)
	local string_sub = string.sub
	local string_match = string.match
	local table_insert = table.insert
	local tonumber = tonumber

	local orig = code

	local function get_line_col_from_pos(pos)
		local line = 1
		local col = 1
		for i = 1, pos - 1 do
			if string_sub(orig, i, i) == "\n" then
				line = line + 1
				col = 1
			else
				col = col + 1
			end
		end
		return line, col
	end

	local function local_err(_err, token)
		if token and token.line then
			print(string.format("Error at line %d, column %d: %s", token.line, token.col, _err))
		elseif token and type(token) == "number" then
			local line, col = get_line_col_from_pos(token)
			print(string.format("Error at line %d, column %d: %s", line, col, _err))
			local src_lines = {}
			for l in string.gmatch(orig, "([^\n]*)\n?") do
				table.insert(src_lines, l)
			end
			if line <= #src_lines then
				local err_line = src_lines[line]
				print(err_line)
				local arrow = string.rep(" ", col - 1).."^"
				print(arrow)
			end
		else
			print("Error: ".._err)
		end
		os.exit(1)
	end

	local function tokenize(source)
		local tokens = {}
		local i = 1
		local len = #source
		local line = 1
		local col = 1

		local operators = {
			["=="] = true,
			["!="] = true,
			["<="] = true,
			[">="] = true,
			["<"] = true,
			[">"] = true,

			["+"] = true,
			["-"] = true,
			["*"] = true,
			["/"] = true,
			["%"] = true,
			["^"] = true,
			
			["#"] = true,
			["="] = true,
			
			["("] = true,
			[")"] = true,
			["["] = true,
			["]"] = true,
			["{"] = true,
			["}"] = true,
			[","] = true,
			[";"] = true,
			["."] = true,
			[":"] = true,
			[".."] = true,
			["~"] = true,
			["&"] = true,
			["|"] = true,
			["<<"] = true,
			[">>"] = true,
			["//"] = true,
		}

		local keywords = {
			["func"] = true,
			["return"] = true,
			["if"] = true,
			["elseif"] = true,
			["else"] = true,
			["while"] = true,
			["for"] = true,
			["do"] = true,
			["end"] = true,
			["break"] = true,
			["local"] = true,
			["null"] = true,
			["true"] = true,
			["false"] = true,
			["or"] = true,
			["and"] = true,
			["not"] = true
		}

		local function is_hex_digit(c)
			return string_match(c, "[0-9a-fA-F]")
		end

		local function skip_comment()
			local depth = 1
			i = i + 3
			col = col + 3
			while i <= len do
				if i <= len - 2 and string_sub(source, i, i + 2) == ">>>" then
					depth = depth - 1
					if depth == 0 then
						i = i + 3
						col = col + 3
						break
					end
					i = i + 3
					col = col + 3
				elseif i <= len - 2 and string_sub(source, i, i + 2) == "<<<" then
					depth = depth + 1
					i = i + 3
					col = col + 3
				else
					local char = string_sub(source, i, i)
					if char == "\n" then
						line = line + 1
						col = 1
					else
						col = col + 1
					end
					i = i + 1
				end
			end
			if depth > 0 then
				local_err("Unclosed comment starting at position "..(i - 3), i - 3)
			end
		end

		while i <= len do
			local char = string_sub(source, i, i)

			if char == "\n" then
				line = line + 1
				col = 1
				i = i + 1
			elseif string_match(char, "%s") then
				col = col + 1
				i = i + 1
			elseif i <= len - 2 and string_sub(source, i, i + 2) == "<<<" then
				skip_comment()
			elseif char == "'" or char == '"' then
				local start_i = i
				local start_line = line
				local start_col = col
				local quote = char
				i = i + 1
				col = col + 1

				while i <= len do
					local current = string_sub(source, i, i)
					if current == "\\" then
						i = i + 2
						col = col + 2
					elseif current == quote then
						break
					else
						i = i + 1
						col = col + 1
					end
				end

				if i > len then
					local_err("Unclosed string literal starting at position "..start_i, start_i)
				end

				table_insert(tokens, {
					type = "string",
					value = string_sub(source, start_i, i),
					start_pos = start_i,
					line = start_line,
					col = start_col
				})
				i = i + 1
				col = col + 1
			elseif string_match(char, "%d") then
				local start_i = i
				local start_line = line
				local start_col = col

				if char == "0" and i < len then
					local next_char = string_sub(source, i + 1, i + 1)
					if next_char == "x" or next_char == "X" then
						i = i + 2
						col = col + 2
						local hex_start = i
						while i <= len and is_hex_digit(string_sub(source, i, i)) do
							i = i + 1
							col = col + 1
						end
						if i == hex_start then
							local_err("Invalid hexadecimal number at position "..start_i, start_i)
						end
						local hex_str = string_sub(source, hex_start, i - 1)
						table_insert(tokens, {
							type = "number",
							value = tonumber(hex_str, 16),
							raw_value = "0x"..hex_str,
							is_hex = true,
							line = start_line,
							col = start_col
						})
					else
						while i <= len and string_match(string_sub(source, i, i), "%d") do
							i = i + 1
							col = col + 1
						end
						if i <= len and string_sub(source, i, i) == "." then
							local next_char = i + 1 <= len and string_sub(source, i + 1, i + 1) or ""
							if next_char ~= "." and string_match(next_char, "%d") then
								i = i + 1
								col = col + 1
								while i <= len and string_match(string_sub(source, i, i), "%d") do
									i = i + 1
									col = col + 1
								end
							end
						end
						local raw_value = string_sub(source, start_i, i - 1)
						table_insert(tokens, {
							type = "number",
							value = tonumber(raw_value) or raw_value,
							raw_value = raw_value,
							line = start_line,
							col = start_col
						})
					end
				else
					while i <= len and string_match(string_sub(source, i, i), "%d") do
						i = i + 1
						col = col + 1
					end
					if i <= len and string_sub(source, i, i) == "." then
						local next_char = i + 1 <= len and string_sub(source, i + 1, i + 1) or ""
						if next_char ~= "." and string_match(next_char, "%d") then
							i = i + 1
							col = col + 1
							while i <= len and string_match(string_sub(source, i, i), "%d") do
								i = i + 1
								col = col + 1
							end
						end
					end
					local raw_value = string_sub(source, start_i, i - 1)
					table_insert(tokens, {
						type = "number",
						value = tonumber(raw_value) or raw_value,
						raw_value = raw_value,
						line = start_line,
						col = start_col
					})
				end
			elseif string_match(char, "[%a_]") then
				local start_i = i
				local start_line = line
				local start_col = col

				while i <= len and string_match(string_sub(source, i, i), "[%w_]") do
					i = i + 1
					col = col + 1
				end

				local value = string_sub(source, start_i, i - 1)
				local token_type = keywords[value] and "keyword" or "identifier"

				table_insert(tokens, {
					type = token_type,
					value = value,
					line = start_line,
					col = start_col
				})
			else
				local start_line = line
				local start_col = col
				if i <= len - 1 and string_sub(source, i, i + 1) == ".." then
					table_insert(tokens, {
						type = "operator",
						value = "..",
						line = start_line,
						col = start_col
					})
					i = i + 2
					col = col + 2
				elseif i <= len - 1 then
					local op2 = string_sub(source, i, i + 1)
					if operators[op2] then
						table_insert(tokens, {
							type = "operator",
							value = op2,
							line = start_line,
							col = start_col
						})
						i = i + 2
						col = col + 2
					elseif operators[char] then
						table_insert(tokens, {
							type = "operator",
							value = char,
							line = start_line,
							col = start_col
						})
						i = i + 1
						col = col + 1
					else
						table_insert(tokens, {
							type = "unknown",
							value = char,
							line = start_line,
							col = start_col
						})
						i = i + 1
						col = col + 1
					end
				elseif operators[char] then
					table_insert(tokens, {
						type = "operator",
						value = char,
						line = start_line,
						col = start_col
					})
					i = i + 1
					col = col + 1
				else
					table_insert(tokens, {
						type = "unknown",
						value = char,
						line = start_line,
						col = start_col
					})
					i = i + 1
					col = col + 1
				end
			end
		end

		return tokens
	end

	local function build_ast(tokens)
		local ast = {
			type = "Program",
			body = {},
			source = orig
		}

		local i = 1
		local token_count = #tokens
		local UNARY_PRECEDENCE = 11

		local function current_token()
			return i <= token_count and tokens[i] or nil
		end

		local function peek_token(offset)
			offset = offset or 1
			return i + offset - 1 <= token_count and tokens[i + offset - 1] or nil
		end

		local function consume_token(expected_type, expected_value)
			local token = current_token()
			if not token then
				local_err("Unexpected end of input")
			end

			if expected_type and token.type ~= expected_type then
				local_err(
					string.format("Expected %s, got %s (value: %s)", expected_type, token.type, tostring(token.value)),
					token)
			end

			if expected_value and token.value ~= expected_value then
				local_err(string.format("Expected '%s', got '%s'", expected_value, token.value), token)
			end

			i = i + 1
			return token
		end

		local function match_token(token_type, token_value)
			local token = current_token()
			if token and token.type == token_type and (not token_value or token.value == token_value) then
				i = i + 1
				return token
			end
			return nil
		end

		local function parse_method_name()
			local obj = nil
			local method = nil
			local computed = false
			local start_line, start_col

			local obj_token = consume_token("identifier")
			obj = {
				type = "Identifier",
				name = obj_token.value,
				loc = { line = obj_token.line, col = obj_token.col }
			}
			start_line = obj_token.line
			start_col = obj_token.col

			if current_token() and (current_token().value == "." or current_token().value == "[") then
				if current_token().value == "." then
					consume_token("operator", ".")
					local method_token = consume_token("identifier")
					method = {
						type = "Identifier",
						name = method_token.value,
						loc = { line = method_token.line, col = method_token.col }
					}
					computed = false
				elseif current_token().value == "[" then
					consume_token("operator", "[")
					method = parse_expression()
					consume_token("operator", "]")
					computed = true
				end
			else
				local_err("Expected '.' or '[' after object name", current_token())
			end

			return {
				type = "MethodDeclaration",
				object = obj,
				method = method,
				computed = computed,
				loc = { line = start_line, col = start_col }
			}
		end

		local function parse_function_expression()
			local func_token = consume_token("keyword", "func")
			local params = {}
			local start_line, start_col = func_token.line, func_token.col

			if match_token("operator", "(") then
				if not match_token("operator", ")") then
					repeat
						local param_token = consume_token("identifier")
						table_insert(params, param_token.value)
						if not match_token("operator", ",") then
							break
						end
					until not current_token() or current_token().value == ")"
					consume_token("operator", ")")
				end
			end

			consume_token("keyword", "do")
			local body = parse_block()
			consume_token("keyword", "end")

			return {
				type = "FunctionExpression",
				parameters = params,
				body = body,
				loc = { line = start_line, col = start_col }
			}
		end

		function parse_expression(min_precedence)
			min_precedence = min_precedence or 0
			local token = current_token()

			if token and token.value == "func" then
				return parse_function_expression()
			end

			local left = parse_unary_expression()
			if not left then return nil end

			if min_precedence == 0 then
				token = current_token()
				if token and token.type == "operator" and token.value == "=" then
					local assign_token = consume_token("operator")
					local right = parse_expression(0)
					return {
						type = "AssignmentExpression",
						operator = "=",
						left = left,
						right = right,
						loc = { line = assign_token.line, col = assign_token.col }
					}
				end
			end

			return parse_binary_expression(left, min_precedence)
		end

		function parse_expression_list()
			local expressions = {}
			if not current_token() or current_token().value == ")" or current_token().value == "end" then
				return expressions
			end

			repeat
				local expr = parse_expression()
				if expr then
					table_insert(expressions, expr)
				end
				if not match_token("operator", ",") then
					break
				end
			until not current_token() or current_token().value == ")" or current_token().value == "end"

			return expressions
		end

		function parse_assignment_targets()
			local targets = {}
			if not current_token() then
				return targets
			end

			repeat
				local target = parse_primary_expression()
				if target then
					table_insert(targets, target)
				end
				if not match_token("operator", ",") then
					break
				end
			until not current_token() or current_token().value == "="

			return targets
		end

		function parse_primary_expression()
			local token = current_token()
			if not token then return nil end

			if token.type == "number" then
				local num_token = consume_token("number")
				return {
					type = "NumberLiteral",
					value = num_token.value,
					loc = { line = num_token.line, col = num_token.col }
				}
			elseif token.type == "string" then
				local str_token = consume_token("string")
				return {
					type = "StringLiteral",
					value = str_token.value,
					loc = { line = str_token.line, col = str_token.col }
				}
			elseif token.value == "null" then
				local null_token = consume_token("keyword", "null")
				return {
					type = "NullLiteral",
					loc = { line = null_token.line, col = null_token.col }
				}
			elseif token.value == "true" or token.value == "false" then
				local bool_token = consume_token("keyword")
				local value = bool_token.value == "true"
				return {
					type = "BooleanLiteral",
					value = value,
					loc = { line = bool_token.line, col = bool_token.col }
				}
			elseif token.type == "identifier" then
				local id_token = consume_token("identifier")
				local name = id_token.value
				local expr = {
					type = "Identifier",
					name = name,
					loc = { line = id_token.line, col = id_token.col }
				}

				while match_token("operator", "[") or match_token("operator", ".") do
					if tokens[i - 1].value == "[" then
						local index = parse_expression()
						local close_token = consume_token("operator", "]")

						if current_token() and current_token().type == "operator" and current_token().value == "(" then
							local open_paren = consume_token("operator", "(")
							local args = parse_expression_list()
							consume_token("operator", ")")
							expr = {
								type = "MethodCallExpression",
								object = expr,
								method = index,
								computed = true,
								arguments = args,
								loc = { line = open_paren.line, col = open_paren.col }
							}
						else
							expr = {
								type = "MemberExpression",
								object = expr,
								property = index,
								computed = true,
								loc = { line = close_token.line, col = close_token.col }
							}
						end
					else
						local prop_token = consume_token("identifier")

						if current_token() and current_token().type == "operator" and current_token().value == "(" then
							local open_paren = consume_token("operator", "(")
							local args = parse_expression_list()
							consume_token("operator", ")")
							expr = {
								type = "MethodCallExpression",
								object = expr,
								method = {
									type = "Identifier",
									name = prop_token.value,
									loc = { line = prop_token.line, col = prop_token.col }
								},
								computed = false,
								arguments = args,
								loc = { line = open_paren.line, col = open_paren.col }
							}
						else
							expr = {
								type = "MemberExpression",
								object = expr,
								property = {
									type = "Identifier",
									name = prop_token.value,
									loc = { line = prop_token.line, col = prop_token.col }
								},
								computed = false,
								loc = { line = prop_token.line, col = prop_token.col }
							}
						end
					end
				end

				if match_token("operator", "(") then
					local args = parse_expression_list()
					consume_token("operator", ")")
					expr = {
						type = "CallExpression",
						callee = expr,
						arguments = args,
						loc = { line = id_token.line, col = id_token.col }
					}
				end

				return expr
			elseif match_token("operator", "{") then
				local open_token = tokens[i - 1]
				local elements = {}
				local fields = {}

				if not match_token("operator", "}") then
					repeat
						local key = nil
						local value = nil
						local is_key_value = false

						local saved_i = i

						if current_token() and current_token().type == "operator" and current_token().value == "[" then
							consume_token("operator", "[")
							key = parse_expression()
							consume_token("operator", "]")
							if current_token() and current_token().type == "operator" and current_token().value == "=" then
								consume_token("operator", "=")
								value = parse_expression()
								is_key_value = true
							else
								i = saved_i
								key = nil
							end
						elseif current_token() and current_token().type == "identifier" then
							local next_token = peek_token(2)
							if next_token and next_token.type == "operator" and next_token.value == "=" then
								local id_token = consume_token("identifier")
								key = {
									type = "StringLiteral",
									value = '"'..id_token.value..'"',
									loc = { line = id_token.line, col = id_token.col }
								}
								consume_token("operator", "=")
								value = parse_expression()
								is_key_value = true
							end
						end

						if is_key_value then
							table_insert(fields, {
								key = key,
								value = value
							})
						else
							local elem = parse_expression()
							if elem then
								table_insert(elements, elem)
							end
						end

						if not (current_token() and (current_token().value == ";" or current_token().value == ",")) then
							break
						end
						if current_token().value == ";" then
							consume_token("operator", ";")
						elseif current_token().value == "," then
							consume_token("operator", ",")
						end
					until not current_token() or current_token().value == "}"
					consume_token("operator", "}")
				end

				return {
					type = "TableLiteral",
					elements = elements,
					fields = fields,
					loc = { line = open_token.line, col = open_token.col }
				}
			elseif match_token("operator", "(") then
				local open_token = tokens[i - 1]
				local expr = parse_expression()
				local close_token = consume_token("operator", ")")
				if expr then
					expr.loc = expr.loc or { line = open_token.line, col = open_token.col }
				end
				return expr
			end

			return nil
		end

		function parse_unary_expression()
			local token = current_token()

			if token and token.type == "keyword" and token.value == "not" then
				local op_token = consume_token("keyword", "not")
				local argument = parse_expression(UNARY_PRECEDENCE)
				return {
					type = "UnaryExpression",
					operator = "not",
					argument = argument,
					loc = { line = op_token.line, col = op_token.col }
				}
			end

			if token and token.type == "operator" and (token.value == "-" or token.value == "#" or token.value == "~") then
				local op_token = consume_token("operator")
				local argument = parse_expression(UNARY_PRECEDENCE)
				return {
					type = "UnaryExpression",
					operator = op_token.value,
					argument = argument,
					loc = { line = op_token.line, col = op_token.col }
				}
			end

			return parse_primary_expression()
		end

		function parse_binary_expression(left, min_precedence)
			local precedences = {
				["or"] = 1,
				["and"] = 2,

				["=="] = 3,
				["!="] = 3,
				["<"] = 3,
				[">"] = 3,
				["<="] = 3,
				[">="] = 3,

				["|"] = 4,
				["~"] = 5,
				["&"] = 6,
				["<<"] = 7,
				[">>"] = 7,

				[".."] = 8,

				["+"] = 9,
				["-"] = 9,
				["*"] = 10,
				["/"] = 10,
				["%"] = 10,
				["//"] = 10,

				["^"] = 12,
			}

			while true do
				local lookahead = current_token()
				if not lookahead then break end

				local op, prec

				if lookahead.type == "operator" and precedences[lookahead.value] then
					op = lookahead.value
					prec = precedences[op]
				elseif lookahead.type == "keyword" and (lookahead.value == "and" or lookahead.value == "or") then
					op = lookahead.value
					prec = precedences[op]
				else
					break
				end

				if prec < min_precedence then break end

				local operator_token
				if lookahead.type == "operator" then
					operator_token = consume_token("operator")
				else
					operator_token = consume_token("keyword")
				end

				local right = parse_unary_expression()
				if not right then break end

				local next_min = prec + 1
				if op == "^" then
					next_min = prec
				end

				right = parse_binary_expression(right, next_min)

				left = {
					type = "BinaryExpression",
					operator = op,
					left = left,
					right = right,
					loc = { line = operator_token.line, col = operator_token.col }
				}
			end

			return left
		end

		function parse_block()
			local body = {}
			while current_token() and current_token().value ~= "end" do
				local stmt = parse_statement()
				if stmt then
					table_insert(body, stmt)
				else
					break
				end
			end
			return body
		end

		local function parse_method_path()
			local path = {}
			local start_line, start_col

			local first_token = consume_token("identifier")
			local current = {
				type = "Identifier",
				name = first_token.value,
				loc = { line = first_token.line, col = first_token.col }
			}
			start_line = first_token.line
			start_col = first_token.col

			while current_token() and (current_token().value == "." or current_token().value == "[") do
				if current_token().value == "." then
					consume_token("operator", ".")
					local prop_token = consume_token("identifier")
					local prop = {
						type = "Identifier",
						name = prop_token.value,
						loc = { line = prop_token.line, col = prop_token.col }
					}
					table_insert(path, {
						type = "member",
						computed = false,
						property = prop
					})
				elseif current_token().value == "[" then
					consume_token("operator", "[")
					local index = parse_expression()
					consume_token("operator", "]")
					table_insert(path, {
						type = "member",
						computed = true,
						property = index
					})
				end
			end

			if #path == 0 then
				local_err("Expected method name after object", current_token())
			end

			local object = current
			for i = 1, #path - 1 do
				local member = path[i]
				if member.computed then
					object = {
						type = "MemberExpression",
						object = object,
						property = member.property,
						computed = true,
						loc = member.property.loc or { line = start_line, col = start_col }
					}
				else
					object = {
						type = "MemberExpression",
						object = object,
						property = member.property,
						computed = false,
						loc = member.property.loc or { line = start_line, col = start_col }
					}
				end
			end

			local last_member = path[#path]
			local method_name
			local computed = last_member.computed

			if computed then
				method_name = last_member.property
			else
				method_name = last_member.property
			end

			return {
				type = "MethodDeclaration",
				object = object,
				method = method_name,
				computed = computed,
				loc = { line = start_line, col = start_col }
			}
		end

		function parse_statement()
			local token = current_token()
			if not token then return nil end

			if token.value == "func" then
				local func_token = consume_token("keyword", "func")

				local saved_i = i
				local next_token = current_token()

				local is_method = false
				if next_token and next_token.type == "identifier" then
					local temp_i = i

					local id_token = consume_token("identifier")
					if current_token() and (current_token().value == "." or current_token().value == "[") then
						is_method = true
					end

					i = saved_i
				end

				if is_method then
					local method_decl = parse_method_path()
					local params = {}

					consume_token("operator", "(")
					if not match_token("operator", ")") then
						repeat
							local param_token = consume_token("identifier")
							table_insert(params, param_token.value)
							if not match_token("operator", ",") then
								break
							end
						until not current_token() or current_token().value == ")"
						consume_token("operator", ")")
					end

					consume_token("keyword", "do")
					local body = parse_block()
					consume_token("keyword", "end")

					return {
						type = "MethodDeclaration",
						object = method_decl.object,
						method = method_decl.method,
						computed = method_decl.computed,
						parameters = params,
						body = body,
						loc = { line = func_token.line, col = func_token.col }
					}
				else
					local name_token = consume_token("identifier")
					local name = name_token.value
					local params = {}

					consume_token("operator", "(")
					if not match_token("operator", ")") then
						repeat
							local param_token = consume_token("identifier")
							table_insert(params, param_token.value)
							if not match_token("operator", ",") then
								break
							end
						until not current_token() or current_token().value == ")"
						consume_token("operator", ")")
					end

					consume_token("keyword", "do")
					local body = parse_block()
					consume_token("keyword", "end")

					return {
						type = "FunctionDeclaration",
						name = name,
						parameters = params,
						body = body,
						loc = { line = func_token.line, col = func_token.col }
					}
				end
			elseif token.value == "local" then
				local local_token = consume_token("keyword", "local")
				local declarations = {}
				local name_token = consume_token("identifier")
				local current_decl = {
					name = name_token.value,
					value = nil,
					loc = { line = name_token.line, col = name_token.col }
				}
				table_insert(declarations, current_decl)
				while match_token("operator", ",") do
					name_token = consume_token("identifier")
					current_decl = {
						name = name_token.value,
						value = nil,
						loc = { line = name_token.line, col = name_token.col }
					}
					table_insert(declarations, current_decl)
				end
				local values = {}
				if match_token("operator", "=") then
					repeat
						local value = parse_expression()
						if value then table_insert(values, value) end
						if not match_token("operator", ",") then break end
					until not current_token() or (current_token().value ~= "," and current_token().value ~= "=")
				end
				return {
					type = "VariableDeclaration",
					kind = "local",
					declarations = declarations,
					values = values,
					loc = { line = local_token.line, col = local_token.col }
				}
			elseif token.value == "if" then
				local if_token = consume_token("keyword", "if")
				local stmt = {
					type = "IfStatement",
					test = parse_expression(),
					consequent = {},
					alternate = nil,
					loc = { line = if_token.line, col = if_token.col }
				}
				consume_token("keyword", "do")
				while current_token() and current_token().value ~= "else" and current_token().value ~= "elseif" and current_token().value ~= "end" do
					local child_stmt = parse_statement()
					if child_stmt then
						table_insert(stmt.consequent, child_stmt)
					else
						break
					end
				end
				while current_token() and (current_token().value == "elseif" or current_token().value == "else") do
					if current_token().value == "elseif" then
						local elseif_token = consume_token("keyword", "elseif")
						local elseif_test = parse_expression()
						consume_token("keyword", "do")
						local elseif_body = {}
						while current_token() and current_token().value ~= "else" and
							current_token().value ~= "elseif" and current_token().value ~= "end" do
							local child_stmt = parse_statement()
							if child_stmt then
								table_insert(elseif_body, child_stmt)
							else
								break
							end
						end
						local elseif_stmt = {
							type = "IfStatement",
							test = elseif_test,
							consequent = elseif_body,
							alternate = nil,
							loc = { line = elseif_token.line, col = elseif_token.col }
						}
						local last = stmt
						while last.alternate do
							last = last.alternate
						end
						last.alternate = elseif_stmt
					else
						local else_token = consume_token("keyword", "else")
						local else_body = {}
						while current_token() and current_token().value ~= "end" do
							local child_stmt = parse_statement()
							if child_stmt then
								table_insert(else_body, child_stmt)
							else
								break
							end
						end
						local last = stmt
						while last.alternate do
							last = last.alternate
						end
						last.alternate = {
							type = "BlockStatement",
							body = else_body,
							loc = { line = else_token.line, col = else_token.col }
						}
						break
					end
				end
				consume_token("keyword", "end")
				return stmt
			elseif token.value == "while" then
				local while_token = consume_token("keyword", "while")
				local condition = parse_expression()
				consume_token("keyword", "do")
				local body = parse_block()
				consume_token("keyword", "end")
				return {
					type = "WhileStatement",
					condition = condition,
					body = body,
					loc = { line = while_token.line, col = while_token.col }
				}
			elseif token.value == "for" then
				local for_token = consume_token("keyword", "for")
				local var_token = consume_token("identifier")
				consume_token("operator", "=")
				local start_expr = parse_expression()
				if not start_expr then
					local_err("Missing start expression in for loop", current_token())
				end
				consume_token("operator", ",")
				local end_expr = parse_expression()
				if not end_expr then
					local_err("Missing end expression in for loop", current_token())
				end
				local step_expr = nil
				if match_token("operator", ",") then
					step_expr = parse_expression()
				end
				consume_token("keyword", "do")
				local body = parse_block()
				consume_token("keyword", "end")
				return {
					type = "ForStatement",
					variable = var_token.value,
					start = start_expr,
					finish = end_expr,
					step = step_expr,
					body = body,
					loc = { line = for_token.line, col = for_token.col }
				}
			elseif token.value == "return" then
				local return_token = consume_token("keyword", "return")
				local return_values = parse_expression_list()
				return {
					type = "ReturnStatement",
					values = return_values,
					loc = { line = return_token.line, col = return_token.col }
				}
			elseif token.value == "break" then
				local break_token = consume_token("keyword", "break")
				return {
					type = "BreakStatement",
					loc = { line = break_token.line, col = break_token.col }
				}
			elseif match_token("keyword", "do") then
				local do_token = tokens[i - 1]
				local body = parse_block()
				consume_token("keyword", "end")
				return {
					type = "BlockStatement",
					body = body,
					loc = { line = do_token.line, col = do_token.col }
				}
			end

			local saved_i = i
			local targets = parse_assignment_targets()

			if #targets > 0 and match_token("operator", "=") then
				local values = parse_expression_list()
				return {
					type = "AssignmentStatement",
					left = targets,
					right = values,
					loc = { line = targets[1].loc.line, col = targets[1].loc.col }
				}
			end

			i = saved_i
			local expr = parse_expression()
			if expr then
				return {
					type = "ExpressionStatement",
					expression = expr,
					loc = expr.loc
				}
			end
			return nil
		end

		while i <= token_count do
			local stmt = parse_statement()
			if stmt then
				table_insert(ast.body, stmt)
			else
				i = i + 1
			end
		end
		return ast
	end

	local tokens = tokenize(code)
	local ast = build_ast(tokens)
	return ast, tokens, code
end

function create_interpreter()
	local interpreter = {}

	local environment = {
		globals = {},
		locals_stack = { {} },
		functions = {},
		builtins = {},
		break_flag = false,
		return_values = nil,
		has_return = false,
		call_stack = {}
	}

	environment.builtins.math = {
		abs = function(x) return math.abs(x[1] or 0) end,
		acos = function(x) return math.acos(x[1] or 0) end,
		asin = function(x) return math.asin(x[1] or 0) end,
		atan = function(x) return math.atan(x[1] or 0) end,
		atan2 = function(y, x) return math.atan2(y[1] or 0, x[1] or 0) end,
		ceil = function(x) return math.ceil(x[1] or 0) end,
		cos = function(x) return math.cos(x[1] or 0) end,
		cosh = function(x) return math.cosh(x[1] or 0) end,
		deg = function(x) return math.deg(x[1] or 0) end,
		exp = function(x) return math.exp(x[1] or 0) end,
		floor = function(x) return math.floor(x[1] or 0) end,
		fmod = function(x, y) return math.fmod(x[1] or 0, y[1] or 0) end,
		frexp = function(x)
			local m, e = math.frexp(x[1] or 0)
			return { m, e }
		end,
		ldexp = function(m, e) return math.ldexp(m[1] or 0, e[1] or 0) end,
		log = function(x) return math.log(x[1] or 0) end,
		log10 = function(x) return math.log10(x[1] or 0) end,
		max = function(...)
			local args = { ... }
			local max_val = -math.huge
			for i, arg in ipairs(args) do
				local val = arg[1] or -math.huge
				if val > max_val then max_val = val end
			end
			return max_val
		end,
		min = function(...)
			local args = { ... }
			local min_val = math.huge
			for i, arg in ipairs(args) do
				local val = arg[1] or math.huge
				if val < min_val then min_val = val end
			end
			return min_val
		end,
		modf = function(x)
			local int, frac = math.modf(x[1] or 0)
			return { int, frac }
		end,
		pow = function(x, y) return math.pow(x[1] or 0, y[1] or 0) end,
		rad = function(x) return math.rad(x[1] or 0) end,
		random = function(m, n)
			if m and n then
				return math.random(m[1] or 1, n[1] or m[1])
			elseif m then
				return math.random(m[1] or 1)
			else
				return math.random()
			end
		end,
		randomseed = function(x)
			math.randomseed(x[1] or os.time())
			return nil
		end,
		sin = function(x) return math.sin(x[1] or 0) end,
		sinh = function(x) return math.sinh(x[1] or 0) end,
		sqrt = function(x) return math.sqrt(x[1] or 0) end,
		tan = function(x) return math.tan(x[1] or 0) end,
		tanh = function(x) return math.tanh(x[1] or 0) end,
		pi = math.pi,
		huge = math.huge
	}

	environment.builtins.string = {
		byte = function(s, i, j)
			return string.byte(s[1] or "", (i and i[1]) or 1, (j and j[1]) or (i and i[1]) or 1)
		end,
		char = function(...)
			local args = { ... }
			local codes = {}
			for i, arg in ipairs(args) do
				codes[i] = arg[1] or 0
			end
			return string.char(unpack(codes))
		end,
		find = function(s, pattern, init, plain)
			return string.find(s[1] or "", pattern[1] or "", (init and init[1]) or 1, (plain and plain[1]) or false)
		end,
		format = function(...)
			local args = { ... }
			local format_str = args[1][1] or ""
			local format_args = {}
			for i = 2, #args do
				format_args[i - 1] = args[i][1]
			end
			return string.format(format_str, unpack(format_args))
		end,
		gmatch = function(s, pattern)
			local str = s[1] or ""
			local pat = pattern[1] or ""
			local iterator = string.gmatch(str, pat)
			local result = iterator()
			return result or ""
		end,
		gsub = function(s, pattern, repl, n)
			return string.gsub(s[1] or "", pattern[1] or "", repl[1] or "", (n and n[1]) or 0)
		end,
		len = function(s) return #(s[1] or "") end,
		lower = function(s) return string.lower(s[1] or "") end,
		match = function(s, pattern, init)
			return string.match(s[1] or "", pattern[1] or "", (init and init[1]) or 1)
		end,
		rep = function(s, n) return string.rep(s[1] or "", n[1] or 0) end,
		reverse = function(s) return string.reverse(s[1] or "") end,
		sub = function(s, i, j)
			return string.sub(s[1] or "", (i and i[1]) or 1, (j and j[1]) or -1)
		end,
		upper = function(s) return string.upper(s[1] or "") end
	}

	environment.builtins.table = {
		insert = function(t, pos, value)
			local tbl = {}
			local old_tbl = t[1] or {}
			for k, v in pairs(old_tbl) do
				tbl[k] = v
			end
			if value then
				table.insert(tbl, pos[1] or #tbl + 1, value[1])
			else
				table.insert(tbl, pos[1])
			end
			return tbl
		end,
		remove = function(t, pos)
			local tbl = {}
			local old_tbl = t[1] or {}
			for k, v in pairs(old_tbl) do
				tbl[k] = v
			end
			if pos then
				table.remove(tbl, pos[1])
			else
				table.remove(tbl)
			end
			return tbl
		end,
		concat = function(t, sep, i, j)
			local tbl = t[1] or {}
			return table.concat(tbl, (sep and sep[1]) or "", (i and i[1]) or 1, (j and j[1]) or #tbl)
		end,
		sort = function(t, comp)
			local tbl = {}
			local old_tbl = t[1] or {}
			for k, v in pairs(old_tbl) do
				tbl[k] = v
			end
			if comp then
				local comp_func = function(a, b)
					return comp[1]({ a }, { b }) == true
				end
				table.sort(tbl, comp_func)
			else
				table.sort(tbl)
			end
			return tbl
		end,
		pack = function(...)
			local args = { ... }
			local result = {}
			for i, arg in ipairs(args) do
				result[i] = arg[1]
			end
			result.n = #args
			return result
		end,
		unpack = function(t, i, j)
			local tbl = t[1] or {}
			return unpack(tbl, (i and i[1]) or 1, (j and j[1]) or #tbl)
		end
	}

	environment.builtins.print = function(...)
		local args = { ... }
		local str_args = {}
		for i, arr in ipairs(args) do
			local v = arr[1]
			if v == nil then
				str_args[i] = "null"
			elseif type(v) == "boolean" then
				str_args[i] = v and "true" or "false"
			elseif type(v) == "table" then
				if v.type == "NumberLiteral" then
					str_args[i] = tostring(v.value)
				elseif v.type == "Function" then
					str_args[i] = "function"
				else
					str_args[i] = "table: "..tostring(#v).." element"..(#v ~= 1 and "s" or "")
				end
			elseif type(v) == "string" then
				str_args[i] = v
			elseif type(v) == "function" then
				str_args[i] = "function"
			else
				str_args[i] = tostring(v)
			end
		end
		_G.print(unpack(str_args))
		return nil
	end

	environment.builtins.tonumber = function(x, base)
		if type(x[1]) == "number" then return x[1] end
		if type(x[1]) == "string" then
			local n = tonumber(x[1], (base and base[1]) or 10)
			return n or 0
		end
		return 0
	end

	environment.builtins.tostring = function(x)
		if type(x[1]) == "string" then return x[1] end
		if x[1] == nil then return "null" end
		return tostring(x[1])
	end

	environment.builtins.type = function(x)
		if x == nil then return "null" end
		local val = x[1]
		if type(val) == "table" then
			if val.type == "Function" then
				return "function"
			end
			return "table"
		else
			local k = type(val)
			return (k=="nil")and"null"or k
		end
	end

	environment.builtins.pairs = function(t)
		local tbl = t[1] or {}
		return function(tbl, k)
			local next_k, next_v = next(tbl, k)
			if next_k ~= nil then
				return next_k, next_v
			end
			return nil
		end, tbl, nil
	end

	environment.builtins.ipairs = function(t)
		local tbl = t[1] or {}
		local i = 0
		return function()
			i = i + 1
			local v = tbl[i]
			if v ~= nil then
				return i, v
			end
			return nil
		end
	end

	environment.builtins.next = function(t, k)
		local tbl = t[1] or {}
		return next(tbl, (k and k[1]) or nil)
	end

	environment.builtins.rawequal = function(a, b)
		return rawequal(a[1], b[1])
	end

	environment.builtins.rawget = function(t, k)
		local tbl = t[1] or {}
		return rawget(tbl, k[1])
	end

	environment.builtins.rawset = function(t, k, v)
		local tbl = t[1] or {}
		rawset(tbl, k[1], v[1])
		return tbl
	end

	environment.builtins.select = function(index, ...)
		local args = { ... }
		if type(index[1]) == "number" then
			local idx = index[1]
			if idx > 0 then
				local result = {}
				for i = idx, #args do
					result[i - idx + 1] = args[i][1]
				end
				return unpack(result)
			else
				return #args
			end
		elseif index[1] == "#" then
			return #args
		end
		return nil
	end

	environment.builtins.os = {
		clock = function() return os.clock() end,
		date = function(format, time)
			return os.date((format and format[1]) or "%c", (time and time[1]) or os.time())
		end,
		difftime = function(t2, t1) return os.difftime(t2[1] or 0, t1[1] or 0) end,
		time = function(t) return os.time(t and t[1] or nil) end,
		tmpname = function() return os.tmpname() end
	}

	environment.builtins.io = {
		write = function(...)
			local args = { ... }
			for i, arg in ipairs(args) do
				io.write(tostring(arg[1] or ""))
			end
			return nil
		end,
		read = function(format)
			return io.read((format and format[1]) or "*l")
		end,
		type = function(file)
			return io.type(file[1])
		end
	}

	environment.globals.math = environment.builtins.math
	environment.globals.string = environment.builtins.string
	environment.globals.table = environment.builtins.table
	environment.globals.os = environment.builtins.os
	environment.globals.io = environment.builtins.io

	local function runtime_error(msg, node)
		local loc = node and node.loc
		if loc then
			print(string.format("Runtime error at line %d, column %d: %s", loc.line, loc.col, msg))
		else
			print("Runtime error: "..msg)
		end

		if #environment.call_stack > 0 then
			print("Call stack:")
			for i = #environment.call_stack, 1, -1 do
				local frame = environment.call_stack[i]
				print(string.format("  %d: function '%s' called from line %d, column %d",
					i, frame.name or "?", frame.line or 0, frame.col or 0))
			end
		end
		os.exit(1)
	end

	local function set_variable(name, value, is_local)
		if is_local then
			environment.locals_stack[#environment.locals_stack][name] = value
		else
			for i = #environment.locals_stack, 1, -1 do
				if environment.locals_stack[i][name] ~= nil then
					environment.locals_stack[i][name] = value
					return
				end
			end
			environment.globals[name] = value
		end
	end

	local function get_variable(name)
		for i = #environment.locals_stack, 1, -1 do
			if environment.locals_stack[i][name] ~= nil then
				return environment.locals_stack[i][name]
			end
		end
		if environment.globals[name] ~= nil then
			return environment.globals[name]
		end
		return environment.builtins[name]
	end

	local function evaluate_expression_list(expressions)
		local results = { n = 0 }
		local count = #expressions

		for i, expr in ipairs(expressions) do
			if i == count then
				local vals = pack(evaluate_expression(expr))
				for j = 1, vals.n do
					results.n = results.n + 1
					results[results.n] = vals[j]
				end
			else
				results.n = results.n + 1
				results[results.n] = evaluate_expression(expr)
			end
		end

		return results
	end

	function evaluate_expression(node)
		if not node then return nil end

		if node.type == "NumberLiteral" then
			return node.value
		elseif node.type == "StringLiteral" then
			return string.sub(node.value, 2, -2)
		elseif node.type == "BooleanLiteral" then
			return node.value
		elseif node.type == "NullLiteral" then
			return nil
		elseif node.type == "Identifier" then
			local val = get_variable(node.name)
			return val
		elseif node.type == "TableLiteral" then
			local table = {}
			for i, elem in ipairs(node.elements) do
				table[i] = evaluate_expression(elem)
			end
			for _, field in ipairs(node.fields) do
				local key = evaluate_expression(field.key)
				if type(key) == "string" then
					local num_key = tonumber(key)
					if num_key then
						key = num_key
					end
				end
				table[key] = evaluate_expression(field.value)
			end
			return table
		elseif node.type == "MemberExpression" then
			local object = evaluate_expression(node.object)
			local property
			if node.computed then
				property = evaluate_expression(node.property)
				if type(property) == "string" then
					property = tonumber(property) or property
				end
			else
				property = node.property.name
			end
			if type(object) ~= "table" then
				runtime_error("Attempt to index a non-table value", node)
			end
			return object[property]
		elseif node.type == "MethodCallExpression" then
			local object = evaluate_expression(node.object)
			if type(object) ~= "table" then
				runtime_error("Attempt to call method on a non-table value", node)
			end

			local method_name
			if node.computed then
				method_name = evaluate_expression(node.method)
			else
				method_name = node.method.name
			end

			local method = object[method_name]
			if not method then
				runtime_error("Method '"..tostring(method_name).."' not found", node)
			end

			table.insert(environment.call_stack, {
				name = tostring(method_name),
				line = node.loc and node.loc.line or 0,
				col = node.loc and node.loc.col or 0
			})

			table.insert(environment.locals_stack, {})

			local raw = evaluate_expression_list(node.arguments)
			local args = {}
			for i = 1, raw.n do
				args[i] = { raw[i] }
			end

			local results
			if type(method) == "function" then
				results = { method(unpack(args)) }
			elseif method.type == "Function" then
				for i, param in ipairs(method.parameters) do
					environment.locals_stack[#environment.locals_stack][param] = args[i] and args[i][1]
				end

				environment.has_return = false
				environment.return_values = nil
				for _, stmt in ipairs(method.body) do
					execute_statement(stmt)
					if environment.has_return or environment.break_flag then
						break
					end
				end
				results = environment.return_values
				environment.has_return = false
				environment.return_values = nil
			else
				runtime_error("Called object is not a function", node)
			end

			table.remove(environment.locals_stack)
			table.remove(environment.call_stack)

			if results and #results == 1 then
				return results[1]
			elseif results and #results > 1 then
				return unpack(results)
			end
			return nil
		elseif node.type == "CallExpression" then
			local callee
			if node.callee.type == "Identifier" then
				callee = node.callee.name
				if environment.builtins[callee] then
					local raw = evaluate_expression_list(node.arguments)
					local args = {}
					for i = 1, raw.n do
						args[i] = { raw[i] }
					end
					return environment.builtins[callee](unpack(args))
				end
				local func = environment.functions[callee] or get_variable(callee)
				if not func then
					runtime_error("Function '"..tostring(callee).."' not found", node)
				elseif not func.parameters then
					runtime_error("Attempt to call a non-function '"..tostring(callee).."'", node)
				end

				table.insert(environment.call_stack, {
					name = callee,
					line = node.loc and node.loc.line or 0,
					col = node.loc and node.loc.col or 0
				})
				table.insert(environment.locals_stack, {})

				local args = evaluate_expression_list(node.arguments)

				for i, param in ipairs(func.parameters) do
					environment.locals_stack[#environment.locals_stack][param] = args[i]
				end

				environment.has_return = false
				environment.return_values = nil
				for _, stmt in ipairs(func.body) do
					execute_statement(stmt)
					if environment.has_return or environment.break_flag then
						break
					end
				end
				table.remove(environment.locals_stack)
				table.remove(environment.call_stack)
				local return_vals = environment.return_values
				environment.has_return = false
				environment.return_values = nil
				if return_vals and return_vals.n > 0 then
					return unpack(return_vals)
				end
				return nil
			else
				callee = evaluate_expression(node.callee)
				if type(callee) ~= "table" or callee.type ~= "Function" then
					runtime_error("Called object is not a function", node)
				end

				table.insert(environment.call_stack, {
					name = "<anonymous>",
					line = node.loc and node.loc.line or 0,
					col = node.loc and node.loc.col or 0
				})
				table.insert(environment.locals_stack, {})

				local args = {}
				for i, arg_node in ipairs(node.arguments) do
					args[i] = evaluate_expression(arg_node)
				end

				for i, param in ipairs(callee.parameters) do
					environment.locals_stack[#environment.locals_stack][param] = args[i]
				end

				environment.has_return = false
				environment.return_values = nil
				for _, stmt in ipairs(callee.body) do
					execute_statement(stmt)
					if environment.has_return or environment.break_flag then
						break
					end
				end
				table.remove(environment.locals_stack)
				table.remove(environment.call_stack)
				local return_vals = environment.return_values
				environment.has_return = false
				environment.return_values = nil
				if return_vals and return_vals.n > 0 then
					return unpack(return_vals)
				end
				return nil
			end
		elseif node.type == "BinaryExpression" then
			local left = evaluate_expression(node.left)
			local right = evaluate_expression(node.right)
			if node.operator == "+" then
				return (tonumber(left) or 0) + (tonumber(right) or 0)
			elseif node.operator == "-" then
				return (tonumber(left) or 0) - (tonumber(right) or 0)
			elseif node.operator == "*" then
				return (tonumber(left) or 0) * (tonumber(right) or 0)
			elseif node.operator == "/" then
				local r = tonumber(right) or 0
				if r == 0 then runtime_error("Division by zero", node) end
				return (tonumber(left) or 0) / r
			elseif node.operator == "%" then
				return (tonumber(left) or 0) % (tonumber(right) or 0)
			elseif node.operator == "^" then
				return (tonumber(left) or 0) ^ (tonumber(right) or 0)
			elseif node.operator == ".." then
				local t1, t2 = type(left), type(right)
				left = left or node.left.name
				right = right or node.right.name
				if t1 == "table" and t2 == "table" then
					for k, v in pairs(right) do table.insert(left, v) end
					return left
				elseif t1 == "table" then
					table.insert(left, right)
					return left
				elseif t2 == "table" then
					return tostring(left)..tostring(node.right.name or "")
				end
				left = tostring(left):gsub("nil", "null")
				right = tostring(right):gsub("nil", "null")
				return left..right
			elseif node.operator == "==" then
				return left == right
			elseif node.operator == "!=" then
				return left ~= right
			elseif node.operator == "<" then
				return (tonumber(left) or 0) < (tonumber(right) or 0)
			elseif node.operator == ">" then
				return (tonumber(left) or 0) > (tonumber(right) or 0)
			elseif node.operator == "<=" then
				return (tonumber(left) or 0) <= (tonumber(right) or 0)
			elseif node.operator == ">=" then
				return (tonumber(left) or 0) >= (tonumber(right) or 0)
			elseif node.operator == "and" then
				if not left then return left end
				return right
			elseif node.operator == "or" then
				if left then return left end
				return right
			elseif node.operator == "~" then
				return bit.bxor(left, right)
			elseif node.operator == "&" then
				return bit.band(left, right)
			elseif node.operator == "|" then
				return bit.bor(left, right)
			elseif node.operator == ">>" then
				return bit.rshift(left, right)
			elseif node.operator == "<<" then
				return bit.lshift(left, right)
			end
		elseif node.type == "UnaryExpression" then
			local argument = evaluate_expression(node.argument)
			if node.operator == "-" then
				return -(tonumber(argument) or 0)
			elseif node.operator == "#" then
				local size
				local t = type(argument)
				if t == "number" then
					size = #tostring(argument)
				elseif t == "boolean" then
					size = argument and 1 or -1
				elseif t == "nil" then
					size = 0
				else
					size = #argument
				end
				return size
			elseif node.operator == "~" then
				return bit.bnot(tonumber(argument) or 0)
			elseif node.operator == "not" then
				return not argument
			end
			return argument
		elseif node.type == "AssignmentExpression" then
			local right = evaluate_expression(node.right)
			if node.left.type == "Identifier" then
				set_variable(node.left.name, right, false)
				if right and (type(right) ~= "number" and type(right) ~= "boolean") and right.type == "Function" then
					environment.functions[node.left.name] = {
						parameters = right.parameters,
						body = right.body
					}
				end
				return right
			elseif node.left.type == "MemberExpression" then
				local object = evaluate_expression(node.left.object)
				local prop
				if node.left.computed then
					prop = evaluate_expression(node.left.property)
				else
					prop = node.left.property.name
				end
				if type(object) ~= "table" then
					runtime_error("Attempt to assign property to a non-table value", node)
				end
				object[prop] = right
				return right
			end
		elseif node.type == "FunctionExpression" then
			return {
				type = "Function",
				parameters = node.parameters,
				body = node.body
			}
		end
		return nil
	end

	function execute_statement(node)
		if not node then return end
		if node.type == "VariableDeclaration" then
			local values = evaluate_expression_list(node.values or {})
			for i, decl in ipairs(node.declarations) do
				set_variable(decl.name, values[i], node.kind == "local")
			end
		elseif node.type == "AssignmentStatement" then
			local values = evaluate_expression_list(node.right)
			for i, left_node in ipairs(node.left) do
				local value = values[i]
				if left_node.type == "Identifier" then
					set_variable(left_node.name, value, false)
					if value and (type(value) ~= "number" and type(value) ~= "boolean") and value.type == "Function" then
						environment.functions[left_node.name] = {
							parameters = value.parameters,
							body = value.body
						}
					end
				elseif left_node.type == "MemberExpression" then
					local object = evaluate_expression(left_node.object)
					local prop
					if left_node.computed then
						prop = evaluate_expression(left_node.property)
					else
						prop = left_node.property.name
					end
					if type(object) ~= "table" then
						runtime_error("Attempt to assign property to a non-table value", node)
					end
					object[prop] = value
				end
			end
		elseif node.type == "ExpressionStatement" then
			evaluate_expression(node.expression)
		elseif node.type == "FunctionDeclaration" then
			environment.functions[node.name] = {
				type = "Function",
				parameters = node.parameters,
				body = node.body
			}
			set_variable(node.name, {
				type = "Function",
				parameters = node.parameters,
				body = node.body
			}, false)
		elseif node.type == "MethodDeclaration" then
			local obj = evaluate_expression(node.object)
			if type(obj) ~= "table" then
				runtime_error("Attempt to add method to a non-table value", node)
			end

			local method_name
			if node.computed then
				method_name = evaluate_expression(node.method)
			else
				method_name = node.method.name
			end

			obj[method_name] = {
				type = "Function",
				parameters = node.parameters,
				body = node.body
			}
		elseif node.type == "WhileStatement" then
			while evaluate_expression(node.condition) do
				if environment.break_flag then
					environment.break_flag = false
					break
				end
				table.insert(environment.locals_stack, {})
				for _, stmt in ipairs(node.body) do
					execute_statement(stmt)
					if environment.break_flag then break end
				end
				table.remove(environment.locals_stack)
			end
		elseif node.type == "ForStatement" then
			local start_val = evaluate_expression(node.start)
			local end_val = evaluate_expression(node.finish)
			local step_val = node.step and evaluate_expression(node.step) or 1
			if step_val == 0 then
				runtime_error("Loop step cannot be zero", node)
			end
			table.insert(environment.locals_stack, {})
			for i = start_val, end_val, step_val do
				environment.locals_stack[#environment.locals_stack][node.variable] = i
				for _, stmt in pairs(node.body) do
					execute_statement(stmt)
					if environment.break_flag then break end
				end
				if environment.break_flag then
					environment.break_flag = false
					break
				end
			end
			table.remove(environment.locals_stack)
		elseif node.type == "IfStatement" then
			local condition = evaluate_expression(node.test)
			if condition then
				table.insert(environment.locals_stack, {})
				for _, stmt in ipairs(node.consequent) do
					execute_statement(stmt)
				end
				table.remove(environment.locals_stack)
			elseif node.alternate then
				if node.alternate.type == "BlockStatement" then
					table.insert(environment.locals_stack, {})
					for _, stmt in ipairs(node.alternate.body) do
						execute_statement(stmt)
					end
					table.remove(environment.locals_stack)
				elseif node.alternate.type == "IfStatement" then
					execute_statement(node.alternate)
				end
			end
		elseif node.type == "ReturnStatement" then
			environment.return_values = evaluate_expression_list(node.values)
			environment.has_return = true
		elseif node.type == "BreakStatement" then
			environment.break_flag = true
		elseif node.type == "BlockStatement" then
			table.insert(environment.locals_stack, {})
			for _, stmt in ipairs(node.body) do
				execute_statement(stmt)
				if environment.break_flag then break end
			end
			table.remove(environment.locals_stack)
		elseif node.type == "CallExpression" then
			evaluate_expression(node)
		end
	end

	function interpreter.execute(ast)
		if not ast or ast.type ~= "Program" then
			err("Invalid AST")
		end
		environment.break_flag = false
		environment.has_return = false
		environment.return_values = nil
		environment.call_stack = {}
		for _, stmt in ipairs(ast.body) do
			execute_statement(stmt)
			if environment.break_flag then break end
		end
		return environment.globals
	end

	function interpreter.get_environment()
		return {
			globals = environment.globals,
			functions = environment.functions
		}
	end

	return interpreter
end

function run_marsik_code(code_string)
	local ast, tokens, clean = parser(code_string)
	local interpreter = create_interpreter()
	return interpreter.execute(ast)
end

if arg[1] then
	local f = io.open(arg[1])
	if not f then
		print("Failed to open file: "..arg[1])
		os.exit(1)
	end
	run_marsik_code(f:read("*a"))
	f:close()
	os.exit(0)
end