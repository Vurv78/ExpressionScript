package base;

import haxe.ds.Option;
import haxe.ds.StringMap;
import haxe.macro.Expr;

using Safety;
using lib.Error;

import lib.Std.types as wire_expression_types;

import lib.Type.E2Number;
import base.Tokenizer.Token;
import base.Tokenizer.TokenType;
import base.Tokenizer.TokenFlag;

/*
Stmt1 ← ("if" Cond Block IfElseIf)? Stmt2
Stmt2 ← ("while" Cond Block)? Stmt3
Stmt3 ← ("for" "(" Var "=" Expr1 "," Expr1 ("," Expr1)? ")" Block)? Stmt4
Stmt4 ← ("foreach" "(" Var "," Var ":" Fun "=" Expr1 ")" Block)? Stmt5
Stmt5 ← ("break" / "continue")? Stmt6
Stmt6 ← (Var ("++" / "--"))? Stmt7
Stmt7 ← (Var ("+=" / "-=" / "*=" / "/="))? Stmt8
Stmt8 ← "local"? (Var (&"[" Index ("=" Stmt8)? / "=" Stmt8))? Expr1

Expr1 ← !(Var "=") !(Var "+=") !(Var "-=") !(Var "*=") !(Var "/=") Expr2
Expr2 ← Expr3 (("?" Expr1 ":" Expr1) / ("?:" Expr1))?
Expr3 ← Expr4 ("|" Expr4)*
Expr4 ← Expr5 ("&" Expr5)*
Expr5 ← Expr6 ("||" Expr6)*
Expr6 ← Expr7 ("&&" Expr7)*
Expr7 ← Expr8 ("^^" Expr8)*
Expr8 ← Expr9 (("==" / "!=") Expr9)*
Expr9 ← Expr10 ((">" / "<" / ">=" / "<=") Expr10)*
Expr10 ← Expr11 (("<<" / ">>") Expr11)*
Expr11 ← Expr12 (("+" / "-") Expr12)*
Expr12 ← Expr13 (("*" / "/" / "%") Expr13)*
Expr13 ← Expr14 ("^" Expr14)*
Expr14 ← ("+" / "-" / "!") Expr15
Expr15 ← Expr16 (MethodCallExpr / TableIndexExpr)?
Expr16 ← "(" Expr1 ")" / FunctionCallExpr / Expr17
Expr17 ← Number / String / "~" Var / "$" Var / "->" Var / Expr18
Expr18 ← !(Var "++") !(Var "--") Expr19
Expr19 ← Var
*/

typedef SException = haxe.Exception;
typedef FunctionParams = Array<{name: String, type: String}>;

typedef Trace = {
	line: Int,
	char: Int
}

typedef Instruction = {
	name: String,
	trace: Trace,
	args: Array<Dynamic> // Arguments to be passed to the compiler.
}

class Parser {
	// Immutable
	public var tokens: Array<Token>;
	public var count: Int;

	public var index: Int; // current token index
	public var token: Token;
	public var readtoken: Null<Token>;
	var exprtoken: Null<Token>;
	var delta: Map<String, Bool>;

	var depth = 0;

	public function new() {
		this.tokens = [];
		this.index = 0;
		this.count = 0;

		this.token = null;
		this.readtoken = null;
		this.exprtoken = null;
	}

	// For now
	function error(msg: String, ?tok: Null<Token>) {
		if (tok != null) {
			throw new ParseError('$msg at line ${ token.line }, char ${ token.char }');
		}
		throw new ParseError('$msg at line ${ this.token.line }, char ${ this.token.char }');
	}


	public function process(tokens: Array<Token>): Instruction {
		this.tokens = tokens;
		this.index = 0;
		this.count = tokens.length;

		this.nextToken();

		return this.root();
	}

	inline function getToken(): Token {
		return this.token;
	}

	inline function getTokenRaw(): String {
		return this.token.raw;
	}

	function getLiteralString(): String {
		switch (this.token.literal) {
			case String(str): return str;
			case Number(_n): throw "Tried to get a string from a number literal!";
			case Void: throw "Tried to get a string from a void!";
		}
	}

	function getLiteralNumber(): E2Number {
		switch (this.token.literal) {
			case String(_str): throw "Tried to get a number from a string literal!";
			case Number(n): return n;
			case Void: throw "Tried to get a number from a void!";
		}
	}

	function getTokenTrace(): Trace {
		if (this.token == null)
			return { line: 1, char: 0 };

		return { line: this.token.line, char: this.token.char };
	}

	function instruction(tr: Trace, name: String, args: Array<Dynamic>): Instruction {
		return { trace: tr, name: name, args: args };
	}

	function hasTokens(): Bool {
		return this.readtoken != null;
	}

	function nextToken() {
		if ( this.index <= this.count ) {
			this.token = (index > 0) ? this.readtoken : new Token(0, 0, "", "", TokenFlag.None, TokenType.Invalid);

			this.readtoken = this.tokens[ this.index++ ];
		} else {
			this.readtoken = null;
		}
	}

	function trackBack() {
		this.index -= 2;
		this.nextToken();
	}

	// Accepts a token with an identifier from the list in Tokenizer.hx
	function acceptRoamingToken(id: String, ?raw: String): Bool {
		final token = this.readtoken;
		if ( token == null || token.id != id )
			return false;

		if (raw != null && token.raw != raw)
			return false;

		this.nextToken();
		return true;
	}

	function acceptRoamingType(?ty: String): Bool {
		final token = this.readtoken;
		if ( token == null || token.id != "lower_ident" )
			return false;

		if (!token.properties.get("type"))
			return false;

		if (ty != null && token.raw != ty)
			return false;

		this.nextToken();

		return true;
	}

