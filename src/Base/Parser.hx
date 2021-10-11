package base;
import haxe.ds.StringMap;

using Safety;
using haxe.ds.Option;
using hx.strings.Strings;

using lib.Error;
using lib.Instructions;

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

class Parser {
	// Immutable
	public var tokens: Array<Token>;
	public var count: Int;

	public var index: Int; // current token index
	public var token: Null<Token>; // It's only null when you first create the parser. Will be filled when you run process on it.
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

		this.delta = [];
	}


	public function process(tokens: Array<Token>): Instruction {
		this.tokens = tokens;
		this.index = 0;
		this.count = tokens.length;

		this.nextToken();

		try {
			return this.root();
		} catch(E: ParseError) {
			final trace = E.trace.or( this.getToken().trace );
			throw new ParseError('${E.message} at line ${ trace.line }, char ${ trace.char }');
		}
	}

	inline function getToken(): Token {
		return this.token.sure();
	}

	inline function getTokenRaw(): String {
		return this.getToken().raw;
	}

	function getLiteralString(): String {
		switch (this.getToken().literal) {
			case String(str): return str;
			case Number(_n): throw "Tried to get a string from a number literal!";
			case Void: throw "Tried to get a string from a void!";
		}
	}

	function getLiteralNumber(): E2Number {
		switch (this.getToken().literal) {
			case String(_str): throw "Tried to get a number from a string literal!";
			case Number(n): return n;
			case Void: throw "Tried to get a number from a void!";
		}
	}

	function getTokenTrace(): Trace {
		return this.getToken().trace;
	}

	@:nullSafety(Strict)
	function instruction(tr: Trace, id: Instr, args: InstructionArgs): Instruction {
		return { trace: tr, id: id, args: args };
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

	/**
	 * Returns whether the token is whitespaced. If tok is null then return false.
	 */
	function isWhitespaced(token: Null<Token>) {
		if (token != null) {
			return token.whitespaced;
		}
		return false;
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

		if (!token.properties.exists("type"))
			return false;

		if (ty != null && token.raw != ty)
			return false;

		this.nextToken();

		return true;
	}

	function assertRoamingType(?ty: String, msg: String = "Not an existing type! Got <T>"): lib.Std.E2TypeDef {
		final token = this.readtoken;

		if ( token == null || token.id != "lower_ident" )
			throw new TypeError("Expected a lowercase type");

		if (!token.properties.exists("type"))
			throw new TypeError( msg.replaceAll("<T>", token.raw) );

		var typ = wire_expression_types.get(token.raw);

		this.nextToken();

		return typ.sure();
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

	function recurseLeftOp(func: ()->Instruction, ops: Array<String>, op_ids: Array<Instr>): Instruction {
		var expr = func();
		var hit = true;
		while(hit) {
			hit = false;
			for (ind => op_raw in ops) {
				if ( this.acceptRoamingToken( "operator", op_raw ) ) {
					hit = true;
					expr = this.instruction( this.getTokenTrace(), op_ids[ind], [expr, func()] );
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

	function stmts() {
		var trace = this.getTokenTrace();
		var stmts = this.instruction(trace, Instr.Root, []);

		if (!this.hasTokens())
			return stmts;

		while (true) {
			if (this.acceptRoamingToken("grammar", ","))
				throw new SyntaxError("Statement separator (,) must not appear multiple times");

			stmts.args.push(this.stmt1());

			if (!this.hasTokens())
				break;

			if ( !this.acceptRoamingToken("grammar", ",") && !this.isWhitespaced(this.readtoken) )
				throw new SyntaxError("Statements must be separated by comma (,) or whitespace");
		}

		return stmts;
	}

	function acceptCondition() {
		if (!this.acceptRoamingToken("grammar", "("))
			throw new SyntaxError("Left parenthesis (() expected before condition");

		var expr = this.expr1();

		if (!this.acceptRoamingToken("grammar", ")"))
			throw new SyntaxError("Right parenthesis ()) missing, to close condition");

		return expr;
	}

	function acceptIndex(): Null<Array<Null<IndexResult>>> {
		if (this.acceptTailingToken("grammar", "[")) {
			var trace = this.getTokenTrace();
			var exp = this.expr1();

			if (this.acceptRoamingToken("grammar", ",")) {
				final tp = this.assertRoamingType();

				if (!this.acceptRoamingToken("grammar", "]"))
					throw new SyntaxError("Right square bracket (]) missing, to close indexing operator [X,t]");

				var out: Array<Null<IndexResult>> = [ { key: exp, type: tp.id, trace: trace } ];

				// If successfully accepted an index, push to list of index ops
				this.acceptIndex().apply((idx) -> out = out.concat(idx));

				return out;
			} else if (this.acceptTailingToken("grammar", "]")) {
				// This used to be [ {...}, null ], might cause problems with removing the null.
				return [ { key: exp, type: null, trace: trace } ];
			} else {
				throw new SyntaxError("Indexing operator ([]) must not be preceded by whitespace");
			}
		}
		return null;
	}

	function acceptBlock(block_name: String = "condition") {
		var trace = this.getTokenTrace();
		var stmts = this.instruction(trace, Instr.Root, []);

		if (!this.acceptRoamingToken("grammar", "{"))
			throw new SyntaxError('Left curly bracket ({) expected after $block_name');

		var token = this.getToken();

		if (this.acceptRoamingToken("grammar", "}"))
			return stmts;

		if (this.hasTokens()) {
			while (true) {
				if (this.acceptRoamingToken("grammar", ",")) {
					throw new SyntaxError("Statement separator (,) must not appear multiple times");
				} else if (this.acceptRoamingToken("grammar", "}")) {
					throw new SyntaxError("Statement separator (,) must be suceeded by statement");
				}

				stmts.args.push( this.stmt1() );

				if (this.acceptRoamingToken("grammar", "}"))
					return stmts;

				if (!this.acceptRoamingToken("grammar", ",")) {
					if (!this.hasTokens())
						break;

					if (!this.isWhitespaced(this.readtoken))
						throw new SyntaxError("Statements must be separated by comma (,) or whitespace");

				}
			}
		}

		throw new SyntaxError("Right curly bracket (}) missing, to close switch block", token.trace);
	}

	function acceptIfElseIf(): Array<Instruction> {
		var args = [];
		while (true) {
			if (this.acceptRoamingToken("keyword", "elseif")) {
				args.push(
					this.instruction(this.getTokenTrace(), Instr.If, [this.acceptCondition(), this.acceptBlock("elseif condition"), null, false])
				);
			} else if(this.acceptRoamingToken("keyword", "else")) {
				args.push(
					this.instruction(this.getTokenTrace(), Instr.If, [null, this.acceptBlock("else"), null, true])
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

		return this.instruction( this.getTokenTrace(), Instr.Root, [] );
	}

	function acceptCaseBlock() {
		if (this.hasTokens()) {
			var stmts = this.instruction(this.getTokenTrace(), Instr.Root, []);

			if (this.hasTokens()) {
				while (true) {
					if (this.acceptRoamingToken("keyword", "case") || this.acceptRoamingToken("keyword", "default") || this.acceptRoamingToken("grammar", "}")) {
						this.trackBack();
						return stmts;
					} else if (this.acceptRoamingToken("grammar", ",")) {
						throw new SyntaxError("Statement separator (,) must not appear multiple times");
					} else if (this.acceptRoamingToken("grammar", "}")) {
						throw new SyntaxError("Statement separator (,) must be succeeded by statement");
					}

					stmts.args.push(this.stmt1());

					if (!this.acceptRoamingToken("grammar", ",")) {
						if (!this.hasTokens()) break;

						if (!this.isWhitespaced(this.readtoken))
							throw new SyntaxError("Statements must be separated by comma (,) or whitespace");
					}
				}
				// Don't know if this should happen either.
				return stmts;
			} else {
				throw new ParseError("Dunno if this should happen or not.");
			}
		} else {
			throw new SyntaxError("Case block is missing after case declaration.");
		}
	}

	function acceptSwitchBlock() {
		var cases: SwitchCases = [];
		var def = false;

		if ( this.hasTokens() && !this.acceptRoamingToken("grammar", ")") ) {
			if (!this.acceptRoamingToken("keyword", "case") && !this.acceptRoamingToken("keyword", "default"))
				throw new SyntaxError("Case Operator (case) expected in case block.", this.getTokenTrace());

			this.trackBack();

			while (true) {
				if (this.acceptRoamingToken("keyword", "case")) {
					var expr = this.expr1();

					if (!this.acceptRoamingToken("grammar", ","))
						throw new SyntaxError("Comma (,) expected after case condition");

					cases.push( { match: expr, block: this.acceptCaseBlock() } );
				} else if (this.acceptRoamingToken("keyword", "default")) {
					if (def)
						throw new UserError("Only one default case (default:) may exist.");

					if (!this.acceptRoamingToken("grammar", ","))
						throw new SyntaxError("Comma (,) expected after default case");
					def = true;
					cases.push( { match: null, block: this.acceptCaseBlock() } );
				} else {
					break;
				}
			}
		}

		if (!this.acceptRoamingToken("grammar", "}"))
			throw new SyntaxError("Right curly bracket (}) missing, to close statement block");

		return cases;
	}

	function acceptFunctionArgs(used_vars: StringMap<Bool>, args: FunctionParams) {
		if ( this.hasTokens() && !this.acceptRoamingToken("grammar", ")") ) {
			while (true) {
				if (this.acceptRoamingToken("grammar", ","))
					throw new SyntaxError("Argument separator (,) must not appear multiple times");

				if ( this.acceptRoamingToken("ident") || this.acceptRoamingToken("lower_ident") ) {
					this.acceptFunctionArg(used_vars, args);
				} else if ( this.acceptRoamingToken("grammar", "[") ) {
					this.acceptFunctionArgList(used_vars, args);
				}

				if ( this.acceptRoamingToken("grammar", ")") ) {
					break;
				} else if ( !this.acceptRoamingToken("grammar", ",") ) {
					this.nextToken();
					throw new SyntaxError("Right parenthesis ()) expected after function arguments");
				}
			}
		}
	}

	function acceptFunctionArg(used_vars: StringMap<Bool>, args: FunctionParams) {
		var type = "number";

		var name = this.getTokenRaw();
		if (name == null)
			throw new SyntaxError("Variable required");

		if (used_vars.exists(name))
			throw new UserError('Variable \'$name\' is already used as an argument,');

		if (this.acceptRoamingToken("grammar", ":")) {
			if (this.acceptRoamingType()) {
				type = this.getTokenRaw();
			} else {
				throw new SyntaxError("Type expected after colon (:)");
			}
		}

		if ( !wire_expression_types.exists(type)  )
			throw new TypeError('Type $type does not exist.');

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
						throw new SyntaxError("Variable required");

					if ( used_vars.exists(name) )
						throw new UserError('Variable \'$name\' is already used as an argument');

					used_vars.set(name, true);
					vars.push(name);
				} else if ( this.acceptRoamingToken("grammar", "]") ) {
					break;
				} else { // if !self:HasTokens() then
					this.nextToken();
					throw new SyntaxError("Right square bracket (]) expected at end of argument list");
				}
			}

			if (vars.length == 0) {
				this.trackBack();
				this.trackBack();
				throw new SyntaxError("Variables expected in variable list");
			}

			var type = "number";

			if ( this.acceptRoamingToken("grammar", ":") ) {
				if ( this.acceptRoamingType() ) {
					type = this.getTokenRaw();
				} else {
					throw new TypeError("Type expected after colon (:)");
				}
			}

			for (v in vars) {
				args.push( {name: v, type: type} );
			}
		} else {
			throw new SyntaxError("Variable expected after left square bracket ([) in argument list");
		}
	}

	function stmt1() {
		if (this.acceptRoamingToken("keyword", "if")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, Instr.If, [this.acceptCondition(), this.acceptBlock("if condition"), this.acceptIfElseIf(), false] );
		}
		return this.stmt2();
	}

	function stmt2() {
		if (this.acceptRoamingToken("keyword", "while")) {
			var trace = this.getTokenTrace();
			this.depth++;
			var whl = this.instruction( trace, Instr.While, [this.acceptCondition(), this.acceptBlock("while condition"), false] );
			this.depth--;
			return whl;
		}

		return this.stmt3();
	}

	function stmt3() {
		if (this.acceptRoamingToken("keyword", "for")) {
			var trace = this.getTokenTrace();
			this.depth++;

			if (!this.acceptRoamingToken("grammar", "("))
				throw new SyntaxError("Left parenthesis (() must appear before condition");

			if (!this.acceptRoamingToken("ident"))
				throw new SyntaxError("Variable expected for the numeric index");

			var v = this.getTokenRaw();

			if (!this.acceptRoamingToken("operator", "="))
				throw new SyntaxError("Assignment operator (=) expected to preceed variable");

			var estart = this.expr1();

			if (!this.acceptRoamingToken("grammar", ","))
				throw new SyntaxError("Comma (,) expected after start value");

			var estop = this.expr1();

			var estep: Option<Instruction> = None;
			if (this.acceptRoamingToken("grammar", ","))
				estep = Some(this.expr1());

			if (!this.acceptRoamingToken("grammar", ")"))
				throw new SyntaxError("Right parenthesis ()) missing, to close condition");

			// Wrap estep in a nullable type
			final estep_wrap = Maybe( Optional.Instruction(estep) );

			var sfor = this.instruction( trace, Instr.For, [v, estart, estop, estep_wrap, this.acceptBlock("for statement")] );

			this.depth--;
			return sfor;
		}

		return this.stmt4();
	}

	function stmt4() {
		if (this.acceptRoamingToken("keyword", "foreach")) {
			var trace = this.getTokenTrace();
			this.depth++;

			if (!this.acceptRoamingToken("grammar", "("))
				throw new SyntaxError("Left parenthesis missing (() after foreach statement");

			if (!this.acceptRoamingToken("ident"))
				throw new SyntaxError("Variable expected to hold the key");

			var keyvar = this.getTokenRaw();

			var keytype = "number"; // By default foreach(K, V) will have K as a number (for arrays)

			if (this.acceptRoamingToken("grammar", ":")) {
				final typ = this.assertRoamingType();

				keytype = typ.id;
			}

			if (!this.acceptRoamingToken("grammar", ","))
				throw new SyntaxError("Comma (,) expected after key variable");

			if (!this.acceptRoamingToken("ident"))
				throw new SyntaxError("Variable expected to hold the value");

			var valvar = this.getTokenRaw();

			if (!this.acceptRoamingToken("grammar", ":"))
				throw new SyntaxError("Colon (:) expected to separate type from variable");

			if (!this.acceptRoamingType())
				throw new SyntaxError("Type expected after colon");

			var valtype = this.getTokenRaw();

			var typ = wire_expression_types.get(valtype);
			if (typ == null)
				throw new TypeError('Unknown type: $valtype');

			valtype = typ.id;

			if (!this.acceptRoamingToken("operator", "="))
				throw new SyntaxError("Equals sign (=) expected after value type to specify table");

			var tableexpr = this.expr1();

			if (!this.acceptRoamingToken("grammar", ")"))
				throw new SyntaxError("Missing right parenthesis after foreach statement");

			var sfea = this.instruction(trace, Instr.Foreach, [keyvar, keytype, valvar, valtype, tableexpr, this.acceptBlock("foreach statement")] );
			this.depth--;
			return sfea;
		}

		return this.stmt5();
	}

	function stmt5() {
		if (this.acceptRoamingToken("keyword", "break")) {
			if (this.depth > 0) {
				var trace = this.getTokenTrace();
				return this.instruction(trace, Instr.Break, []);
			} else {
				throw new UserError("Break may not exist outside of a loop");
			}
		} else if (this.acceptRoamingToken("keyword", "continue")) {
			if (this.depth > 0) {
				var trace = this.getTokenTrace();
				return this.instruction(trace, Instr.Continue, []);
			} else {
				throw new UserError("Continue may not exist outside of a loop");
			}
		}

		return this.stmt6();
	}

	function stmt6() {
		if (this.acceptRoamingToken("ident")) {
			var trace = this.getTokenTrace();
			var v = this.getTokenRaw();

			if (this.acceptTailingToken("operator", "++")) {
				return this.instruction( trace, Instr.Increment, [v] );
			} else if (this.acceptRoamingToken("operator", "++")) {
				throw new SyntaxError("Increment operator (++) must not be preceded by whitespace");
			}

			if (this.acceptTailingToken("operator", "--")) {
				return this.instruction( trace, Instr.Decrement, [v] );
			} else if (this.acceptRoamingToken("operator", "--")) {
				throw new SyntaxError("Decrement operator (--) must not be preceded by whitespace");
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
				return this.instruction( trace, Instr.Assign, [ v, this.instruction(trace, Instr.Add, [this.instruction(trace, Instr.Var, [v]), this.expr1()]) ] );
			} else if (this.acceptRoamingToken("operator", "-=")) {
				return this.instruction( trace, Instr.Assign, [ v, this.instruction(trace, Instr.Sub, [this.instruction(trace, Instr.Var, [v]), this.expr1()]) ] );
			} else if (this.acceptRoamingToken("operator", "*=")) {
				return this.instruction( trace, Instr.Assign, [ v, this.instruction(trace, Instr.Mul, [this.instruction(trace, Instr.Var, [v]), this.expr1()]) ] );
			} else if (this.acceptRoamingToken("operator", "/=")) {
				return this.instruction( trace, Instr.Assign, [ v, this.instruction(trace, Instr.Div, [this.instruction(trace, Instr.Var, [v]), this.expr1()]) ] );
			}

			this.trackBack();
		}

		return this.stmt8();
	}

	function stmt8(parentLocalized: Bool = false): Instruction {
		var localized = false;
		if (this.acceptRoamingToken("keyword", "local")) {
			if (parentLocalized)
				throw new UserError("Assignment can't contain roaming local operator");

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
						throw new UserError("Invalid operator (local).");

					var total = indexs.length;
					var inst = this.instruction( trace, Instr.Var, [v] );

					for (i => idx in indexs) {
						idx = idx.sure();
						var key = idx.key;
						var type = idx.type;
						var trace = idx.trace;

						// Pls..
						final type_wrap = Maybe( Optional.String(type) );
						if (i == total-1) {
							inst = this.instruction( trace, Instr.IndexSet, [inst, key, this.stmt8(false), type_wrap] );
						} else {
							inst = this.instruction( trace, Instr.IndexGet, [inst, key, type_wrap] );
						}
					} // Example Result: set( get( get(Var,1,table) ,1,table) ,3,"hello",string)
					return inst;
				}

			} else if (this.acceptRoamingToken("operator", "=")) {
				if (localized || parentLocalized) {
					return this.instruction( trace, Instr.LAssign, [v, this.stmt8(true)] );
				} else {
					return this.instruction( trace, Instr.Assign, [v, this.stmt8(false)] );
				}
			} else if (localized) {
				throw new UserError("Invalid operator (local) must be used for variable declaration.");
			}

			this.index = tbpos - 2;
			this.nextToken();
		} else if (localized) {
			throw new UserError("Invalid operator (local) must be used for variable declaration.");
		}

		return stmt9();
	}

	function stmt9() {
		if (this.acceptRoamingToken("keyword", "switch")) {
			var trace = this.getTokenTrace();

			if (!this.acceptRoamingToken("grammar", "("))
				throw new SyntaxError("Left parenthesis (() expected before switch condition");

			var expr = this.expr1();

			if (!this.acceptRoamingToken("grammar", ")"))
				throw new SyntaxError("Right parenthesis ()) expected after switch condition");

			if (!this.acceptRoamingToken("grammar", "{"))
				throw new SyntaxError("Left curly bracket ({) expected after switch condition");

			this.depth++;
			var cases = this.acceptSwitchBlock();
			this.depth--;

			return this.instruction(trace, Instr.Switch, [expr, cases]);
		}

		return stmt10();
	}

	function stmt10() {
		if (this.acceptRoamingToken("keyword", "function")) {
			var trace = this.getTokenTrace();

			var name: Null<String> = null;
			var ret: String = "void";
			var type: Null<String> = null; // Metatype <entity>:fnCall()

			var name_token: Null<Token> = null;
			var return_token: Null<Token> = null;
			var type_token: Null<Token> = null;

			var args: FunctionParams = [];
			var used_vars: StringMap<Bool> = new StringMap();

			// Errors are handled after line 49, both 'fun' and 'var' tokens are used for accurate error reports.
			if ( this.acceptRoamingToken("lower_ident") ) {
				name = this.getTokenRaw();
				name_token = this.getToken(); // Copy the current token for error logging

				// Check if previous token was the type rather than the function name
				if ( this.acceptRoamingToken("lower_ident") ) {
					ret = name;
					return_token = name_token;

					name = this.getTokenRaw();
					name_token = this.getToken();
				}

				// Check if the token before was the metatype
				if (this.acceptRoamingToken("grammar", ":")) {
					if (this.acceptRoamingToken("lower_ident")) {
						type = name;
						type_token = name_token;

						name = this.getTokenRaw();
						name_token = this.getToken();
					} else {
						throw new SyntaxError("Function name must appear after colon (:)");
					}
				}
			}

			if (ret != "void") {
				// We already made sure the return type is lowercase by accepting ``lower_ident``
				if (!return_token.sure().properties.exists("type"))
					throw new TypeError('Invalid return type [${ ret }]');

				ret = ret.toUpperCase();
			}

			if (type != null && type_token != null) {
				if (type != type.toLowerCase())
					throw new SyntaxError("Function object must be full lowercase", type_token.trace);
				if (type == "void")
					throw new UserError("Void cannot be used as function object type", type_token.trace);

				type = type.toUpperCase();

				// TODO: Check if ``type`` is a valid type.

				used_vars.set("This", true);
				args[0] = { name: "This", type: type.sure() };
			}

			if (name == null)
				throw new SyntaxError("Function name must follow function declaration");

			var first_char = name.charAt(0);
			if (first_char != first_char.toLowerCase())
				throw new SyntaxError("Function name must start with a lower case letter", name_token.sure().trace);

			if ( !this.acceptRoamingToken("grammar", "(") )
				throw new SyntaxError("Left parenthesis (() must appear after function name");

			this.acceptFunctionArgs(used_vars, args);

			var sig = name + "(";
			for (i in 1...args.length) {
				var arg = args[i];
				sig += wire_expression_types.get(arg.type).sure().id;
				if (i == 1 && arg.name == "This" && type != '') {
					sig += ":";
				}
			}
			sig += ")";

			// TODO: Make sure you can't overwrite existing functions with the signature.


			final type_wrap = Maybe( Optional.String(type) );
			return this.instruction( trace, Instr.Function, [name, ret, type_wrap, sig, args, this.acceptBlock("function declaration")] );
		} else if ( this.acceptRoamingToken("keyword", "return") ) {
			var trace = this.getTokenTrace();

			if ( this.acceptRoamingType("void") || (this.readtoken != null && this.readtoken.raw == "}" /* check if readtoken is rcb */ ) )
				return this.instruction( trace, Instr.Return, [] );

			return this.instruction( trace, Instr.Return, [this.expr1()] );
		} else if ( this.acceptRoamingType("void") ) {
			throw new SyntaxError("Void may only exist after return");
		}

		return stmt11();
	}

	// do {} while(1)
	function stmt11() {
		if (this.acceptRoamingToken("keyword", "do")) {
			var trace = this.getTokenTrace();

			this.depth++;
			var block = this.acceptBlock("do keyword");

			if ( !this.acceptRoamingToken("keyword", "while") )
				throw new SyntaxError("while expected after do block");

			var condition = this.acceptCondition();

			final instr = this.instruction( trace, Instr.While, [condition, block, true] );
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
	function stmt12() {
		if (this.acceptRoamingToken("keyword", "try")) {
			var trace = this.getTokenTrace();
			var stmt = this.acceptBlock("try block");

			if (!this.acceptRoamingToken("keyword", "catch"))
				throw new SyntaxError("Try block must be followed by catch statement");

			if (!this.acceptRoamingToken("grammar", "("))
				throw new SyntaxError("Left parenthesis (() expected after catch keyword");

			if (!this.acceptRoamingToken("ident"))
				throw new SyntaxError("Variable expected after left parenthesis (() in catch statement");

			var var_name = this.getTokenRaw();

			if (!this.acceptRoamingToken("grammar", ")"))
				throw new SyntaxError("Right parenthesis ()) missing, to close catch statement");

			return this.instruction(trace, Instr.Try, [stmt, var_name, this.acceptBlock("catch block")] );
		}
		return expr1();
	}

	function expr1(): Instruction {
		this.exprtoken = this.getToken();

		if (this.acceptRoamingToken("ident")) {
			if (this.acceptRoamingToken("operator", "="))
				throw new SyntaxError("Assignment operator (=) must not be part of equation");

			if (this.acceptRoamingToken("operator", "+=")) {
				throw new SyntaxError("Additive assignment operator (+=) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "-=")) {
				throw new SyntaxError("Subtractive assignment operator (-=) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "*=")) {
				throw new SyntaxError("Multiplicative assignment operator (*=) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "/=")) {
				throw new SyntaxError("Divisive assignment operator (/=) must not be part of equation");
			}

			this.trackBack();
		}

		return this.expr2();
	}

	function expr2() {
		var expr = this.expr3();

		if (this.acceptRoamingToken("operator", "?")) {
			var trace = this.getTokenTrace();
			var exprtrue = this.expr1();

			if (!this.acceptRoamingToken("grammar", ":"))
				throw new SyntaxError( "Conditional operator (:) must appear after expression to complete conditional" );

			return this.instruction( trace, Instr.Ternary, [expr, exprtrue, this.expr1()] );
		}

		if (this.acceptRoamingToken("grammar", "?:")) {
			var trace = this.getTokenTrace();

			return this.instruction( trace, Instr.TernaryDefault, [expr, this.expr1()] );
		}

		return expr;
	}

	// Yes, || and && are swapped. They should be logical ops but they are binary ops.
	// We're trying to keep parity with E2, so this will be kept.
	function expr3() return this.recurseLeftOp(this.expr4, ["||"], [Instr.Bor]); // bitwise or
	function expr4() return this.recurseLeftOp(this.expr5, ["&&"], [Instr.BAnd]); // bitwise and
	function expr5() return this.recurseLeftOp(this.expr6, ["|"], [Instr.Or]); // logical or
	function expr6() return this.recurseLeftOp(this.expr7, ["&"], [Instr.And]); // logical and
	function expr7() return this.recurseLeftOp(this.expr8, ["^^"], [Instr.BXor]); // binary xor
	function expr8() return this.recurseLeftOp(this.expr9, ["==", "!="], [Instr.Equal, Instr.NotEqual]);
	function expr9() return this.recurseLeftOp(this.expr10, [">", "<", ">=", "<="], [Instr.GreaterThan, Instr.LessThan, Instr.GreaterThanEq, Instr.LessThanEq]);
	function expr10() return this.recurseLeftOp(this.expr11, [">>", "<<"], [Instr.BShl, Instr.BShr]);
	function expr11() return this.recurseLeftOp(this.expr12, ["+", "-"], [Instr.Add, Instr.Sub]);
	function expr12() return this.recurseLeftOp(this.expr13, ["*", "/", "%"], [Instr.Mul, Instr.Div, Instr.Mod]);
	function expr13() return this.recurseLeftOp(this.expr14, ["^"], [Instr.Exp]); // exponent

	function expr14() {
		if (this.acceptLeadingToken("operator", "+")) {
			return this.expr15();
		} else if (this.acceptRoamingToken("operator", "+")) {
			throw new SyntaxError("Identity operator (+) must not be succeeded by whitespace");
		}

		if (this.acceptLeadingToken("operator", "-")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, Instr.Negative, [this.expr15()] );
		} else if (this.acceptRoamingToken("operator", "-")) {
			throw new SyntaxError("Negation operator (-) must not be succeeded by whitespace");
		}

		if (this.acceptLeadingToken("operator", "!")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, Instr.Not, [this.expr14()] );
		} else if (this.acceptRoamingToken("operator", "!")) {
			throw new SyntaxError("Logical not operator (!) must not be succeeded by whitespace");
		}

		return this.expr15();
	}

	function expr15() {
		var expr = this.expr16();

		while (true) {
			if (this.acceptTailingToken("grammar", ":")) {
				if (!this.acceptTailingToken("lower_ident")) {
					if (this.acceptRoamingToken("lower_ident")) {
						throw new SyntaxError("Method operator (:) must not be preceded by whitespace");
					} else {
						throw new SyntaxError("Method operator (:) must be followed by method name");
					}
				}

				var trace = this.getTokenTrace();
				var fun = this.getTokenRaw();

				if (!this.acceptTailingToken("grammar", "(")) {
					if (this.acceptRoamingToken("grammar", "(")) {
						throw new SyntaxError("Left parenthesis (() must not be preceded by whitespace");
					} else {
						throw new SyntaxError("Left parenthesis (() must appear after method name");
					}
				}

				final token = this.getToken();

				if (this.acceptRoamingToken("grammar", ")")) {
					expr = this.instruction( trace, Instr.Methodcall, [fun, expr] );
				} else {
					var exprs: Array<Instruction> = [this.expr1()];

					while (this.acceptRoamingToken("grammar", ",")) {
						exprs.push( this.expr1() );
					}

					if (!this.acceptRoamingToken("grammar", ")"))
						throw new SyntaxError("Right parenthesis ()) missing, to close method argument list", token.trace);

					expr = this.instruction( trace, Instr.Methodcall, [fun, expr, exprs] );
				}
			} else if (this.acceptTailingToken("grammar", "[")) {
				var trace = this.getTokenTrace();

				if (this.acceptRoamingToken("grammar", "]"))
					throw new SyntaxError("Indexing operator ([]) requires an index [X]");

				var aexpr = this.expr1();
				if (this.acceptRoamingToken("grammar", ",")) {
					final typ = this.assertRoamingType();

					if (!this.acceptRoamingToken("grammar", "]"))
						throw new SyntaxError("Right square bracket (]) missing, to close indexing operator [X,t]");

					expr = this.instruction( trace, Instr.IndexGet, [expr, aexpr, typ.id] );
				} else if (this.acceptRoamingToken("grammar", "]")) {
					expr = this.instruction( trace, Instr.IndexGet, [expr, aexpr] );
				} else {
					throw new SyntaxError("Indexing operator ([]) needs to be closed with comma (,) or right square bracket (])");
				}
			} else if (this.acceptRoamingToken("grammar", "[") && this.isWhitespaced(this.token)) {
				throw new SyntaxError("Indexing operator ([]) must not be preceded by whitespace");
			} else if (this.acceptTailingToken("grammar", "(")) {
				var trace = this.getTokenTrace();

				final token = this.getToken();
				var exprs: Array<Instruction> = [];

				if (this.acceptRoamingToken("grammar", ")")) {
					exprs = [];
				} else {
					exprs = [ this.expr1() ];

					while (this.acceptRoamingToken("grammar", ",")) {
						exprs.push( this.expr1() );
					}

					if (!this.acceptRoamingToken("grammar", ")"))
						throw new SyntaxError("Right parenthesis ()) missing, to close function argument list", token.trace);
				}

				if (this.acceptRoamingToken("grammar", "[")) {
					final stype = this.assertRoamingType(null, 'Return type operator ([]) does not support the type [<T>]');

					if (!this.acceptRoamingToken("grammar", "]"))
						throw new SyntaxError("Right square bracket (]) missing, to close return type operator");

					expr = this.instruction( trace, Instr.Stringcall, [expr, exprs, stype.id] );
				} else {
					expr = this.instruction( trace, Instr.Stringcall, [expr, exprs, null] );
				}
			} else {
				break;
			}
		}

		return expr;
	}

	function expr16() {
		if (this.acceptRoamingToken("grammar", "(")) {
			final trace = this.getTokenTrace();
			final token = this.getToken();
			final expr = this.expr1();

			if (!this.acceptRoamingToken("grammar", ")"))
				throw new SyntaxError("Right parenthesis ()) missing, to close grouped equation", token.trace);

			return this.instruction( trace, Instr.GroupedEquation, [expr] );
		}

		if (this.acceptRoamingToken("lower_ident")) {
			final trace = this.getTokenTrace();
			final fun = this.getTokenRaw();

			if (!this.acceptTailingToken("grammar", "(")) {
				if (this.acceptRoamingToken("grammar", "(")) {
					throw new SyntaxError("Left parenthesis (() must not be preceded by whitespace");
				} else {
					throw new SyntaxError("Left parenthesis (() must appear after function name, variables must start with uppercase letter,");
				}
			}

			final token = this.getToken();

			if (this.acceptRoamingToken("grammar", ")")) {
				return this.instruction(trace, Instr.Call, [fun, []]);
			} else {
				final kv_exprs: Map<Instruction, Instruction> = new Map();
				var i_exprs: Array<Instruction> = [];

				// TODO: Make this work for all functions.
				// So you can declare a kvtable / itable function and use them as params.
				// table( "yes" = "no", 5 = 2 )
				if (fun == "table" || fun == "array") {
					var kvtable = false;
					final key = this.expr1();

					if (this.acceptRoamingToken("operator", "=")) {
						if (this.acceptRoamingToken("grammar", ")"))
							throw new SyntaxError("Expression expected, got right paranthesis ())");

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
									throw new SyntaxError("Expression expected, got right paranthesis ())");

								kv_exprs[key] = this.expr1();
							} else {
								throw new SyntaxError("Assignment operator (=) missing, to complete expression", token.trace);
							}
						}

						if (!this.acceptRoamingToken("grammar", ")"))
							throw new SyntaxError("Right parenthesis ()) missing, to close function argument list");

						if (fun == "table") {
							return this.instruction( trace, Instr.KVTable, [kv_exprs, i_exprs] );
						} else {
							return this.instruction( trace, Instr.KVArray, [kv_exprs, i_exprs] );
						}
					}
				} else {
					i_exprs = [this.expr1()];
				}

				while (this.acceptRoamingToken("grammar", ","))
					i_exprs.push( this.expr1() );

				if (!this.acceptRoamingToken("grammar", ")"))
					throw new SyntaxError("Right parenthesis ()) missing, to close function argument list", token.trace);

				return this.instruction( trace, Instr.Call, [fun, kv_exprs, i_exprs] );
			}
		}

		return this.expr17();
	}

	function expr17() {
		if (this.acceptRoamingToken("number")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, Instr.Literal, [this.getToken().literal] );
		}

		if (this.acceptRoamingToken("string")) {
			var trace = this.getTokenTrace();
			return this.instruction( trace, Instr.Literal, [this.getToken().literal] );
		}

		if (this.acceptRoamingToken("operator", "~")) {
			var trace = this.getTokenTrace();

			if (!this.acceptTailingToken("ident")) {
				if (this.acceptRoamingToken("ident")) {
					throw new SyntaxError("Triggered operator (~) must not be succeeded by whitespace");
				} else {
					throw new SyntaxError("Triggered operator (~) must be preceded by variable");
				}
			}

			var varname = this.getTokenRaw();
			return this.instruction( trace, Instr.Triggered, [varname] );
		}

		if (this.acceptRoamingToken("operator", "$")) {
			var trace = this.getTokenTrace();

			if (!this.acceptTailingToken("ident")) {
				if (this.acceptRoamingToken("ident")) {
					throw new SyntaxError("Delta operator ($) must not be succeeded by whitespace");
				} else {
					throw new SyntaxError("Delta operator ($) must be preceded by variable");
				}
			}

			var varname = this.getTokenRaw();
			return this.instruction( trace, Instr.Delta, [varname] );
		}

		if (this.acceptRoamingToken("operator", "->")) {
			var trace = this.getTokenTrace();

			if (!this.acceptTailingToken("ident")) {
				if (this.acceptRoamingToken("ident")) {
					throw new SyntaxError("Connected operator (->) must not be succeeded by whitespace");
				} else {
					throw new SyntaxError("Connected operator (->) must be preceded by variable");
				}
			}

			var varname = this.getTokenRaw();
			return this.instruction( trace, Instr.Connected, [varname] );
		}

		return this.expr18();
	}

	function expr18() {
		if (this.acceptRoamingToken("ident")) {
			if (this.acceptTailingToken("operator", "++")) {
				throw new SyntaxError("Increment operator (++) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "++")) {
				throw new SyntaxError("Increment operator (++) must not be preceded by whitespace");
			}

			if (this.acceptTailingToken("operator", "--")) {
				throw new SyntaxError("Decrement operator (--) must not be part of equation");
			} else if (this.acceptRoamingToken("operator", "--")) {
				throw new SyntaxError("Decrement operator (--) must not be preceded by whitespace");
			}

			this.trackBack();
		}

		return this.expr19();
	}

	function expr19() {
		if (this.acceptRoamingToken("ident"))
			return this.instruction( this.getTokenTrace(), Instr.Var, [this.getTokenRaw()] );

		throw new SyntaxError( this.getExprError() );
	}

	@:nullSafety(Off)
	function getExprError(): String {
		if(!this.hasTokens())
			throw new SyntaxError("Further input required at } of code, incomplete expression", this.exprtoken.trace);

		if (this.acceptRoamingToken("operator", "+")) {
			throw new SyntaxError("Addition operator (+) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "-")) { // can't occur (unary minus)
			throw new SyntaxError("Subtraction operator (-) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "*")) {
			throw new SyntaxError("Multiplication operator (*) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "/")) {
			throw new SyntaxError("Division operator (/) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "%")) {
			throw new SyntaxError("Modulo operator (%) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "^")) {
			throw new SyntaxError("Exponentiation operator (^) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "=")) {
			throw new SyntaxError("Assignment operator (=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "+=")) {
			throw new SyntaxError("Additive assignment operator (+=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "-=")) {
			throw new SyntaxError("Subtractive assignment operator (-=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "*=")) {
			throw new SyntaxError("Multiplicative assignment operator (*=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "/=")) {
			throw new SyntaxError("Divisive assignment operator (/=) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "&")) {
			throw new SyntaxError("Logical and operator (&) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "|")) {
			throw new SyntaxError("Logical or operator (|) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "==")) {
			throw new SyntaxError("Equality operator (==) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "!=")) {
			throw new SyntaxError("Inequality operator (!=) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", ">=")) {
			throw new SyntaxError("Greater than or equal to operator (>=) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "<=")) {
			throw new SyntaxError("Less than or equal to operator (<=) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", ">")) {
			throw new SyntaxError("Greater than operator (>) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "<")) {
			throw new SyntaxError("Less than operator (<) must be preceded by equation or value");
		} else if (this.acceptRoamingToken("operator", "++")) {
			throw new SyntaxError("Increment operator (++) must be preceded by variable");
		} else if (this.acceptRoamingToken("operator", "--")) {
			throw new SyntaxError("Decrement operator (--) must be preceded by variable");
		} else if (this.acceptRoamingToken("grammar", ")")) {
			throw new SyntaxError("Right parenthesis ()) without matching left parenthesis");
		} else if (this.acceptRoamingToken("grammar", "(")) {
			throw new SyntaxError("Left curly bracket ({) must be part of an if/while/for-statement block");
		} else if (this.acceptRoamingToken("grammar", "{")) {
			throw new SyntaxError("Right curly bracket (}) without matching left curly bracket");
		} else if (this.acceptRoamingToken("grammar", "[")) {
			throw new SyntaxError("Left square bracket ([) must be preceded by variable");
		} else if (this.acceptRoamingToken("grammar", "]")) {
			throw new SyntaxError("Right square bracket (]) without matching left square bracket");
		} else if (this.acceptRoamingToken("grammar", ",")) {
			throw new SyntaxError("Comma (,) not expected here, missing an argument?");
		} else if (this.acceptRoamingToken("operator", ":")) {
			throw new SyntaxError("Method operator (:) must not be preceded by whitespace");
		} else if (this.acceptRoamingToken("keyword", "if")) {
			throw new SyntaxError("If keyword (if) must not appear inside an equation");
		} else if (this.acceptRoamingToken("keyword", "elseif")) {
			throw new SyntaxError("Else-if keyword (} else if) must be part of an if-statement");
		} else if (this.acceptRoamingToken("keyword", "else")) {
			throw new SyntaxError("Else keyword (else) must be part of an if-statement");
		} else {
			throw new SyntaxError('Unexpected token found (${ this.readtoken.id })');
		}
	}
}