function err(_err, token, source) {
	let line, col;
	if (token && token.line) {
		line = token.line;
		col = token.col;
	} else if (token && typeof token === "number") {
		if (typeof get_line_col_from_pos === "function") {
			[line, col] = get_line_col_from_pos(token);
		} else {
			line = 1; col = 1;
		}
	} else {
		console.log("Error: " + _err);
		process.exit(1);
	}

	console.log(`Error at line ${line}, column ${col}: ${_err}`);
	if (source && line) {
		const src_lines = source.split("\n");
		if (line <= src_lines.length) {
			console.log(src_lines[line - 1]);
			console.log(" ".repeat(Math.max(0, col - 1)) + "^");
		}
	}
	process.exit(1);
}

let _d = 0;
function debug(arg) {
	_d++;
	console.log("DEBUG: " + _d + (arg ? " - " + String(arg) : ""));
}


class Multi {
	constructor(vals) { this.vals = vals; }
}
function first(v) {
	if (v instanceof Multi) return v.vals.length > 0 ? v.vals[0] : null;
	return v;
}
function expand(v) {
	if (v instanceof Multi) return v.vals;
	return [v];
}
function isTruthy(v) {
	v = first(v);
	return v !== null && v !== undefined && v !== false;
}
function tbl_len(t) {
	if (t === null || t === undefined) return 0;
	if (typeof t === "string") return t.length;
	if (Array.isArray(t)) return t.length;
	let n = 0;
	while (t[n + 1] !== undefined && t[n + 1] !== null) n++;
	return n;
}

const bit = {
	bnot: (n) => (~(Number(n) | 0)) | 0,
	band: (a, b) => ((Number(a) | 0) & (Number(b) | 0)) | 0,
	bor: (a, b) => ((Number(a) | 0) | (Number(b) | 0)) | 0,
	bxor: (a, b) => ((Number(a) | 0) ^ (Number(b) | 0)) | 0,
	lshift: (a, s) => ((Number(a) | 0) << (Number(s) | 0)) | 0,
	rshift: (a, s) => ((Number(a) | 0) >>> (Number(s) | 0)) | 0,
};