	function acceptTailingToken(id: String, ?raw: String): Bool {
		final tok = this.readtoken;
		if (tok == null || tok.whitespaced)
			return false;

		return this.acceptRoamingToken(id, raw);
	}

	function acceptLeadingToken(id: String, ?raw: String): Bool {
		final tok = this.tokens[this.index + 1];
		if (tok == null || tok.whitespaced)
			return false;

		return this.acceptRoamingToken(id, raw);
	}

	function recurseLeftOp(func: ()->Instruction, ops: Array<String>, op_names: Array<String>): Instruction {
		var expr = func();
		var hit = true;
		while(hit) {
			hit = false;
			for (ind => op_raw in ops) {
				if ( this.acceptRoamingToken( "operator", op_raw ) ) {
					hit = true;
					expr = this.instruction( this.getTokenTrace(), op_names[ind], [expr, func()] );
					break;
				}
			}
		}
		return expr;
	}

	function root(): Instruction {
		this.depth = 0;
		return this.stmts();
	}

	function stmts(): Instruction {
		var trace = this.getTokenTrace();
		var stmts = this.instruction(trace, "root", []);

		if (!this.hasTokens())
			return stmts;

		while (true) {
			if (this.acceptRoamingToken("grammar", ","))
				this.error("Statement separator (,) must not appear multiple times");

			stmts.args.push(this.stmt1());

			if (!this.hasTokens())
				break;

			if ( !this.acceptRoamingToken("grammar", ",") && !this.readtoken.whitespaced )
				this.error("Statements must be separated by comma (,) or whitespace");
		}

		return stmts;
	}

	function acceptCondition() {
		if (!this.acceptRoamingToken("grammar", "("))
			this.error("Left parenthesis (() expected before condition");

		var expr = this.expr1();

		if (!this.acceptRoamingToken("grammar", ")"))
			this.error("Right parenthesis ()) missing, to close condition");

		return expr;
	}

	// TODO Maybe type this.
	function acceptIndex(): Null<Array<Null<{ type: Null<String>, trace: Trace, key: Instruction }>>> {
		if (this.acceptTailingToken("grammar", "[")) {
			var trace = this.getTokenTrace();
			var exp = this.expr1();

			if (this.acceptRoamingToken("grammar", ",")) {
				if (!this.acceptRoamingType())
					this.error("Indexing operator ([]) requires a lowercase type [X,t]");

				var typename = this.getTokenRaw();

				if (!this.acceptRoamingToken("grammar", "]"))
					this.error("Right square bracket (]) missing, to close indexing operator [X,t]");

				final tp = wire_expression_types.get(typename);
				if (tp == null)
					this.error('Indexing operator ([]) does not support the type [$typename]');

				// TODO This should be a multi-return
				var out = [ { key: exp, type: tp.id, trace: trace } ];
				var ind = this.acceptIndex();
				if (ind != null)
					out = out.concat(ind);
				return out;
			} else if (this.acceptTailingToken("grammar", "]")) {
				return [ { key: exp, type: null, trace: trace }, null ];
			} else {
				this.error("Indexing operator ([]) must not be preceded by whitespace");
			}
		}
		return null;
	}

	function acceptBlock(block_name: String = "condition") {
		var trace = this.getTokenTrace();
		var stmts = this.instruction(trace, "root", []);

		if (!this.acceptRoamingToken("grammar", "{"))
			this.error('Left curly bracket ({) expected after $block_name');

		var token = this.getToken();

		if (this.acceptRoamingToken("grammar", "}"))
			return stmts;

		if (this.hasTokens()) {
			while (true) {
				if (this.acceptRoamingToken("grammar", ",")) {
					this.error("Statement separator (,) must not appear multiple times");
				} else if (this.acceptRoamingToken("grammar", "}")) {
					this.error("Statement separator (,) must be suceeded by statement");
				}

				stmts.args.push( this.stmt1() );

				if (this.acceptRoamingToken("grammar", "}"))
					return stmts;

				if (!this.acceptRoamingToken("grammar", ",")) {
					if (!this.hasTokens())
						break;

					if (!this.readtoken.whitespaced)
						this.error("Statements must be separated by comma (,) or whitespace");

				}
			}
		}

		this.error("Right curly bracket (}) missing, to close switch block", token);
		return null;
	}

	function acceptIfElseIf(): Array<Instruction> {
		var args = [];
		while (true) {
			if (this.acceptRoamingToken("keyword", "elseif")) {
				args.push(
					this.instruction(this.getTokenTrace(), "if", [this.acceptCondition(), this.acceptBlock("elseif condition"), null, false])
				);
			} else if(this.acceptRoamingToken("keyword", "else")) {
				args.push(
					this.instruction(this.getTokenTrace(), "if", [null, this.acceptBlock("else"), null, true])
				);
				break;
			} else {
				break;
			}
		}

		return args;
	}

	function acceptIfElse() {
		if (this.acceptRoamingToken("keyword", "else"))
			return this.acceptBlock("else");

		trace("root?");
		return this.instruction( this.getTokenTrace(), "root", [] );
	}

	function acceptCaseBlock() {
		if (this.hasTokens()) {
			var stmts = this.instruction(this.getTokenTrace(), "root", []);

			if (this.hasTokens()) {
				while (true) {
					if (this.acceptRoamingToken("keyword", "case") || this.acceptRoamingToken("keyword", "default") || this.acceptRoamingToken("grammar", "}")) {
						this.trackBack();
						return stmts;
					} else if (this.acceptRoamingToken("grammar", ",")) {
						this.error("Statement separator (,) must not appear multiple times");
					} else if (this.acceptRoamingToken("grammar", "}")) {
						this.error("Statement separator (,) must be suceeded by statement");
					}

					stmts.args.push(this.stmt1());

					if (!this.acceptRoamingToken("grammar", ",")) {
						if (!this.hasTokens())
							break;

						if (!this.readtoken.whitespaced)
							this.error("Statements must be separated by comma (,) or whitespace");
					}
				}
			}
		} else {
			this.error("Case block is missing after case declaration.");
		}
		return null;
	}

	function acceptSwitchBlock(): Array<{ ?match: Instruction, block: Instruction }> {
		var cases: Array<{ ?match: Instruction, block: Instruction }> = [];
		var def = false;

		if ( this.hasTokens() && !this.acceptRoamingToken("grammar", ")") ) {
			if (!this.acceptRoamingToken("keyword", "case") && !this.acceptRoamingToken("keyword", "default"))
				this.error("Case Operator (case) expected in case block.", this.getToken());

			this.trackBack();

			while (true) {
				if (this.acceptRoamingToken("keyword", "case")) {
					var expr = this.expr1();

					if (!this.acceptRoamingToken("grammar", ","))
						this.error("Comma (,) expected after case condition");

					cases.push( { match: expr, block: this.acceptCaseBlock() } );
				} else if (this.acceptRoamingToken("keyword", "default")) {
					if (def)
						this.error("Only one default case (default:) may exist.");

					if (!this.acceptRoamingToken("grammar", ","))
						this.error("Comma (,) expected after default case");
					def = true;
					cases.push( { match: null, block: this.acceptCaseBlock() } );
				} else {
					break;
				}
			}
		}

		if (!this.acceptRoamingToken("grammar", "}"))
			this.error("Right curly bracket (}) missing, to close statement block", this.getToken());

		return cases;
	}

	function acceptFunctionArgs(used_vars: StringMap<Bool>, args: FunctionParams) {
		if ( this.hasTokens() && !this.acceptRoamingToken("grammar", ")") ) {
			while (true) {
				if (this.acceptRoamingToken("grammar", ","))
					this.error("Argument separator (,) must not appear multiple times");

				if ( this.acceptRoamingToken("ident") || this.acceptRoamingToken("lower_ident") ) {
					this.acceptFunctionArg(used_vars, args);
				} else if ( this.acceptRoamingToken("grammar", "[") ) {
					this.acceptFunctionArgList(used_vars, args);
				}

				if ( this.acceptRoamingToken("grammar", ")") ) {
					break;
				} else if ( !this.acceptRoamingToken("grammar", ",") ) {
					this.nextToken();
					this.error("Right parenthesis ()) expected after function arguments");
				}
			}
		}
	}

	function acceptFunctionArg(used_vars: StringMap<Bool>, args: FunctionParams) {
		var type = "number";

		var name = this.getTokenRaw();
		if (name == null)
			this.error("Variable required");

		if (used_vars.exists(name))
			this.error('Variable \'$name\' is already used as an argument,');

		if (this.acceptRoamingToken("grammar", ":")) {
			if (this.acceptRoamingType()) {
				type = this.getTokenRaw();
			} else {
				this.error("Type expected after colon (:)");
			}
		}

		if ( !wire_expression_types.exists(type)  )
			this.error('Type $type does not exist.');

		// TODO: Check if type exists here

		used_vars.set(name, true);
		args.push( { name: name, type: type } );
	}

	function acceptFunctionArgList(used_vars: StringMap<Bool>, args: FunctionParams) {
		if (this.hasTokens()) {
			var vars: Array<String> = [];
			while (true) {
				if (this.acceptRoamingToken("ident")) {
					var name = this.getTokenRaw();

					if (name == null)
						this.error("Variable required");

					if ( used_vars.exists(name) )
						this.error('Variable \'$name\' is already used as an argument');

					used_vars.set(name, true);
					vars.push(name);
				} else if ( this.acceptRoamingToken("grammar", "]") ) {
					break;
				} else { // if !self:HasTokens() then
					this.nextToken();
					this.error("Right square bracket (]) expected at end of argument list");
				}
			}

			if (vars.length == 0) {
				this.trackBack();
				this.trackBack();
				this.error("Variables expected in variable list");
			}

			var type = "number";

			if ( this.acceptRoamingToken("grammar", ":") ) {
				if ( this.acceptRoamingType() ) {
					type = this.getTokenRaw();
				} else {
					this.error("Type expected after colon (:)");
				}
			}

			if (type != type.toLowerCase())
				this.error("Type must be lowercased");

			type = type.toUpperCase();

			// TODO: Check if type exists here

			for (v in vars) {
				args.push( {name: v, type: type} );
			}
		} else {
			this.error("Variable expected after left square bracket ([) in argument list");
		}
	}