function parser(code) {
	const orig = code;

	const sub = (s, i, j) => {
		if (j === undefined) return s.substring(i - 1);
		if (j < i) return "";
		return s.substring(i - 1, j);
	};

	function get_line_col_from_pos(pos) {
		let line = 1, col = 1;
		for (let i = 1; i < pos; i++) {
			if (orig[i - 1] === "\n") { line++; col = 1; }
			else col++;
		}
		return [line, col];
	}

	function local_err(_err, token) {
		if (token && token.line) {
			console.log(`Error at line ${token.line}, column ${token.col}: ${_err}`);
		} else if (token && typeof token === "number") {
			const [line, col] = get_line_col_from_pos(token);
			console.log(`Error at line ${line}, column ${col}: ${_err}`);
			const src_lines = orig.split("\n");
			if (line <= src_lines.length) {
				console.log(src_lines[line - 1]);
				console.log(" ".repeat(Math.max(0, col - 1)) + "^");
			}
		} else {
			console.log("Error: " + _err);
		}
		process.exit(1);
	}

	function tokenize(source) {
		const tokens = [];
		let i = 1;
		const len = source.length;
		let line = 1, col = 1;

		const operators = new Set([
			"==", "!=", "<=", ">=", "+", "-", "*", "/", "%", "^", "#",
			"=", "<", ">", "(", ")", "[", "]", "{", "}", ",", ";", ".",
			":", "..", "~", "&", "|", "<<", ">>", "//"
		]);
		const keywords = new Set([
			"func", "return", "if", "elseif", "else", "while", "for", "do",
			"end", "break", "local", "null", "true", "false", "or", "and", "not"
		]);

		const is_hex_digit = c => /[0-9a-fA-F]/.test(c);
		const is_ws = c => /\s/.test(c);
		const is_digit = c => /[0-9]/.test(c);
		const is_alpha = c => /[a-zA-Z_]/.test(c);
		const is_alnum = c => /[a-zA-Z0-9_]/.test(c);

		function skip_comment() {
			let depth = 1;
			i += 3; col += 3;
			while (i <= len) {
				if (i <= len - 2 && sub(source, i, i + 2) === ">>>") {
					depth--;
					if (depth === 0) { i += 3; col += 3; break; }
					i += 3; col += 3;
				} else if (i <= len - 2 && sub(source, i, i + 2) === "<<<") {
					depth++;
					i += 3; col += 3;
				} else {
					const c = sub(source, i, i);
					if (c === "\n") { line++; col = 1; } else col++;
					i++;
				}
			}
			if (depth > 0) {
				local_err("Unclosed comment starting at position " + (i - 3), i - 3);
			}
		}

		function read_number(start_i, start_line, start_col) {
			const char = sub(source, i, i);
			if (char === "0" && i < len) {
				const nc = sub(source, i + 1, i + 1);
				if (nc === "x" || nc === "X") {
					i += 2; col += 2;
					const hex_start = i;
					while (i <= len && is_hex_digit(sub(source, i, i))) { i++; col++; }
					if (i === hex_start) {
						local_err("Invalid hexadecimal number at position " + start_i, start_i);
					}
					const hex_str = sub(source, hex_start, i - 1);
					tokens.push({
						type: "number",
						value: parseInt(hex_str, 16),
						raw_value: "0x" + hex_str,
						is_hex: true,
						line: start_line, col: start_col
					});
					return;
				}
			}
			while (i <= len && is_digit(sub(source, i, i))) { i++; col++; }
			if (i <= len && sub(source, i, i) === ".") {
				const nc = i + 1 <= len ? sub(source, i + 1, i + 1) : "";
				if (nc !== "." && is_digit(nc)) {
					i++; col++;
					while (i <= len && is_digit(sub(source, i, i))) { i++; col++; }
				}
			}
			const raw_value = sub(source, start_i, i - 1);
			const num = parseFloat(raw_value);
			tokens.push({
				type: "number",
				value: isNaN(num) ? raw_value : num,
				raw_value: raw_value,
				line: start_line, col: start_col
			});
		}

		while (i <= len) {
			const char = sub(source, i, i);
			if (char === "\n") { line++; col = 1; i++; }
			else if (is_ws(char)) { col++; i++; }
			else if (i <= len - 2 && sub(source, i, i + 2) === "<<<") { skip_comment(); }
			else if (char === "'" || char === '"') {
				const start_i = i, start_line = line, start_col = col;
				const quote = char;
				i++; col++;
				while (i <= len) {
					const c = sub(source, i, i);
					if (c === "\\") { i += 2; col += 2; }
					else if (c === quote) break;
					else { i++; col++; }
				}
				if (i > len) {
					local_err("Unclosed string literal starting at position " + start_i, start_i);
				}
				tokens.push({
					type: "string",
					value: sub(source, start_i, i),
					start_pos: start_i,
					line: start_line, col: start_col
				});
				i++; col++;
			} else if (is_digit(char)) {
				read_number(i, line, col);
			} else if (is_alpha(char)) {
				const start_i = i, start_line = line, start_col = col;
				while (i <= len && is_alnum(sub(source, i, i))) { i++; col++; }
				const value = sub(source, start_i, i - 1);
				const token_type = keywords.has(value) ? "keyword" : "identifier";
				tokens.push({ type: token_type, value, line: start_line, col: start_col });
			} else {
				const start_line = line, start_col = col;
				if (i <= len - 1 && sub(source, i, i + 1) === "..") {
					tokens.push({ type: "operator", value: "..", line: start_line, col: start_col });
					i += 2; col += 2;
				} else if (i <= len - 1) {
					const op2 = sub(source, i, i + 1);
					if (operators.has(op2)) {
						tokens.push({ type: "operator", value: op2, line: start_line, col: start_col });
						i += 2; col += 2;
					} else if (operators.has(char)) {
						tokens.push({ type: "operator", value: char, line: start_line, col: start_col });
						i++; col++;
					} else {
						tokens.push({ type: "unknown", value: char, line: start_line, col: start_col });
						i++; col++;
					}
				} else if (operators.has(char)) {
					tokens.push({ type: "operator", value: char, line: start_line, col: start_col });
					i++; col++;
				} else {
					tokens.push({ type: "unknown", value: char, line: start_line, col: start_col });
					i++; col++;
				}
			}
		}

		return tokens;
	}

	function build_ast(tokens) {
		const ast = { type: "Program", body: [], source: orig };
		let i = 1;
		const token_count = tokens.length;
		const UNARY_PRECEDENCE = 11;

		const current_token = () => i <= token_count ? tokens[i - 1] : null;
		const peek_token = (offset) => {
			offset = offset || 1;
			return i + offset - 1 <= token_count ? tokens[i + offset - 1] : null;
		};

		function consume_token(expected_type, expected_value) {
			const token = current_token();
			if (!token) local_err("Unexpected end of input");
			if (expected_type && token.type !== expected_type) {
				local_err(`Expected ${expected_type}, got ${token.type} (value: ${token.value})`, token);
			}
			if (expected_value && token.value !== expected_value) {
				local_err(`Expected '${expected_value}', got '${token.value}'`, token);
			}
			i++;
			return token;
		}

		function match_token(token_type, token_value) {
			const token = current_token();
			if (token && token.type === token_type && (!token_value || token.value === token_value)) {
				i++;
				return token;
			}
			return null;
		}

		function parse_function_expression() {
			const func_token = consume_token("keyword", "func");
			const params = [];
			const start_line = func_token.line, start_col = func_token.col;
			if (match_token("operator", "(")) {
				if (!match_token("operator", ")")) {
					do {
						const p = consume_token("identifier");
						params.push(p.value);
						if (!match_token("operator", ",")) break;
					} while (current_token() && current_token().value !== ")");
					consume_token("operator", ")");
				}
			}
			consume_token("keyword", "do");
			const body = parse_block();
			consume_token("keyword", "end");
			return {
				type: "FunctionExpression",
				parameters: params, body,
				loc: { line: start_line, col: start_col }
			};
		}

		function parse_expression(min_precedence) {
			min_precedence = min_precedence || 0;
			let token = current_token();
			if (token && token.value === "func") return parse_function_expression();
			const left = parse_unary_expression();
			if (!left) return null;
			if (min_precedence === 0) {
				token = current_token();
				if (token && token.type === "operator" && token.value === "=") {
					const at = consume_token("operator");
					const right = parse_expression(0);
					return {
						type: "AssignmentExpression",
						operator: "=", left, right,
						loc: { line: at.line, col: at.col }
					};
				}
			}
			return parse_binary_expression(left, min_precedence);
		}

		function parse_expression_list() {
			const expressions = [];
			if (!current_token() || current_token().value === ")" || current_token().value === "end") {
				return expressions;
			}
			do {
				const e = parse_expression();
				if (e) expressions.push(e);
				if (!match_token("operator", ",")) break;
			} while (current_token() && current_token().value !== ")" && current_token().value !== "end");
			return expressions;
		}

		function parse_assignment_targets() {
			const targets = [];
			if (!current_token()) return targets;
			do {
				const t = parse_primary_expression();
				if (t) targets.push(t);
				if (!match_token("operator", ",")) break;
			} while (current_token() && current_token().value !== "=");
			return targets;
		}

		function parse_primary_expression() {
			const token = current_token();
			if (!token) return null;

			if (token.type === "number") {
				const t = consume_token("number");
				return { type: "NumberLiteral", value: t.value, loc: { line: t.line, col: t.col } };
			}
			if (token.type === "string") {
				const t = consume_token("string");
				return { type: "StringLiteral", value: t.value, loc: { line: t.line, col: t.col } };
			}
			if (token.value === "null") {
				const t = consume_token("keyword", "null");
				return { type: "NullLiteral", loc: { line: t.line, col: t.col } };
			}
			if (token.value === "true" || token.value === "false") {
				const t = consume_token("keyword");
				return { type: "BooleanLiteral", value: t.value === "true", loc: { line: t.line, col: t.col } };
			}
			if (token.type === "identifier") {
				const id_token = consume_token("identifier");
				let expr = {
					type: "Identifier", name: id_token.value,
					loc: { line: id_token.line, col: id_token.col }
				};
				while (match_token("operator", "[") || match_token("operator", ".")) {
					if (tokens[i - 2].value === "[") {
						const index = parse_expression();
						const close_token = consume_token("operator", "]");
						if (current_token() && current_token().type === "operator" && current_token().value === "(") {
							const op = consume_token("operator", "(");
							const args = parse_expression_list();
							consume_token("operator", ")");
							expr = {
								type: "MethodCallExpression",
								object: expr, method: index, computed: true, arguments: args,
								loc: { line: op.line, col: op.col }
							};
						} else {
							expr = {
								type: "MemberExpression",
								object: expr, property: index, computed: true,
								loc: { line: close_token.line, col: close_token.col }
							};
						}
					} else {
						const prop_token = consume_token("identifier");
						if (current_token() && current_token().type === "operator" && current_token().value === "(") {
							const op = consume_token("operator", "(");
							const args = parse_expression_list();
							consume_token("operator", ")");
							expr = {
								type: "MethodCallExpression",
								object: expr,
								method: {
									type: "Identifier", name: prop_token.value,
									loc: { line: prop_token.line, col: prop_token.col }
								},
								computed: false, arguments: args,
								loc: { line: op.line, col: op.col }
							};
						} else {
							expr = {
								type: "MemberExpression",
								object: expr,
								property: {
									type: "Identifier", name: prop_token.value,
									loc: { line: prop_token.line, col: prop_token.col }
								},
								computed: false,
								loc: { line: prop_token.line, col: prop_token.col }
							};
						}
					}
				}
				if (match_token("operator", "(")) {
					const args = parse_expression_list();
					consume_token("operator", ")");
					expr = {
						type: "CallExpression", callee: expr, arguments: args,
						loc: { line: id_token.line, col: id_token.col }
					};
				}
				return expr;
			}
			if (match_token("operator", "{")) {
				const open_token = tokens[i - 2];
				const elements = [];
				const fields = [];
				if (!match_token("operator", "}")) {
					do {
						let key = null, value = null, is_kv = false;
						const saved_i = i;
						if (current_token() && current_token().type === "operator" && current_token().value === "[") {
							consume_token("operator", "[");
							key = parse_expression();
							consume_token("operator", "]");
							if (current_token() && current_token().type === "operator" && current_token().value === "=") {
								consume_token("operator", "=");
								value = parse_expression();
								is_kv = true;
							} else {
								i = saved_i;
								key = null;
							}
						} else if (current_token() && current_token().type === "identifier") {
							const nt = peek_token(1);
							if (nt && nt.type === "operator" && nt.value === "=") {
								const id_t = consume_token("identifier");
								key = {
									type: "StringLiteral",
									value: '"' + id_t.value + '"',
									loc: { line: id_t.line, col: id_t.col }
								};
								consume_token("operator", "=");
								value = parse_expression();
								is_kv = true;
							}
						}
						if (is_kv) fields.push({ key, value });
						else {
							const e = parse_expression();
							if (e) elements.push(e);
						}
						if (!(current_token() && (current_token().value === ";" || current_token().value === ","))) break;
						if (current_token().value === ";") consume_token("operator", ";");
						else consume_token("operator", ",");
					} while (current_token() && current_token().value !== "}");
					consume_token("operator", "}");
				}
				return {
					type: "TableLiteral", elements, fields,
					loc: { line: open_token.line, col: open_token.col }
				};
			}
			if (match_token("operator", "(")) {
				const open_token = tokens[i - 2];
				const expr = parse_expression();
				consume_token("operator", ")");
				if (expr) expr.loc = expr.loc || { line: open_token.line, col: open_token.col };
				return expr;
			}
			return null;
		}

		function parse_unary_expression() {
			const token = current_token();
			if (token && token.type === "keyword" && token.value === "not") {
				const op = consume_token("keyword", "not");
				const arg = parse_expression(UNARY_PRECEDENCE);
				return {
					type: "UnaryExpression", operator: "not", argument: arg,
					loc: { line: op.line, col: op.col }
				};
			}
			if (token && token.type === "operator" &&
				(token.value === "-" || token.value === "#" || token.value === "~")) {
				const op = consume_token("operator");
				const arg = parse_expression(UNARY_PRECEDENCE);
				return {
					type: "UnaryExpression", operator: op.value, argument: arg,
					loc: { line: op.line, col: op.col }
				};
			}
			return parse_primary_expression();
		}

		function parse_binary_expression(left, min_precedence) {
			const prec_map = {
				"or": 1, "and": 2,
				"==": 3, "!=": 3, "<": 3, ">": 3, "<=": 3, ">=": 3,
				"|": 4, "~": 5, "&": 6, "<<": 7, ">>": 7,
				"..": 8,
				"+": 9, "-": 9, "*": 10, "/": 10, "%": 10, "//": 10,
				"^": 12
			};
			while (true) {
				const lookahead = current_token();
				if (!lookahead) break;
				let op, prec;
				if (lookahead.type === "operator" && prec_map[lookahead.value] !== undefined) {
					op = lookahead.value; prec = prec_map[op];
				} else if (lookahead.type === "keyword" && (lookahead.value === "and" || lookahead.value === "or")) {
					op = lookahead.value; prec = prec_map[op];
				} else break;

				if (prec < min_precedence) break;
				const op_token = lookahead.type === "operator"
					? consume_token("operator")
					: consume_token("keyword");

				let right = parse_unary_expression();
				if (!right) break;
				const next_min = op === "^" ? prec : prec + 1;
				right = parse_binary_expression(right, next_min);
				left = {
					type: "BinaryExpression", operator: op, left, right,
					loc: { line: op_token.line, col: op_token.col }
				};
			}
			return left;
		}

		function parse_block() {
			const body = [];
			while (current_token() && current_token().value !== "end") {
				const s = parse_statement();
				if (s) body.push(s); else break;
			}
			return body;
		}

		function parse_method_path() {
			const path = [];
			const first_token = consume_token("identifier");
			const current = {
				type: "Identifier", name: first_token.value,
				loc: { line: first_token.line, col: first_token.col }
			};
			const start_line = first_token.line, start_col = first_token.col;
			while (current_token() && (current_token().value === "." || current_token().value === "[")) {
				if (current_token().value === ".") {
					consume_token("operator", ".");
					const pt = consume_token("identifier");
					path.push({
						type: "member", computed: false,
						property: {
							type: "Identifier", name: pt.value,
							loc: { line: pt.line, col: pt.col }
						}
					});
				} else {
					consume_token("operator", "[");
					const index = parse_expression();
					consume_token("operator", "]");
					path.push({ type: "member", computed: true, property: index });
				}
			}
			if (path.length === 0) {
				local_err("Expected method name after object", current_token());
			}
			let object = current;
			for (let k = 0; k < path.length - 1; k++) {
				const m = path[k];
				object = {
					type: "MemberExpression",
					object, property: m.property, computed: m.computed,
					loc: m.property.loc || { line: start_line, col: start_col }
				};
			}
			const last = path[path.length - 1];
			return {
				type: "MethodDeclaration",
				object, method: last.property, computed: last.computed,
				loc: { line: start_line, col: start_col }
			};
		}

		function parse_statement() {
			const token = current_token();
			if (!token) return null;

			if (token.value === "func") {
				const func_token = consume_token("keyword", "func");
				const saved_i = i;
				const next_token = current_token();
				let is_method = false;
				if (next_token && next_token.type === "identifier") {
					consume_token("identifier");
					if (current_token() && (current_token().value === "." || current_token().value === "[")) {
						is_method = true;
					}
					i = saved_i;
				}
				if (is_method) {
					const md = parse_method_path();
					const params = [];
					consume_token("operator", "(");
					if (!match_token("operator", ")")) {
						do {
							const p = consume_token("identifier");
							params.push(p.value);
							if (!match_token("operator", ",")) break;
						} while (current_token() && current_token().value !== ")");
						consume_token("operator", ")");
					}
					consume_token("keyword", "do");
					const body = parse_block();
					consume_token("keyword", "end");
					return {
						type: "MethodDeclaration",
						object: md.object, method: md.method, computed: md.computed,
						parameters: params, body,
						loc: { line: func_token.line, col: func_token.col }
					};
				} else {
					const nt = consume_token("identifier");
					const params = [];
					consume_token("operator", "(");
					if (!match_token("operator", ")")) {
						do {
							const p = consume_token("identifier");
							params.push(p.value);
							if (!match_token("operator", ",")) break;
						} while (current_token() && current_token().value !== ")");
						consume_token("operator", ")");
					}
					consume_token("keyword", "do");
					const body = parse_block();
					consume_token("keyword", "end");
					return {
						type: "FunctionDeclaration",
						name: nt.value, parameters: params, body,
						loc: { line: func_token.line, col: func_token.col }
					};
				}
			} else if (token.value === "local") {
				const local_token = consume_token("keyword", "local");
				const declarations = [];
				let nt = consume_token("identifier");
				declarations.push({
					name: nt.value, value: null,
					loc: { line: nt.line, col: nt.col }
				});
				while (match_token("operator", ",")) {
					nt = consume_token("identifier");
					declarations.push({
						name: nt.value, value: null,
						loc: { line: nt.line, col: nt.col }
					});
				}
				const values = [];
				if (match_token("operator", "=")) {
					do {
						const v = parse_expression();
						if (v) values.push(v);
						if (!match_token("operator", ",")) break;
					} while (current_token() && current_token().value !== "," && current_token().value !== "=");
				}
				return {
					type: "VariableDeclaration", kind: "local",
					declarations, values,
					loc: { line: local_token.line, col: local_token.col }
				};
			} else if (token.value === "if") {
				const if_token = consume_token("keyword", "if");
				const stmt = {
					type: "IfStatement",
					test: parse_expression(),
					consequent: [],
					alternate: null,
					loc: { line: if_token.line, col: if_token.col }
				};
				consume_token("keyword", "do");
				while (current_token() && current_token().value !== "else" &&
					 current_token().value !== "elseif" && current_token().value !== "end") {
					const s = parse_statement();
					if (s) stmt.consequent.push(s); else break;
				}
				while (current_token() && (current_token().value === "elseif" || current_token().value === "else")) {
					if (current_token().value === "elseif") {
						const et = consume_token("keyword", "elseif");
						const test = parse_expression();
						consume_token("keyword", "do");
						const body = [];
						while (current_token() && current_token().value !== "else" &&
							 current_token().value !== "elseif" && current_token().value !== "end") {
							const s = parse_statement();
							if (s) body.push(s); else break;
						}
						const elseif_stmt = {
							type: "IfStatement", test, consequent: body, alternate: null,
							loc: { line: et.line, col: et.col }
						};
						let last = stmt;
						while (last.alternate) last = last.alternate;
						last.alternate = elseif_stmt;
					} else {
						const et = consume_token("keyword", "else");
						const body = [];
						while (current_token() && current_token().value !== "end") {
							const s = parse_statement();
							if (s) body.push(s); else break;
						}
						let last = stmt;
						while (last.alternate) last = last.alternate;
						last.alternate = {
							type: "BlockStatement", body,
							loc: { line: et.line, col: et.col }
						};
						break;
					}
				}
				consume_token("keyword", "end");
				return stmt;
			} else if (token.value === "while") {
				const wt = consume_token("keyword", "while");
				const cond = parse_expression();
				consume_token("keyword", "do");
				const body = parse_block();
				consume_token("keyword", "end");
				return {
					type: "WhileStatement", condition: cond, body,
					loc: { line: wt.line, col: wt.col }
				};
			} else if (token.value === "for") {
				const ft = consume_token("keyword", "for");
				const vt = consume_token("identifier");
				consume_token("operator", "=");
				const start_expr = parse_expression();
				if (!start_expr) local_err("Missing start expression in for loop", current_token());
				consume_token("operator", ",");
				const end_expr = parse_expression();
				if (!end_expr) local_err("Missing end expression in for loop", current_token());
				let step_expr = null;
				if (match_token("operator", ",")) step_expr = parse_expression();
				consume_token("keyword", "do");
				const body = parse_block();
				consume_token("keyword", "end");
				return {
					type: "ForStatement",
					variable: vt.value,
					start: start_expr, finish: end_expr, step: step_expr,
					body,
					loc: { line: ft.line, col: ft.col }
				};
			} else if (token.value === "return") {
				const rt = consume_token("keyword", "return");
				const values = parse_expression_list();
				return {
					type: "ReturnStatement", values,
					loc: { line: rt.line, col: rt.col }
				};
			} else if (token.value === "break") {
				const bt = consume_token("keyword", "break");
				return { type: "BreakStatement", loc: { line: bt.line, col: bt.col } };
			} else if (match_token("keyword", "do")) {
				const dt = tokens[i - 2];
				const body = parse_block();
				consume_token("keyword", "end");
				return {
					type: "BlockStatement", body,
					loc: { line: dt.line, col: dt.col }
				};
			}

			const saved_i = i;
			const targets = parse_assignment_targets();
			if (targets.length > 0 && match_token("operator", "=")) {
				const values = parse_expression_list();
				return {
					type: "AssignmentStatement",
					left: targets, right: values,
					loc: { line: targets[0].loc.line, col: targets[0].loc.col }
				};
			}
			i = saved_i;
			const expr = parse_expression();
			if (expr) {
				return { type: "ExpressionStatement", expression: expr, loc: expr.loc };
			}
			return null;
		}

		while (i <= token_count) {
			const s = parse_statement();
			if (s) ast.body.push(s); else i++;
		}
		return ast;
	}

	const tokens = tokenize(code);
	const ast = build_ast(tokens);
	return { ast, tokens, code: orig };
}