	function stmt1() {
		if (this.acceptRoamingToken("keyword", "if")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, "if", [this.acceptCondition(), this.acceptBlock("if condition"), this.acceptIfElseIf(), false] );
		}
		return this.stmt2();
	}

	function stmt2() {
		if (this.acceptRoamingToken("keyword", "while")) {
			var trace = this.getTokenTrace();
			this.depth++;
			var whl = this.instruction( trace, "while", [this.acceptCondition(), this.acceptBlock("while condition"), false] );
			this.depth--;
			return whl;
		}

		return this.stmt3();
	}

	function stmt3(): Instruction {
		if (this.acceptRoamingToken("keyword", "for")) {
			var trace = this.getTokenTrace();
			this.depth++;

			if (!this.acceptRoamingToken("grammar", "("))
				this.error("Left parenthesis (() must appear before condition");

			if (!this.acceptRoamingToken("ident"))
				this.error("Variable expected for the numeric index");

			var v = this.getTokenRaw();

			if (!this.acceptRoamingToken("operator", "="))
				this.error("Assignment operator (=) expected to preceed variable");

			var estart = this.expr1();

			if (!this.acceptRoamingToken("grammar", ","))
				this.error("Comma (,) expected after start value");

			var estop = this.expr1();

			var estep = null;
			if (this.acceptRoamingToken("grammar", ","))
				estep = this.expr1();

			if (!this.acceptRoamingToken("grammar", ")"))
				this.error("Right parenthesis ()) missing, to close condition");

			var sfor = this.instruction( trace, "for", [v, estart, estop, estep, this.acceptBlock("for statement")] );

			this.depth--;
			return sfor;
		}

		return this.stmt4();
	}

	function stmt4(): Instruction {
		if (this.acceptRoamingToken("keyword", "foreach")) {
			var trace = this.getTokenTrace();
			this.depth++;

			if (!this.acceptRoamingToken("grammar", "("))
				this.error("Left parenthesis missing (() after foreach statement");

			if (!this.acceptRoamingToken("ident"))
				this.error("Variable expected to hold the key");

			var keyvar = this.getTokenRaw();

			var keytype = null;

			if (this.acceptRoamingToken("grammar", ":")) {
				if (!this.acceptRoamingType())
					this.error("Type expected after colon");

				keytype = this.getTokenRaw();

				var typ = wire_expression_types.get(keytype);
				if (typ == null)
					this.error('Unknown type: $keytype');

				keytype = typ.id;
			}

			if (!this.acceptRoamingToken("grammar", ","))
				this.error("Comma (,) expected after key variable");

			if (!this.acceptRoamingToken("ident"))
				this.error("Variable expected to hold the value");

			var valvar = this.getTokenRaw();

			if (!this.acceptRoamingToken("grammar", ":"))
				this.error("Colon (:) expected to separate type from variable");

			if (!this.acceptRoamingType())
				this.error("Type expected after colon");

			var valtype = this.getTokenRaw();

			var typ = wire_expression_types.get(valtype);
			if (typ == null)
				this.error('Unknown type: $valtype');

			valtype = typ.id;

			if (!this.acceptRoamingToken("operator", "="))
				this.error("Equals sign (=) expected after value type to specify table");

			var tableexpr = this.expr1();

			if (!this.acceptRoamingToken("grammar", ")"))
				this.error("Missing right parenthesis after foreach statement");

			var sfea = this.instruction(trace, "foreach", [keyvar, keytype, valvar, valtype, tableexpr, this.acceptBlock("foreach statement")] );
			this.depth--;
			return sfea;
		}

		return this.stmt5();
	}

	function stmt5(): Instruction {
		if (this.acceptRoamingToken("keyword", "break")) {
			if (this.depth > 0) {
				var trace = this.getTokenTrace();
				return this.instruction(trace, "break", []);
			} else {
				this.error("Break may not exist outside of a loop");
			}
		} else if (this.acceptRoamingToken("keyword", "continue")) {
			if (this.depth > 0) {
				var trace = this.getTokenTrace();
				return this.instruction(trace, "continue", []);
			} else {
				this.error("Continue may not exist outside of a loop");
			}
		}

		return this.stmt6();
	}

	function stmt6(): Instruction {
		if (this.acceptRoamingToken("ident")) {
			var trace = this.getTokenTrace();
			var v = this.getTokenRaw();

			if (this.acceptTailingToken("operator", "++")) {
				return this.instruction( trace, "increment", [v] );
			} else if (this.acceptRoamingToken("operator", "++")) {
				this.error("Increment operator (++) must not be preceded by whitespace");
			}

			if (this.acceptTailingToken("operator", "--")) {
				return this.instruction( trace, "decrement", [v] );
			} else if (this.acceptRoamingToken("operator", "--")) {
				this.error("Decrement operator (--) must not be preceded by whitespace");
			}
			this.trackBack();
		}

		return this.stmt7();
	}

	function stmt7(): Instruction {
		if (this.acceptRoamingToken("ident")) {
			var trace = this.getTokenTrace();
			var v = this.getTokenRaw();

			if (this.acceptRoamingToken("operator", "+=")) {
				return this.instruction( trace, "assign", [ v, this.instruction(trace, "add", [this.instruction(trace, "variable", [v]), this.expr1()]) ] );
			} else if (this.acceptRoamingToken("operator", "-=")) {
				return this.instruction( trace, "assign", [ v, this.instruction(trace, "sub", [this.instruction(trace, "variable", [v]), this.expr1()]) ] );
			} else if (this.acceptRoamingToken("operator", "*=")) {
				return this.instruction( trace, "assign", [ v, this.instruction(trace, "mul", [this.instruction(trace, "variable", [v]), this.expr1()]) ] );
			} else if (this.acceptRoamingToken("operator", "/=")) {
				return this.instruction( trace, "assign", [ v, this.instruction(trace, "div", [this.instruction(trace, "variable", [v]), this.expr1()]) ] );
			}

			this.trackBack();
		}

		return this.stmt8();
	}

	function stmt8(parentLocalized: Bool = false): Instruction {
		var localized = false;
		if (this.acceptRoamingToken("keyword", "local")) {
			if (parentLocalized)
				this.error("Assignment can't contain roaming local operator");

			localized = true;
		}

		if (this.acceptRoamingToken("ident")) {
			var tbpos = this.index;
			var trace = this.getTokenTrace();
			var v = this.getTokenRaw();

			if (this.acceptTailingToken("grammar", "[")) {
				this.trackBack();

				var ind = this.acceptIndex();
				var indexs = [];
				if (ind != null) {
					for (i in ind)
						indexs.push(i);
				}

				if (this.acceptRoamingToken("operator", "=")) {
					if (localized || parentLocalized)
						this.error("Invalid operator (local).");

					var total = indexs.length;
					var inst = this.instruction( trace, "variable", [v] );

					for (i in 0...total) {
						var idx = indexs[i];
						var key = idx.key;
						var type = idx.type;
						var trace = idx.trace;
						if (i == total-1) {
							inst = this.instruction( trace, "index_set", [inst, key, this.stmt8(false), type] );
						} else {
							inst = this.instruction( trace, "index_get", [inst, key, type] );
						}
					} // Example Result: set( get( get(Var,1,table) ,1,table) ,3,"hello",string)
					return inst;
				}

			} else if (this.acceptRoamingToken("operator", "=")) {
				if (localized || parentLocalized) {
					return this.instruction( trace, "assignlocal", [v, this.stmt8(true)] );
				} else {
					return this.instruction( trace, "assign", [v, this.stmt8(false)] );
				}
			} else if (localized) {
				this.error("Invalid operator (local) must be used for variable declaration.");
			}

			this.index = tbpos - 2;
			this.nextToken();
		} else if (localized) {
			this.error("Invalid operator (local) must be used for variable declaration.");
		}

		return stmt9();
	}

	function stmt9(): Instruction {
		if (this.acceptRoamingToken("keyword", "switch")) {
			var trace = this.getTokenTrace();

			if (!this.acceptRoamingToken("grammar", "("))
				this.error("Left parenthesis (() expected before switch condition");

			var expr = this.expr1();

			if (!this.acceptRoamingToken("grammar", ")"))
				this.error("Right parenthesis ()) expected after switch condition");

			if (!this.acceptRoamingToken("grammar", "{"))
				this.error("Left curly bracket ({) expected after switch condition");

			this.depth++;
			var cases = this.acceptSwitchBlock();
			this.depth--;

			return this.instruction(trace, "switch", [expr, cases]);
		}

		return stmt10();
	}

	function stmt10(): Instruction {
		if (this.acceptRoamingToken("keyword", "function")) {
			var trace = this.getTokenTrace();

			var name: String = null;
			var ret: String = "void";
			var type: String = null; // Metatype <entity>:fnCall()

			var name_token = null;
			var return_token = null;
			var type_token = null;

			var args: FunctionParams = [];
			var used_vars: StringMap<Bool> = new StringMap();

			// Errors are handled after line 49, both 'fun' and 'var' tokens are used for accurate error reports.
			if ( this.acceptRoamingToken("lower_ident") ) {
				name = this.getTokenRaw();
				name_token = this.token; // Copy the current token for error logging

				// Check if previous token was the type rather than the function name
				if ( this.acceptRoamingToken("lower_ident") ) {
					ret = name;
					return_token = name_token;

					name = this.getTokenRaw();
					name_token = this.token;
				}

				// Check if the token before was the metatype
				if (this.acceptRoamingToken("grammar", ":")) {
					if (this.acceptRoamingToken("lower_ident")) {
						type = name;
						type_token = name_token;

						name = this.getTokenRaw();
						name_token = this.token;
					} else {
						this.error("Function name must appear after colon (:)");
					}
				}
			}

			if (ret != "void") {
				if (ret != ret.toLowerCase())
					this.error("Function return type must be lowercased", return_token);

				ret = ret.toUpperCase();

				// TODO: Check if ``ret`` is a valid return type.
			}

			if (type != null) {
				if (type != type.toLowerCase())
					this.error("Function object must be full lowercase", type_token);
				if (type == "void")
					this.error("Void cannot be used as function object type", type_token);

				type = type.toUpperCase();

				// TODO: Check if ``type`` is a valid type.

				used_vars.set("This", true);
				args[0] = { name: "This", type: type };
			}

			if (name == null)
				this.error("Function name must follow function declaration");

			var first_char = name.charAt(0);
			if (first_char != first_char.toLowerCase())
				this.error("Function name must start with a lower case letter", name_token);

			if ( !this.acceptRoamingToken("grammar", "(") )
				this.error("Left parenthesis (() must appear after function name");

			this.acceptFunctionArgs(used_vars, args);

			// TODO: Properly build the signature
			var sig = name + "(";
			for (i in 1...args.length) {
				var arg = args[i];
				sig += wire_expression_types.get(arg.type).id;
				if (i == 1 && arg.name == "This" && type != '') {
					sig += ":";
				}
			}
			sig += ")";

			// TODO: Make sure you can't overwrite existing functions with the signature.

			return this.instruction( trace, "fndecl", [name, ret, type, sig, args, this.acceptBlock("function declaration")] );
		} else if ( this.acceptRoamingToken("keyword", "return") ) {
			var trace = this.getTokenTrace();

			if ( this.acceptRoamingType("void") || (this.readtoken != null && this.readtoken.raw == "}" /* check if readtoken is rcb */ ) )
				return this.instruction( trace, "return", [] );

			return this.instruction( trace, "return", [this.expr1()] );
		} else if ( this.acceptRoamingType("void") ) {
			this.error("Void may only exist after return");
		}

		return stmt11();
	}

	// do {} while(1)
	function stmt11(): Instruction {
		if (this.acceptRoamingToken("keyword", "do")) {
			var trace = this.getTokenTrace();

			this.depth++;
			var block = this.acceptBlock("do keyword");

			if ( !this.acceptRoamingToken("keyword", "while") )
				this.error("while expected after do block");

			var condition = this.acceptCondition();

			final instr = this.instruction( trace, "while", [condition, block, true] );
			this.depth--;
			return instr;
		}
		return stmt12();
	}

	/**
	 *	```
	 *	try {
	 *		error("hi")
	 *	} catch(Err) {
	 *		print(Err)
	 *	}
	**/
	function stmt12(): Instruction {
		if (this.acceptRoamingToken("keyword", "try")) {
			var trace = this.getTokenTrace();
			var stmt = this.acceptBlock("try block");

			if (!this.acceptRoamingToken("keyword", "catch"))
				this.error("Try block must be followed by catch statement");

			if (!this.acceptRoamingToken("grammar", "("))
				this.error("Left parenthesis (() expected after catch keyword");

			if (!this.acceptRoamingToken("ident"))
				this.error("Variable expected after left parenthesis (() in catch statement");

			var var_name = this.getTokenRaw();

			if (!this.acceptRoamingToken("grammar", ")"))
				this.error("Right parenthesis ()) missing, to close catch statement");

			return this.instruction(trace, "try", [stmt, var_name, this.acceptBlock("catch block")] );
		}
		return expr1();
	}

	function expr1(): Instruction {
		this.exprtoken = this.getToken();

		if (this.acceptRoamingToken("ident")) {
			if (this.acceptRoamingToken("operator", "="))
				this.error("Assignment operator (=) must not be part of equation");

			if (this.acceptRoamingToken("operator", "+=")) {
				this.error("Additive assignment operator (+=) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "-=")) {
				this.error("Subtractive assignment operator (-=) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "*=")) {
				this.error("Multiplicative assignment operator (*=) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "/=")) {
				this.error("Divisive assignment operator (/=) must not be part of equation");
			}

			this.trackBack();
		}

		return this.expr2();
	}

	function expr2(): Instruction {
		var expr = this.expr3();

		if (this.acceptRoamingToken("operator", "?")) {
			var trace = this.getTokenTrace();
			var exprtrue = this.expr1();

			if (!this.acceptRoamingToken("grammar", ":"))
				this.error( "Conditional operator (:) must appear after expression to complete conditional", this.getToken() );

			return this.instruction( trace, "ternary", [expr, exprtrue, this.expr1()] );
		}

		if (this.acceptRoamingToken("keyword", "default")) {
			var trace = this.getTokenTrace();

			return this.instruction( trace, "def", [expr, this.expr1()] );
		}

		return expr;
	}

	// Yes, || and && are swapped. They should be logical ops but they are binary ops.
	// We're trying to keep parity with E2, so this will be kept.
	function expr3() return this.recurseLeftOp(this.expr4, ["||"], ["bor"]); // bitwise or
	function expr4() return this.recurseLeftOp(this.expr5, ["&&"], ["band"]); // bitwise and
	function expr5() return this.recurseLeftOp(this.expr6, ["|"], ["or"]); // logical or
	function expr6() return this.recurseLeftOp(this.expr7, ["&"], ["and"]); // logical and
	function expr7() return this.recurseLeftOp(this.expr8, ["^^"], ["xor"]); // binary xor
	function expr8() return this.recurseLeftOp(this.expr9, ["==", "!="], ["eq", "neq"]);
	function expr9() return this.recurseLeftOp(this.expr10, [">", "<", ">=", "<="], ["gt", "lt", "geq", "leq"]);
	function expr10() return this.recurseLeftOp(this.expr11, [">>", "<<"], ["bshl", "bshr"]);
	function expr11() return this.recurseLeftOp(this.expr12, ["+", "-"], ["add", "sub"]);
	function expr12() return this.recurseLeftOp(this.expr13, ["*", "/", "%"], ["mul", "div", "mod"]);
	function expr13() return this.recurseLeftOp(this.expr14, ["^"], ["exp"]); // exponent

	function expr14() {
		if (this.acceptLeadingToken("operator", "+")) {
			return this.expr15();
		} else if (this.acceptRoamingToken("operator", "+")) {
			this.error("Identity operator (+) must not be succeeded by whitespace");
		}

		if (this.acceptLeadingToken("operator", "-")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, "neg", [this.expr15()] );
		} else if (this.acceptRoamingToken("operator", "-")) {
			this.error("Negation operator (-) must not be succeeded by whitespace");
		}

		if (this.acceptLeadingToken("operator", "!")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, "not", [this.expr14()] );
		} else if (this.acceptRoamingToken("operator", "!")) {
			this.error("Logical not operator (!) must not be succeeded by whitespace");
		}

		return this.expr15();
	}

	function expr15() {
		var expr = this.expr16();

		while (true) {
			if (this.acceptTailingToken("grammar", ":")) {
				if (!this.acceptTailingToken("lower_ident")) {
					if (this.acceptRoamingToken("lower_ident")) {
						this.error("Method operator (:) must not be preceded by whitespace");
					} else {
						this.error("Method operator (:) must be followed by method name");
					}
				}

				var trace = this.getTokenTrace();
				var fun = this.getTokenRaw();

				if (!this.acceptTailingToken("grammar", "(")) {
					if (this.acceptRoamingToken("grammar", "(")) {
						this.error("Left parenthesis (() must not be preceded by whitespace");
					} else {
						this.error("Left parenthesis (() must appear after method name");
					}
				}

				var token = this.getToken();

				if (this.acceptRoamingToken("grammar", ")")) {
					expr = this.instruction( trace, "methodcall", [fun, expr] );
				} else {
					var exprs = [this.expr1()];

					while (this.acceptRoamingToken("grammar", ",")) {
						exprs.push( this.expr1() );
					}

					if (!this.acceptRoamingToken("grammar", ")"))
						this.error("Right parenthesis ()) missing, to close method argument list", token);

					expr = this.instruction( trace, "methodcall", [fun, expr, exprs] );
				}
			} else if (this.acceptTailingToken("grammar", "[")) {
				var trace = this.getTokenTrace();

				if (this.acceptRoamingToken("grammar", "]"))
					this.error("Indexing operator ([]) requires an index [X]");

				var aexpr = this.expr1();
				if (this.acceptRoamingToken("grammar", ",")) {
					if (!this.acceptRoamingType())
						this.error("Indexing operator ([]) requires a lower case type [X,t]");

					// TODO: maybe replace with another function
					var longtp = this.getTokenRaw();

					if (!this.acceptRoamingToken("grammar", "]"))
						this.error("Right square bracket (]) missing, to close indexing operator [X,t]");

					var typ = wire_expression_types.get(longtp);
					if (typ == null)
						this.error('Indexing operator ([]) does not support the type [$longtp]');

					expr = this.instruction( trace, "index_get", [expr, aexpr, typ.id] );
				} else if (this.acceptRoamingToken("grammar", "]")) {
					expr = this.instruction( trace, "index_get", [expr, aexpr] );
				} else {
					this.error("Indexing operator ([]) needs to be closed with comma (,) or right square bracket (])");
				}
			} else if (this.acceptRoamingToken("grammar", "[") && this.token.whitespaced) {
				this.error("Indexing operator ([]) must not be preceded by whitespace");
			} else if (this.acceptTailingToken("grammar", "(")) {
				var trace = this.getTokenTrace();

				var token = this.getToken();
				var exprs: Array<Instruction> = [];

				if (this.acceptRoamingToken("grammar", ")")) {
					exprs = [];
				} else {
					exprs = [ this.expr1() ];

					while (this.acceptRoamingToken("grammar", ",")) {
						exprs.push( this.expr1() );
					}

					if (!this.acceptRoamingToken("grammar", ")"))
						this.error("Right parenthesis ()) missing, to close function argument list", token);
				}

				if (this.acceptRoamingToken("grammar", "[")) {
					if (!this.acceptRoamingType())
						this.error('Return type operator ([]) does not support the type [${ this.getTokenRaw() }]');

					var longtp = this.getTokenRaw();

					if (!this.acceptRoamingToken("grammar", "]"))
						this.error("Right square bracket (]) missing, to close return type operator");

					var stype = wire_expression_types.get( longtp ).id;

					expr = this.instruction( trace, "stringcall", [expr, exprs, stype] );
				} else {
					expr = this.instruction( trace, "stringcall", [expr, exprs, null] );
				}
			} else {
				break;
			}
		}

		return expr;
	}

	function expr16() {
		if (this.acceptRoamingToken("grammar", "(")) {
			var trace = this.getTokenTrace();
			var token = this.getToken();
			var expr = this.expr1();

			if (!this.acceptRoamingToken("grammar", ")")) {
				this.error("Right parenthesis ()) missing, to close grouped equation", token);
			}

			return this.instruction( trace, "grouped_equation", [expr] );
		}

		if (this.acceptRoamingToken("lower_ident")) {
			var trace = this.getTokenTrace();

			var fun = this.getTokenRaw();

			if (!this.acceptTailingToken("grammar", "(")) {
				if (this.acceptRoamingToken("grammar", "(")) {
					this.error("Left parenthesis (() must not be preceded by whitespace");
				} else {
					this.error("Left parenthesis (() must appear after function name, variables must start with uppercase letter,");
				}
			}

			var token = this.getToken();

			if (this.acceptRoamingToken("grammar", ")")) {
				return this.instruction(trace, "call", [fun, []]);
			} else {
				var kv_exprs = new Map();
				var i_exprs = [];

				// TODO: Make this work for all functions.
				// So you can declare a kvtable / itable function and use them as params.
				// table( "yes" = "no", 5 = 2 )
				if (fun == "table" || fun == "array") {
					var kvtable = false;
					var key = this.expr1();

					if (this.acceptRoamingToken("operator", "=")) {
						if (this.acceptRoamingToken("grammar", ")"))
							this.error("Expression expected, got right paranthesis ())", this.getToken());

						kv_exprs[key] = this.expr1();
						kvtable = true;
					} else { // If it isn't a "table( str=val, ...)", { it's a "table( val,val,val,... )"
						i_exprs = [key];
					}

					if (kvtable) {
						while (this.acceptRoamingToken("grammar", ",")) {
							var key = this.expr1();
							var token = this.getToken();

							if (this.acceptRoamingToken("operator", "=")) {
								if (this.acceptRoamingToken("grammar", ")"))
									this.error("Expression expected, got right paranthesis ())", this.getToken());

								kv_exprs[key] = this.expr1();
							} else {
								this.error("Assignment operator (=) missing, to complete expression", token);
							}
						}

						if (!this.acceptRoamingToken("grammar", ")"))
							this.error("Right parenthesis ()) missing, to close function argument list", this.getToken());

						return this.instruction( trace, 'kv$fun', [kv_exprs, i_exprs] );
					}
				} else {
					i_exprs = [this.expr1()];
				}

				while (this.acceptRoamingToken("grammar", ","))
					i_exprs.push( this.expr1() );

				if (!this.acceptRoamingToken("grammar", ")"))
					this.error("Right parenthesis ()) missing, to close function argument list", token);

				return this.instruction( trace, "call", [fun, kv_exprs, i_exprs] );
			}
		}

		return this.expr17();
	}

	function expr17() {
		if (this.acceptRoamingToken("number")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, "literal", [this.token.literal, this.token.raw] );
		}

		if (this.acceptRoamingToken("string")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, "literal", [this.token.literal, this.token.raw] );
		}

		if (this.acceptRoamingToken("operator", "~")) {
			var trace = this.getTokenTrace();

			if (!this.acceptTailingToken("ident")) {
				if (this.acceptRoamingToken("ident")) {
					this.error("Triggered operator (~) must not be succeeded by whitespace");
				} else {
					this.error("Triggered operator (~) must be preceded by variable");
				}
			}

			var v = this.getLiteralString();
			return this.instruction( trace, "trg", [v] );
		}

		if (this.acceptRoamingToken("operator", "$")) {
			var trace = this.getTokenTrace();

			if (!this.acceptTailingToken("ident")) {
				if (this.acceptRoamingToken("ident")) {
					this.error("Delta operator ($) must not be succeeded by whitespace");
				} else {
					this.error("Delta operator ($) must be preceded by variable");
				}
			}

			var v = this.getTokenRaw();
			this.delta.set(v, true);

			return this.instruction( trace, "dlt", [v] );
		}

		if (this.acceptRoamingToken("operator", "->")) {
			var trace = this.getTokenTrace();

			if (!this.acceptTailingToken("ident")) {
				if (this.acceptRoamingToken("ident")) {
					this.error("Connected operator (->) must not be succeeded by whitespace");
				} else {
					this.error("Connected operator (->) must be preceded by variable");
				}
			}

			var v = this.getLiteralString();
			return this.instruction( trace, "iwc", [v] );
		}

		return this.expr18();
	}

	function expr18() {
		if (this.acceptRoamingToken("ident")) {
			if (this.acceptTailingToken("operator", "++")) {
				this.error("Increment operator (++) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "++")) {
				this.error("Increment operator (++) must not be preceded by whitespace");
			}

			if (this.acceptTailingToken("operator", "--")) {
				this.error("Decrement operator (--) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "--")) {
				this.error("Decrement operator (--) must not be preceded by whitespace");
			}

			this.trackBack();
		}

		return this.expr19();
	}

	function expr19() {
		if (this.acceptRoamingToken("ident")) {
			return this.instruction( this.getTokenTrace(), "variable", [this.getTokenRaw()] );
		}

		return this.exprError();
	}

	function exprError() {
		if(!this.hasTokens())
			this.error("Further input required at } of code, incomplete expression", this.exprtoken);

		if (this.acceptRoamingToken("operator", "+")) {
			this.error("Addition operator (+) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "-")) { // can't occur (unary minus)
			this.error("Subtraction operator (-) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "*")) {
			this.error("Multiplication operator (*) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "/")) {
			this.error("Division operator (/) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "%")) {
			this.error("Modulo operator (%) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "^")) {
			this.error("Exponentiation operator (^) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "=")) {
			this.error("Assignment operator (=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "+=")) {
			this.error("Additive assignment operator (+=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "-=")) {
			this.error("Subtractive assignment operator (-=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "*=")) {
			this.error("Multiplicative assignment operator (*=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "/=")) {
			this.error("Divisive assignment operator (/=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "&")) {
			this.error("Logical and operator (&) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "|")) {
			this.error("Logical or operator (|) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "==")) {
			this.error("Equality operator (==) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "!=")) {
			this.error("Inequality operator (!=) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", ">=")) {
			this.error("Greater than or equal to operator (>=) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "<=")) {
			this.error("Less than or equal to operator (<=) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", ">")) {
			this.error("Greater than operator (>) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "<")) {
			this.error("Less than operator (<) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "++")) {
			this.error("Increment operator (++) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "--")) {
			this.error("Decrement operator (--) must be preceded by variable");
		} else if (this.acceptRoamingToken("grammar", ")")) {
			this.error("Right parenthesis ()) without matching left parenthesis");
		} else if (this.acceptRoamingToken("grammar", "(")) {
			this.error("Left curly bracket ({) must be part of an if/while/for-statement block");
		} else if (this.acceptRoamingToken("grammar", "{")) {
			this.error("Right curly bracket (}) without matching left curly bracket");
		} else if (this.acceptRoamingToken("grammar", "[")) {
			this.error("Left square bracket ([) must be preceded by variable");
		} else if (this.acceptRoamingToken("grammar", "]")) {
			this.error("Right square bracket (]) without matching left square bracket");
		} else if (this.acceptRoamingToken("grammar", ",")) {
			this.error("Comma (,) not expected here, missing an argument?");
		} else if (this.acceptRoamingToken("operator", ":")) {
			this.error("Method operator (:) must not be preceded by whitespace");
		} else if (this.acceptRoamingToken("keyword", "if")) {
			this.error("If keyword (if) must not appear inside an equation");
		} else if (this.acceptRoamingToken("keyword", "elseif")) {
			this.error("Else-if keyword (} else if) must be part of an if-statement");
		} else if (this.acceptRoamingToken("keyword", "else")) {
			this.error("Else keyword (else) must be part of an if-statement");
		} else {
			this.error('Unexpected token found (${ this.readtoken.id })');
		}
		return null;
	}
}