function create_interpreter() {
	const environment = {
		globals: {},
		locals_stack: [{}],
		functions: {},
		builtins: {},
		break_flag: false,
		return_values: null,
		has_return: false,
		call_stack: []
	};

	environment.builtins.math = {
		abs: x => Math.abs(x[0] || 0),
		acos: x => Math.acos(x[0] || 0),
		asin: x => Math.asin(x[0] || 0),
		atan: x => Math.atan(x[0] || 0),
		atan2: (y, x) => Math.atan2(y[0] || 0, x[0] || 0),
		ceil: x => Math.ceil(x[0] || 0),
		cos: x => Math.cos(x[0] || 0),
		cosh: x => Math.cosh(x[0] || 0),
		deg: x => (x[0] || 0) * 180 / Math.PI,
		exp: x => Math.exp(x[0] || 0),
		floor: x => Math.floor(x[0] || 0),
		fmod: (x, y) => (x[0] || 0) % (y[0] || 0),
		frexp: x => {
			const v = x[0] || 0;
			if (v === 0) return [0, 0];
			const e = Math.floor(Math.log2(Math.abs(v))) + 1;
			return [v / Math.pow(2, e), e];
		},
		ldexp: (m, e) => (m[0] || 0) * Math.pow(2, e[0] || 0),
		log: x => Math.log(x[0] || 0),
		log10: x => Math.log10(x[0] || 0),
		max: (...args) => {
			let m = -Infinity;
			for (const a of args) { const v = a[0] ?? -Infinity; if (v > m) m = v; }
			return m;
		},
		min: (...args) => {
			let m = Infinity;
			for (const a of args) { const v = a[0] ?? Infinity; if (v < m) m = v; }
			return m;
		},
		modf: x => {
			const v = x[0] || 0;
			const int = Math.trunc(v);
			return [int, v - int];
		},
		pow: (x, y) => Math.pow(x[0] || 0, y[0] || 0),
		rad: x => (x[0] || 0) * Math.PI / 180,
		random: (m, n) => {
			if (m && n) return Math.floor(Math.random() * ((n[0] || 1) - (m[0] || 1) + 1)) + (m[0] || 1);
			if (m) return Math.floor(Math.random() * (m[0] || 1)) + 1;
			return Math.random();
		},
		randomseed: x => null,
		sin: x => Math.sin(x[0] || 0),
		sinh: x => Math.sinh(x[0] || 0),
		sqrt: x => Math.sqrt(x[0] || 0),
		tan: x => Math.tan(x[0] || 0),
		tanh: x => Math.tanh(x[0] || 0),
		pi: Math.PI,
		huge: Infinity
	};

	environment.builtins.string = {
		byte: (s, i2, j) => (s[0] || "").charCodeAt(((i2 && i2[0]) || 1) - 1),
		char: (...args) => String.fromCharCode(...args.map(a => a[0] || 0)),
		find: (s, pattern, init, plain) => {
			const str = s[0] || "", pat = pattern[0] || "";
			const idx = str.indexOf(pat, ((init && init[0]) || 1) - 1);
			if (idx === -1) return null;
			return [idx + 1, idx + pat.length];
		},
		format: (...args) => {
			const fmt = args[0][0] || "";
			const rest = args.slice(1).map(a => a[0]);
			let idx = 0;
			return fmt.replace(/%[sdifxX%]/g, m => {
				if (m === "%%") return "%";
				const v = rest[idx++];
				if (m === "%d" || m === "%i") return String(Math.trunc(v));
				if (m === "%f") return String(v);
				if (m === "%x") return Math.trunc(v).toString(16);
				if (m === "%X") return Math.trunc(v).toString(16).toUpperCase();
				if (m === "%s") return String(v);
				return m;
			});
		},
		gmatch: (s, pattern) => {
			const str = s[0] || "", pat = pattern[0] || "";
			const re = new RegExp(pat
				.replace(/%a/g, "[a-zA-Z]")
				.replace(/%d/g, "\\d")
				.replace(/%w/g, "\\w")
				.replace(/%s/g, "\\s")
				.replace(/%p/g, "[^\\w\\s]"));
			const m = str.match(re);
			return m ? m[0] : "";
		},
		gsub: (s, pattern, repl, n) => {
			const str = s[0] || "", pat = pattern[0] || "", r = repl[0] || "";
			const limit = (n && n[0]) || 0;
			let count = 0;
			const result = str.replace(new RegExp(pat, "g"), (m) => {
				if (limit && count >= limit) return m;
				count++;
				return r;
			});
			return [result, count];
		},
		len: s => (s[0] || "").length,
		lower: s => (s[0] || "").toLowerCase(),
		match: (s, pattern, init) => {
			const str = s[0] || "", pat = pattern[0] || "";
			const from = ((init && init[0]) || 1) - 1;
			const re = new RegExp(pat
				.replace(/%a/g, "[a-zA-Z]")
				.replace(/%d/g, "\\d")
				.replace(/%w/g, "\\w")
				.replace(/%s/g, "\\s")
				.replace(/%p/g, "[^\\w\\s]"));
			const m = str.substring(from).match(re);
			if (!m) return null;
			return m.length === 1 ? m[0] : m.slice(1);
		},
		rep: (s, n) => (s[0] || "").repeat(n[0] || 0),
		reverse: s => (s[0] || "").split("").reverse().join(""),
		sub: (s, i2, j) => {
			const str = s[0] || "";
			const start = (i2 && i2[0]) || 1;
			let end = (j && j[0]) !== undefined ? j[0] : -1;
			if (end < 0) end = str.length + end + 1;
			return str.substring(start - 1, end);
		},
		upper: s => (s[0] || "").toUpperCase()
	};

	environment.builtins.table = {
		insert: (t, pos, value) => {
			const old_tbl = t[0] || {};
			const tbl = {};
			for (const k in old_tbl) tbl[k] = old_tbl[k];
			if (value !== undefined) {
				const p = pos[0] || (tbl_len(tbl) + 1);
				for (let k = tbl_len(tbl); k >= p; k--) tbl[k + 1] = tbl[k];
				tbl[p] = value[0];
			} else {
				tbl[tbl_len(tbl) + 1] = pos[0];
			}
			return tbl;
		},
		remove: (t, pos) => {
			const old_tbl = t[0] || {};
			const tbl = {};
			for (const k in old_tbl) tbl[k] = old_tbl[k];
			const n = tbl_len(tbl);
			const p = (pos && pos[0]) || n;
			const val = tbl[p];
			for (let k = p; k < n; k++) tbl[k] = tbl[k + 1];
			delete tbl[n];
			return val;
		},
		concat: (t, sep, i2, j) => {
			const tbl = t[0] || {};
			const s = (sep && sep[0]) || "";
			const start = (i2 && i2[0]) || 1;
			const end = (j && j[0]) || tbl_len(tbl);
			const parts = [];
			for (let k = start; k <= end; k++) parts.push(String(tbl[k]));
			return parts.join(s);
		},
		sort: (t, comp) => {
			const old_tbl = t[0] || {};
			const arr = [];
			for (let k = 1; k <= tbl_len(old_tbl); k++) arr.push(old_tbl[k]);
			if (comp) arr.sort((a, b) => isTruthy(comp[0]([a], [b])) ? -1 : 1);
			else arr.sort((a, b) => a < b ? -1 : a > b ? 1 : 0);
			const tbl = {};
			for (let k = 0; k < arr.length; k++) tbl[k + 1] = arr[k];
			return tbl;
		},
		pack: (...args) => {
			const result = {};
			for (let k = 0; k < args.length; k++) result[k + 1] = args[k][0];
			result.n = args.length;
			return result;
		},
		unpack: (t, i2, j) => {
			const tbl = t[0] || {};
			const start = (i2 && i2[0]) || 1;
			const end = (j && j[0]) || tbl_len(tbl);
			const out = [];
			for (let k = start; k <= end; k++) out.push(tbl[k]);
			return out;
		}
	};

	environment.builtins.print = (...args) => {
		const strs = args.map(arr => {
			const v = arr[0];
			if (v === null || v === undefined) return "null";
			if (typeof v === "boolean") return v ? "true" : "false";
			if (typeof v === "object") {
				if (v.type === "NumberLiteral") return String(v.value);
				if (v.type === "Function") return "function";
				return `table: ${tbl_len(v)} element${tbl_len(v) !== 1 ? "s" : ""}`;
			}
			if (typeof v === "string") return v;
			if (typeof v === "function") return "function";
			return String(v);
		});
		console.log(strs.join("\t"));
		return null;
	};

	environment.builtins.tonumber = (x, base) => {
		if (typeof x[0] === "number") return x[0];
		if (typeof x[0] === "string") {
			const n = base ? parseInt(x[0], base[0]) : parseFloat(x[0]);
			return isNaN(n) ? null : n;
		}
		return null;
	};

	environment.builtins.tostring = (x) => {
		const v = x[0];
		if (typeof v === "string") return v;
		if (v === null || v === undefined) return "null";
		if (typeof v === "boolean") return v ? "true" : "false";
		return String(v);
	};

	environment.builtins.type = (x) => {
		if (x === null || x === undefined) return "null";
		const val = x[0];
		if (typeof val === "object" && val !== null) {
			if (val.type === "Function") return "function";
			return "table";
		}
		const k = typeof val;
		return (k === "undefined" || k === "object") ? "null" : k;
	};

	environment.builtins.pairs = (t) => {
		const tbl = t[0] || {};
		const keys = Object.keys(tbl);
		let idx = 0;
		return () => {
			if (idx < keys.length) {
				const k = keys[idx++];
				return [k, tbl[k]];
			}
			return null;
		};
	};

	environment.builtins.ipairs = (t) => {
		const tbl = t[0] || {};
		let idx = 0;
		return () => {
			idx++;
			if (tbl[idx] !== undefined) return [idx, tbl[idx]];
			return null;
		};
	};

	environment.builtins.next = (t, k) => {
		const tbl = t[0] || {};
		const keys = Object.keys(tbl);
		const kk = (k && k[0]) || null;
		const idx = kk === null ? 0 : keys.indexOf(String(kk)) + 1;
		if (idx < keys.length) return [keys[idx], tbl[keys[idx]]];
		return null;
	};

	environment.builtins.rawequal = (a, b) => a[0] === b[0];
	environment.builtins.rawget = (t, k) => (t[0] || {})[k[0]];
	environment.builtins.rawset = (t, k, v) => { (t[0] || {})[k[0]] = v[0]; return t[0]; };

	environment.builtins.select = (index, ...args) => {
		if (typeof index[0] === "number") {
			const idx = index[0];
			if (idx > 0) return args.slice(idx - 1).map(a => a[0]);
			return args.length;
		}
		if (index[0] === "#") return args.length;
		return null;
	};

	environment.builtins.os = {
		clock: () => process.uptime(),
		date: (format, time) => new Date().toString(),
		difftime: (t2, t1) => (t2[0] || 0) - (t1[0] || 0),
		time: (t) => Math.floor(Date.now() / 1000),
		tmpname: () => "/tmp/tmp_" + Math.random().toString(36).slice(2)
	};

	environment.builtins.io = {
		write: (...args) => {
			for (const a of args) process.stdout.write(String(a[0] ?? ""));
			return null;
		},
		read: (format) => null,
		type: (file) => null
	};

	environment.globals.math = environment.builtins.math;
	environment.globals.string = environment.builtins.string;
	environment.globals.table = environment.builtins.table;
	environment.globals.os = environment.builtins.os;
	environment.globals.io = environment.builtins.io;

	function runtime_error(msg, node) {
		const loc = node && node.loc;
		if (loc) {
			console.log(`Runtime error at line ${loc.line}, column ${loc.col}: ${msg}`);
		} else {
			console.log("Runtime error: " + msg);
		}
		if (environment.call_stack.length > 0) {
			console.log("Call stack:");
			for (let k = environment.call_stack.length - 1; k >= 0; k--) {
				const f = environment.call_stack[k];
				console.log(`  ${k + 1}: function '${f.name || "?"}' called from line ${f.line || 0}, column ${f.col || 0}`);
			}
		}
		process.exit(1);
	}

	function set_variable(name, value, is_local) {
		if (is_local) {
			environment.locals_stack[environment.locals_stack.length - 1][name] = value;
		} else {
			for (let k = environment.locals_stack.length - 1; k >= 0; k--) {
				if (environment.locals_stack[k][name] !== undefined) {
					environment.locals_stack[k][name] = value;
					return;
				}
			}
			environment.globals[name] = value;
		}
	}

	function get_variable(name) {
		for (let k = environment.locals_stack.length - 1; k >= 0; k--) {
			if (environment.locals_stack[k][name] !== undefined) {
				return environment.locals_stack[k][name];
			}
		}
		if (environment.globals[name] !== undefined) {
			return environment.globals[name];
		}
		return environment.builtins[name];
	}

	function evaluate_expression_list(expressions) {
		const results = [];
		const count = expressions.length;
		for (let k = 0; k < count; k++) {
			const expr = expressions[k];
			if (k === count - 1) {
				const vals = expand(evaluate_expression(expr));
				for (const v of vals) results.push(v);
			} else {
				results.push(first(evaluate_expression(expr)));
			}
		}
		return results;
	}

	function call_function(func, args, node, name) {
		if (typeof func === "function") {
			const wrapped = args.map(a => [a]);
			const result = func(...wrapped);
			if (result === undefined) return [];
			return [result];
		}
		if (func && func.type === "Function") {
			environment.call_stack.push({
				name: name || func.name || "<anonymous>",
				line: node && node.loc ? node.loc.line : 0,
				col: node && node.loc ? node.loc.col : 0
			});
			environment.locals_stack.push({});
			const params = func.parameters || [];
			for (let k = 0; k < params.length; k++) {
				environment.locals_stack[environment.locals_stack.length - 1][params[k]] =
					args[k] !== undefined ? args[k] : null;
			}
			environment.has_return = false;
			environment.return_values = null;
			const saved_break = environment.break_flag;
			environment.break_flag = false;
			for (const stmt of func.body) {
				execute_statement(stmt);
				if (environment.has_return || environment.break_flag) break;
			}
			environment.break_flag = saved_break;
			const ret = environment.return_values || [];
			environment.has_return = false;
			environment.return_values = null;
			environment.locals_stack.pop();
			environment.call_stack.pop();
			return ret;
		}
		runtime_error("Called object is not a function", node);
		return [];
	}

	function evaluate_expression(node) {
		if (!node) return null;

		if (node.type === "NumberLiteral") return node.value;
		if (node.type === "StringLiteral") return node.value.slice(1, -1);
		if (node.type === "BooleanLiteral") return node.value;
		if (node.type === "NullLiteral") return null;

		if (node.type === "Identifier") {
			return get_variable(node.name);
		}

		if (node.type === "TableLiteral") {
			const table = {};
			for (let k = 0; k < node.elements.length; k++) {
				table[k + 1] = first(evaluate_expression(node.elements[k]));
			}
			for (const field of node.fields) {
				let key = first(evaluate_expression(field.key));
				if (typeof key === "string") {
					const n = Number(key);
					if (!isNaN(n) && key.trim() !== "") key = n;
				}
				table[key] = first(evaluate_expression(field.value));
			}
			return table;
		}

		if (node.type === "MemberExpression") {
			const object = first(evaluate_expression(node.object));
			let property;
			if (node.computed) {
				property = first(evaluate_expression(node.property));
				if (typeof property === "string") {
					const n = Number(property);
					if (!isNaN(n) && property.trim() !== "") property = n;
				}
			} else {
				property = node.property.name;
			}
			if (typeof object !== "object" || object === null) {
				runtime_error("Attempt to index a non-table value", node);
			}
			return object[property];
		}

		if (node.type === "MethodCallExpression") {
			const object = first(evaluate_expression(node.object));
			if (typeof object !== "object" || object === null) {
				runtime_error("Attempt to call method on a non-table value", node);
			}
			let method_name;
			if (node.computed) method_name = first(evaluate_expression(node.method));
			else method_name = node.method.name;
			const method = object[method_name];
			if (!method) {
				runtime_error(`Method '${method_name}' not found`, node);
			}
			const args = evaluate_expression_list(node.arguments);
			const results = call_function(method, args, node, String(method_name));
			if (results.length === 0) return null;
			if (results.length === 1) return results[0];
			return new Multi(results);
		}

		if (node.type === "CallExpression") {
			if (node.callee.type === "Identifier") {
				const callee_name = node.callee.name;
				if (environment.builtins[callee_name]) {
					const args = evaluate_expression_list(node.arguments);
					const result = environment.builtins[callee_name](...args.map(a => [a]));
					if (result === undefined) return null;
					return result;
				}
				const func = environment.functions[callee_name] || get_variable(callee_name);
				if (!func) {
					runtime_error(`Function '${callee_name}' not found`, node);
				}
				const args = evaluate_expression_list(node.arguments);
				const results = call_function(func, args, node, callee_name);
				if (results.length === 0) return null;
				if (results.length === 1) return results[0];
				return new Multi(results);
			} else {
				const callee = first(evaluate_expression(node.callee));
				if (!callee || callee.type !== "Function") {
					runtime_error("Called object is not a function", node);
				}
				const args = evaluate_expression_list(node.arguments);
				const results = call_function(callee, args, node, "<anonymous>");
				if (results.length === 0) return null;
				if (results.length === 1) return results[0];
				return new Multi(results);
			}
		}

		if (node.type === "BinaryExpression") {
			const left = first(evaluate_expression(node.left));
			const right = first(evaluate_expression(node.right));
			const op = node.operator;

			if (op === "+") return (Number(left) || 0) + (Number(right) || 0);
			if (op === "-") return (Number(left) || 0) - (Number(right) || 0);
			if (op === "*") return (Number(left) || 0) * (Number(right) || 0);
			if (op === "/") {
				const r = Number(right) || 0;
				if (r === 0) runtime_error("Division by zero", node);
				return (Number(left) || 0) / r;
			}
			if (op === "%") return (Number(left) || 0) % (Number(right) || 0);
			if (op === "^") return Math.pow(Number(left) || 0, Number(right) || 0);

			if (op === "..") {
				const t1 = left === null || left === undefined ? "nil" : (typeof left === "object" ? "table" : typeof left);
				const t2 = right === null || right === undefined ? "nil" : (typeof right === "object" ? "table" : typeof right);
				let l = left, r = right;
				if (left === null || left === undefined || left === false) {
					l = node.left.name !== undefined ? node.left.name : left;
				}
				if (right === null || right === undefined || right === false) {
					r = node.right.name !== undefined ? node.right.name : right;
				}
				if (t1 === "table" && t2 === "table") {
					for (const k in r) {
						if (Object.prototype.hasOwnProperty.call(r, k)) {
							l[tbl_len(l) + 1] = r[k];
						}
					}
					return l;
				} else if (t1 === "table") {
					l[tbl_len(l) + 1] = r;
					return l;
				} else if (t2 === "table") {
					return String(l) + String(node.right.name !== undefined ? node.right.name : "");
				}
				const ls = l === null || l === undefined ? "null" : String(l);
				const rs = r === null || r === undefined ? "null" : String(r);
				return ls + rs;
			}

			if (op === "==") return left === right;
			if (op === "!=") return left !== right;
			if (op === "<") return (Number(left) || 0) < (Number(right) || 0);
			if (op === ">") return (Number(left) || 0) > (Number(right) || 0);
			if (op === "<=") return (Number(left) || 0) <= (Number(right) || 0);
			if (op === ">=") return (Number(left) || 0) >= (Number(right) || 0);
			if (op === "and") return isTruthy(left) ? right : left;
			if (op === "or") return isTruthy(left) ? left : right;
			if (op === "~") return bit.bxor(left, right);
			if (op === "&") return bit.band(left, right);
			if (op === "|") return bit.bor(left, right);
			if (op === ">>") return bit.rshift(left, right);
			if (op === "<<") return bit.lshift(left, right);
		}

		if (node.type === "UnaryExpression") {
			const argument = first(evaluate_expression(node.argument));
			if (node.operator === "-") return -(Number(argument) || 0);
			if (node.operator === "#") {
				if (argument === null || argument === undefined) return 0;
				const t = typeof argument;
				if (t === "number") return String(argument).length;
				if (t === "boolean") return argument ? 1 : -1;
				return tbl_len(argument);
			}
			if (node.operator === "~") return bit.bnot(Number(argument) || 0);
			if (node.operator === "not") return !isTruthy(argument);
			return argument;
		}

		if (node.type === "AssignmentExpression") {
			const right = first(evaluate_expression(node.right));
			if (node.left.type === "Identifier") {
				set_variable(node.left.name, right, false);
				if (right && typeof right === "object" && right.type === "Function") {
					environment.functions[node.left.name] = right;
				}
				return right;
			} else if (node.left.type === "MemberExpression") {
				const object = first(evaluate_expression(node.left.object));
				let prop;
				if (node.left.computed) prop = first(evaluate_expression(node.left.property));
				else prop = node.left.property.name;
				if (typeof object !== "object" || object === null) {
					runtime_error("Attempt to assign property to a non-table value", node);
				}
				object[prop] = right;
				return right;
			}
		}

		if (node.type === "FunctionExpression") {
			return { type: "Function", parameters: node.parameters, body: node.body };
		}

		return null;
	}

	function execute_statement(node) {
		if (!node) return;

		if (node.type === "VariableDeclaration") {
			const values = evaluate_expression_list(node.values || []);
			for (let k = 0; k < node.declarations.length; k++) {
				const decl = node.declarations[k];
				set_variable(decl.name, values[k] !== undefined ? values[k] : null, node.kind === "local");
			}
		} else if (node.type === "AssignmentStatement") {
			const values = evaluate_expression_list(node.right);
			for (let k = 0; k < node.left.length; k++) {
				const left_node = node.left[k];
				const value = values[k] !== undefined ? values[k] : null;
				if (left_node.type === "Identifier") {
					set_variable(left_node.name, value, false);
					if (value && typeof value === "object" && value.type === "Function") {
						environment.functions[left_node.name] = value;
					}
				} else if (left_node.type === "MemberExpression") {
					const object = first(evaluate_expression(left_node.object));
					let prop;
					if (left_node.computed) prop = first(evaluate_expression(left_node.property));
					else prop = left_node.property.name;
					if (typeof object !== "object" || object === null) {
						runtime_error("Attempt to assign property to a non-table value", node);
					}
					object[prop] = value;
				}
			}
		} else if (node.type === "ExpressionStatement") {
			evaluate_expression(node.expression);
		} else if (node.type === "FunctionDeclaration") {
			const fn = { type: "Function", parameters: node.parameters, body: node.body, name: node.name };
			environment.functions[node.name] = fn;
			set_variable(node.name, fn, false);
		} else if (node.type === "MethodDeclaration") {
			const obj = first(evaluate_expression(node.object));
			if (typeof obj !== "object" || obj === null) {
				runtime_error("Attempt to add method to a non-table value", node);
			}
			let method_name;
			if (node.computed) method_name = first(evaluate_expression(node.method));
			else method_name = node.method.name;
			obj[method_name] = { type: "Function", parameters: node.parameters, body: node.body };
		} else if (node.type === "WhileStatement") {
			while (isTruthy(evaluate_expression(node.condition))) {
				if (environment.break_flag) { environment.break_flag = false; break; }
				environment.locals_stack.push({});
				for (const stmt of node.body) {
					execute_statement(stmt);
					if (environment.break_flag) break;
				}
				environment.locals_stack.pop();
			}
		} else if (node.type === "ForStatement") {
			const start_val = Number(first(evaluate_expression(node.start))) || 0;
			const end_val = Number(first(evaluate_expression(node.finish))) || 0;
			const step_val = node.step ? Number(first(evaluate_expression(node.step))) : 1;
			if (step_val === 0) runtime_error("Loop step cannot be zero", node);
			environment.locals_stack.push({});
			for (let iv = start_val; (step_val > 0 ? iv <= end_val : iv >= end_val); iv += step_val) {
				environment.locals_stack[environment.locals_stack.length - 1][node.variable] = iv;
				for (const stmt of node.body) {
					execute_statement(stmt);
					if (environment.break_flag) break;
				}
				if (environment.break_flag) { environment.break_flag = false; break; }
			}
			environment.locals_stack.pop();
		} else if (node.type === "IfStatement") {
			const condition = isTruthy(evaluate_expression(node.test));
			if (condition) {
				environment.locals_stack.push({});
				for (const stmt of node.consequent) execute_statement(stmt);
				environment.locals_stack.pop();
			} else if (node.alternate) {
				if (node.alternate.type === "BlockStatement") {
					environment.locals_stack.push({});
					for (const stmt of node.alternate.body) execute_statement(stmt);
					environment.locals_stack.pop();
				} else if (node.alternate.type === "IfStatement") {
					execute_statement(node.alternate);
				}
			}
		} else if (node.type === "ReturnStatement") {
			environment.return_values = evaluate_expression_list(node.values);
			environment.has_return = true;
		} else if (node.type === "BreakStatement") {
			environment.break_flag = true;
		} else if (node.type === "BlockStatement") {
			environment.locals_stack.push({});
			for (const stmt of node.body) {
				execute_statement(stmt);
				if (environment.break_flag) break;
			}
			environment.locals_stack.pop();
		} else if (node.type === "CallExpression") {
			evaluate_expression(node);
		}
	}

	function execute(ast) {
		if (!ast || ast.type !== "Program") err("Invalid AST");
		environment.break_flag = false;
		environment.has_return = false;
		environment.return_values = null;
		environment.call_stack = [];
		for (const stmt of ast.body) {
			execute_statement(stmt);
			if (environment.break_flag) break;
		}
		return environment.globals;
	}

	return {
		execute,
		get_environment: () => ({ globals: environment.globals, functions: environment.functions })
	};
}


function run_marsik_code(code_string) {
	const { ast } = parser(code_string);
	const interpreter = create_interpreter();
	return interpreter.execute(ast);
}

if (typeof process !== "undefined" && process.argv && process.argv[2]) {
	const fs = require("fs");
	const filename = process.argv[2];
	try {
		const content = fs.readFileSync(filename, "utf8");
		run_marsik_code(content);
		process.exit(0);
	} catch (e) {
		console.log("Failed to open file: " + filename);
		process.exit(1);
	}
}
