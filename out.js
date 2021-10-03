(function ($global) { "use strict";
var $estr = function() { return js_Boot.__string_rec(this,''); },$hxEnums = $hxEnums || {},$_;
function $extend(from, fields) {
	var proto = Object.create(from);
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var EReg = function(r,opt) {
	this.r = new RegExp(r,opt.split("u").join(""));
};
EReg.__name__ = true;
EReg.prototype = {
	match: function(s) {
		if(this.r.global) {
			this.r.lastIndex = 0;
		}
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) {
			return this.r.m[n];
		} else {
			throw haxe_Exception.thrown("EReg::matched");
		}
	}
	,matchedPos: function() {
		if(this.r.m == null) {
			throw haxe_Exception.thrown("No string matched");
		}
		return { pos : this.r.m.index, len : this.r.m[0].length};
	}
	,matchSub: function(s,pos,len) {
		if(len == null) {
			len = -1;
		}
		if(this.r.global) {
			this.r.lastIndex = pos;
			this.r.m = this.r.exec(len < 0 ? s : HxOverrides.substr(s,0,pos + len));
			var b = this.r.m != null;
			if(b) {
				this.r.s = s;
			}
			return b;
		} else {
			var b = this.match(len < 0 ? HxOverrides.substr(s,pos,null) : HxOverrides.substr(s,pos,len));
			if(b) {
				this.r.s = s;
				this.r.m.index += pos;
			}
			return b;
		}
	}
	,map: function(s,f) {
		var offset = 0;
		var buf_b = "";
		while(true) {
			if(offset >= s.length) {
				break;
			} else if(!this.matchSub(s,offset)) {
				buf_b += Std.string(HxOverrides.substr(s,offset,null));
				break;
			}
			var p = this.matchedPos();
			buf_b += Std.string(HxOverrides.substr(s,offset,p.pos - offset));
			buf_b += Std.string(f(this));
			if(p.len == 0) {
				buf_b += Std.string(HxOverrides.substr(s,p.pos,1));
				offset = p.pos + 1;
			} else {
				offset = p.pos + p.len;
			}
			if(!this.r.global) {
				break;
			}
		}
		if(!this.r.global && offset > 0 && offset < s.length) {
			buf_b += Std.string(HxOverrides.substr(s,offset,null));
		}
		return buf_b;
	}
};
var HxOverrides = function() { };
HxOverrides.__name__ = true;
HxOverrides.substr = function(s,pos,len) {
	if(len == null) {
		len = s.length;
	} else if(len < 0) {
		if(pos == 0) {
			len = s.length + len;
		} else {
			return "";
		}
	}
	return s.substr(pos,len);
};
HxOverrides.now = function() {
	return Date.now();
};
function Main_main() {
	var preprocessor = new base_Preprocessor();
	var code = preprocessor.process(Main_CODE);
	var tokenizer = new base_Tokenizer();
	var tokens = tokenizer.process(code);
	var parser = new base_Parser();
	var ast = parser.process(tokens);
	var out = base_transpiler_Lua_callInstruction(ast.id,[ast.args]);
	var lua_code = out;
	console.log("src/Main.hx:26:","Finished transpiling!");
}
Math.__name__ = true;
var Reflect = function() { };
Reflect.__name__ = true;
Reflect.field = function(o,field) {
	try {
		return o[field];
	} catch( _g ) {
		return null;
	}
};
var Std = function() { };
Std.__name__ = true;
Std.string = function(s) {
	return js_Boot.__string_rec(s,"");
};
var StringTools = function() { };
StringTools.__name__ = true;
StringTools.replace = function(s,sub,by) {
	return s.split(sub).join(by);
};
var base_Parser = function() {
	this.depth = 0;
	this.tokens = [];
	this.index = 0;
	this.count = 0;
	this.token = null;
	this.readtoken = null;
	this.exprtoken = null;
};
base_Parser.__name__ = true;
base_Parser.prototype = {
	error: function(msg,tok) {
		if(tok != null) {
			throw new lib_ParseError("" + msg + " at line " + this.token.line + ", char " + this.token.char);
		}
		throw new lib_ParseError("" + msg + " at line " + this.token.line + ", char " + this.token.char);
	}
	,process: function(tokens) {
		this.tokens = tokens;
		this.index = 0;
		this.count = tokens.length;
		this.nextToken();
		return this.root();
	}
	,getLiteralString: function() {
		var _g = this.token.literal;
		switch(_g._hx_index) {
		case 0:
			throw haxe_Exception.thrown("Tried to get a string from a void!");
		case 1:
			var _n = _g.val;
			throw haxe_Exception.thrown("Tried to get a string from a number literal!");
		case 2:
			var str = _g.val;
			return str;
		}
	}
	,getTokenTrace: function() {
		if(this.token == null) {
			return { line : 1, char : 0};
		}
		return { line : this.token.line, char : this.token.char};
	}
	,instruction: function(tr,id,args) {
		return { trace : tr, id : id, args : args};
	}
	,hasTokens: function() {
		return this.readtoken != null;
	}
	,nextToken: function() {
		if(this.index <= this.count) {
			this.token = this.index > 0 ? this.readtoken : new base_Token(0,0,"","",0,base_TokenType.Invalid);
			this.readtoken = this.tokens[this.index++];
		} else {
			this.readtoken = null;
		}
	}
	,trackBack: function() {
		this.index -= 2;
		this.nextToken();
	}
	,acceptRoamingToken: function(id,raw) {
		var token = this.readtoken;
		if(token == null || token.id != id) {
			return false;
		}
		if(raw != null && token.raw != raw) {
			return false;
		}
		this.nextToken();
		return true;
	}
	,acceptRoamingType: function(ty) {
		var token = this.readtoken;
		if(token == null || token.id != "lower_ident") {
			return false;
		}
		if(!token.properties.h["type"]) {
			return false;
		}
		if(ty != null && token.raw != ty) {
			return false;
		}
		this.nextToken();
		return true;
	}
	,assertRoamingType: function(ty) {
		var token = this.readtoken;
		if(token == null || token.id != "lower_ident") {
			this.error("Expected a lowercase type");
		}
		if(!token.properties.h["type"]) {
			this.error("Not an existing type! Got [" + token.raw + "]");
		}
		var typ = lib_Std_types.h[token.raw];
		if(typ == null) {
			this.error("Type didn't exist?");
		}
		this.nextToken();
		return typ;
	}
	,acceptTailingToken: function(id,raw) {
		var tok = this.readtoken;
		if(tok == null || tok.whitespaced) {
			return false;
		}
		return this.acceptRoamingToken(id,raw);
	}
	,acceptLeadingToken: function(id,raw) {
		var tok = this.tokens[this.index + 1];
		if(tok == null || tok.whitespaced) {
			return false;
		}
		return this.acceptRoamingToken(id,raw);
	}
	,recurseLeftOp: function(func,ops,op_ids) {
		var expr = func();
		var hit = true;
		while(hit) {
			hit = false;
			var _g_current = 0;
			var _g_array = ops;
			while(_g_current < _g_array.length) {
				var _g1_value = _g_array[_g_current];
				var _g1_key = _g_current++;
				var ind = _g1_key;
				var op_raw = _g1_value;
				if(this.acceptRoamingToken("operator",op_raw)) {
					hit = true;
					expr = this.instruction(this.getTokenTrace(),op_ids[ind],[expr,func()]);
					break;
				}
			}
		}
		return expr;
	}
	,root: function() {
		this.depth = 0;
		return this.stmts();
	}
	,stmts: function() {
		var trace = this.getTokenTrace();
		var stmts = this.instruction(trace,lib_Instr.Root,[]);
		if(!this.hasTokens()) {
			return stmts;
		}
		while(true) {
			if(this.acceptRoamingToken("grammar",",")) {
				this.error("Statement separator (,) must not appear multiple times");
			}
			stmts.args.push(this.stmt1());
			if(!this.hasTokens()) {
				break;
			}
			if(!this.acceptRoamingToken("grammar",",") && !this.readtoken.whitespaced) {
				this.error("Statements must be separated by comma (,) or whitespace");
			}
		}
		return stmts;
	}
	,acceptCondition: function() {
		if(!this.acceptRoamingToken("grammar","(")) {
			this.error("Left parenthesis (() expected before condition");
		}
		var expr = this.expr1();
		if(!this.acceptRoamingToken("grammar",")")) {
			this.error("Right parenthesis ()) missing, to close condition");
		}
		return expr;
	}
	,acceptIndex: function() {
		if(this.acceptTailingToken("grammar","[")) {
			var trace = this.getTokenTrace();
			var exp = this.expr1();
			if(this.acceptRoamingToken("grammar",",")) {
				var tp = this.assertRoamingType();
				var typename = this.token.raw;
				if(!this.acceptRoamingToken("grammar","]")) {
					this.error("Right square bracket (]) missing, to close indexing operator [X,t]");
				}
				var out = [{ key : exp, type : tp.id, trace : trace}];
				var ind = this.acceptIndex();
				if(ind != null) {
					out = out.concat(ind);
				}
				return out;
			} else if(this.acceptTailingToken("grammar","]")) {
				return [{ key : exp, type : null, trace : trace},null];
			} else {
				this.error("Indexing operator ([]) must not be preceded by whitespace");
			}
		}
		return null;
	}
	,acceptBlock: function(block_name) {
		if(block_name == null) {
			block_name = "condition";
		}
		var trace = this.getTokenTrace();
		var stmts = this.instruction(trace,lib_Instr.Root,[]);
		if(!this.acceptRoamingToken("grammar","{")) {
			this.error("Left curly bracket ({) expected after " + block_name);
		}
		var token = this.token;
		if(this.acceptRoamingToken("grammar","}")) {
			return stmts;
		}
		if(this.hasTokens()) {
			while(true) {
				if(this.acceptRoamingToken("grammar",",")) {
					this.error("Statement separator (,) must not appear multiple times");
				} else if(this.acceptRoamingToken("grammar","}")) {
					this.error("Statement separator (,) must be suceeded by statement");
				}
				stmts.args.push(this.stmt1());
				if(this.acceptRoamingToken("grammar","}")) {
					return stmts;
				}
				if(!this.acceptRoamingToken("grammar",",")) {
					if(!this.hasTokens()) {
						break;
					}
					if(!this.readtoken.whitespaced) {
						this.error("Statements must be separated by comma (,) or whitespace");
					}
				}
			}
		}
		this.error("Right curly bracket (}) missing, to close switch block",token);
		return null;
	}
	,acceptIfElseIf: function() {
		var args = [];
		while(true) if(this.acceptRoamingToken("keyword","elseif")) {
			args.push(this.instruction(this.getTokenTrace(),lib_Instr.If,[this.acceptCondition(),this.acceptBlock("elseif condition"),null,false]));
		} else if(this.acceptRoamingToken("keyword","else")) {
			args.push(this.instruction(this.getTokenTrace(),lib_Instr.If,[null,this.acceptBlock("else"),null,true]));
			break;
		} else {
			break;
		}
		return args;
	}
	,acceptCaseBlock: function() {
		if(this.hasTokens()) {
			var stmts = this.instruction(this.getTokenTrace(),lib_Instr.Root,[]);
			if(this.hasTokens()) {
				while(true) {
					if(this.acceptRoamingToken("keyword","case") || this.acceptRoamingToken("keyword","default") || this.acceptRoamingToken("grammar","}")) {
						this.trackBack();
						return stmts;
					} else if(this.acceptRoamingToken("grammar",",")) {
						this.error("Statement separator (,) must not appear multiple times");
					} else if(this.acceptRoamingToken("grammar","}")) {
						this.error("Statement separator (,) must be suceeded by statement");
					}
					stmts.args.push(this.stmt1());
					if(!this.acceptRoamingToken("grammar",",")) {
						if(!this.hasTokens()) {
							break;
						}
						if(!this.readtoken.whitespaced) {
							this.error("Statements must be separated by comma (,) or whitespace");
						}
					}
				}
			}
		} else {
			this.error("Case block is missing after case declaration.");
		}
		return null;
	}
	,acceptSwitchBlock: function() {
		var cases = [];
		var def = false;
		if(this.hasTokens() && !this.acceptRoamingToken("grammar",")")) {
			if(!this.acceptRoamingToken("keyword","case") && !this.acceptRoamingToken("keyword","default")) {
				this.error("Case Operator (case) expected in case block.",this.token);
			}
			this.trackBack();
			while(true) if(this.acceptRoamingToken("keyword","case")) {
				var expr = this.expr1();
				if(!this.acceptRoamingToken("grammar",",")) {
					this.error("Comma (,) expected after case condition");
				}
				cases.push({ match : expr, block : this.acceptCaseBlock()});
			} else if(this.acceptRoamingToken("keyword","default")) {
				if(def) {
					this.error("Only one default case (default:) may exist.");
				}
				if(!this.acceptRoamingToken("grammar",",")) {
					this.error("Comma (,) expected after default case");
				}
				def = true;
				cases.push({ match : null, block : this.acceptCaseBlock()});
			} else {
				break;
			}
		}
		if(!this.acceptRoamingToken("grammar","}")) {
			this.error("Right curly bracket (}) missing, to close statement block",this.token);
		}
		return cases;
	}
	,acceptFunctionArgs: function(used_vars,args) {
		if(this.hasTokens() && !this.acceptRoamingToken("grammar",")")) {
			while(true) {
				if(this.acceptRoamingToken("grammar",",")) {
					this.error("Argument separator (,) must not appear multiple times");
				}
				if(this.acceptRoamingToken("ident") || this.acceptRoamingToken("lower_ident")) {
					this.acceptFunctionArg(used_vars,args);
				} else if(this.acceptRoamingToken("grammar","[")) {
					this.acceptFunctionArgList(used_vars,args);
				}
				if(this.acceptRoamingToken("grammar",")")) {
					break;
				} else if(!this.acceptRoamingToken("grammar",",")) {
					this.nextToken();
					this.error("Right parenthesis ()) expected after function arguments");
				}
			}
		}
	}
	,acceptFunctionArg: function(used_vars,args) {
		var type = "number";
		var name = this.token.raw;
		if(name == null) {
			this.error("Variable required");
		}
		if(Object.prototype.hasOwnProperty.call(used_vars.h,name)) {
			this.error("Variable '" + name + "' is already used as an argument,");
		}
		if(this.acceptRoamingToken("grammar",":")) {
			if(this.acceptRoamingType()) {
				type = this.token.raw;
			} else {
				this.error("Type expected after colon (:)");
			}
		}
		if(!Object.prototype.hasOwnProperty.call(lib_Std_types.h,type)) {
			this.error("Type " + type + " does not exist.");
		}
		used_vars.h[name] = true;
		args.push({ name : name, type : type});
	}
	,acceptFunctionArgList: function(used_vars,args) {
		if(this.hasTokens()) {
			var vars = [];
			while(true) if(this.acceptRoamingToken("ident")) {
				var name = this.token.raw;
				if(name == null) {
					this.error("Variable required");
				}
				if(Object.prototype.hasOwnProperty.call(used_vars.h,name)) {
					this.error("Variable '" + name + "' is already used as an argument");
				}
				used_vars.h[name] = true;
				vars.push(name);
			} else if(this.acceptRoamingToken("grammar","]")) {
				break;
			} else {
				this.nextToken();
				this.error("Right square bracket (]) expected at end of argument list");
			}
			if(vars.length == 0) {
				this.trackBack();
				this.trackBack();
				this.error("Variables expected in variable list");
			}
			var type = "number";
			if(this.acceptRoamingToken("grammar",":")) {
				if(this.acceptRoamingType()) {
					type = this.token.raw;
				} else {
					this.error("Type expected after colon (:)");
				}
			}
			var _g = 0;
			while(_g < vars.length) {
				var v = vars[_g];
				++_g;
				args.push({ name : v, type : type});
			}
		} else {
			this.error("Variable expected after left square bracket ([) in argument list");
		}
	}
	,stmt1: function() {
		if(this.acceptRoamingToken("keyword","if")) {
			var trace = this.getTokenTrace();
			return this.instruction(trace,lib_Instr.If,[this.acceptCondition(),this.acceptBlock("if condition"),this.acceptIfElseIf(),false]);
		}
		return this.stmt2();
	}
	,stmt2: function() {
		if(this.acceptRoamingToken("keyword","while")) {
			var trace = this.getTokenTrace();
			this.depth++;
			var whl = this.instruction(trace,lib_Instr.While,[this.acceptCondition(),this.acceptBlock("while condition"),false]);
			this.depth--;
			return whl;
		}
		return this.stmt3();
	}
	,stmt3: function() {
		if(this.acceptRoamingToken("keyword","for")) {
			var trace = this.getTokenTrace();
			this.depth++;
			if(!this.acceptRoamingToken("grammar","(")) {
				this.error("Left parenthesis (() must appear before condition");
			}
			if(!this.acceptRoamingToken("ident")) {
				this.error("Variable expected for the numeric index");
			}
			var v = this.token.raw;
			if(!this.acceptRoamingToken("operator","=")) {
				this.error("Assignment operator (=) expected to preceed variable");
			}
			var estart = this.expr1();
			if(!this.acceptRoamingToken("grammar",",")) {
				this.error("Comma (,) expected after start value");
			}
			var estop = this.expr1();
			var estep = null;
			if(this.acceptRoamingToken("grammar",",")) {
				estep = this.expr1();
			}
			if(!this.acceptRoamingToken("grammar",")")) {
				this.error("Right parenthesis ()) missing, to close condition");
			}
			var sfor = this.instruction(trace,lib_Instr.For,[v,estart,estop,estep,this.acceptBlock("for statement")]);
			this.depth--;
			return sfor;
		}
		return this.stmt4();
	}
	,stmt4: function() {
		if(this.acceptRoamingToken("keyword","foreach")) {
			var trace = this.getTokenTrace();
			this.depth++;
			if(!this.acceptRoamingToken("grammar","(")) {
				this.error("Left parenthesis missing (() after foreach statement");
			}
			if(!this.acceptRoamingToken("ident")) {
				this.error("Variable expected to hold the key");
			}
			var keyvar = this.token.raw;
			var keytype = null;
			if(this.acceptRoamingToken("grammar",":")) {
				if(!this.acceptRoamingType()) {
					this.error("Type expected after colon");
				}
				keytype = this.token.raw;
				var typ = lib_Std_types.h[keytype];
				if(typ == null) {
					this.error("Unknown type: " + keytype);
				}
				keytype = typ.id;
			}
			if(!this.acceptRoamingToken("grammar",",")) {
				this.error("Comma (,) expected after key variable");
			}
			if(!this.acceptRoamingToken("ident")) {
				this.error("Variable expected to hold the value");
			}
			var valvar = this.token.raw;
			if(!this.acceptRoamingToken("grammar",":")) {
				this.error("Colon (:) expected to separate type from variable");
			}
			if(!this.acceptRoamingType()) {
				this.error("Type expected after colon");
			}
			var valtype = this.token.raw;
			var typ = lib_Std_types.h[valtype];
			if(typ == null) {
				this.error("Unknown type: " + valtype);
			}
			valtype = typ.id;
			if(!this.acceptRoamingToken("operator","=")) {
				this.error("Equals sign (=) expected after value type to specify table");
			}
			var tableexpr = this.expr1();
			if(!this.acceptRoamingToken("grammar",")")) {
				this.error("Missing right parenthesis after foreach statement");
			}
			var sfea = this.instruction(trace,lib_Instr.Foreach,[keyvar,keytype,valvar,valtype,tableexpr,this.acceptBlock("foreach statement")]);
			this.depth--;
			return sfea;
		}
		return this.stmt5();
	}
	,stmt5: function() {
		if(this.acceptRoamingToken("keyword","break")) {
			if(this.depth > 0) {
				var trace = this.getTokenTrace();
				return this.instruction(trace,lib_Instr.Break,[]);
			} else {
				this.error("Break may not exist outside of a loop");
			}
		} else if(this.acceptRoamingToken("keyword","continue")) {
			if(this.depth > 0) {
				var trace = this.getTokenTrace();
				return this.instruction(trace,lib_Instr.Continue,[]);
			} else {
				this.error("Continue may not exist outside of a loop");
			}
		}
		return this.stmt6();
	}
	,stmt6: function() {
		if(this.acceptRoamingToken("ident")) {
			var trace = this.getTokenTrace();
			var v = this.token.raw;
			if(this.acceptTailingToken("operator","++")) {
				return this.instruction(trace,lib_Instr.Increment,[v]);
			} else if(this.acceptRoamingToken("operator","++")) {
				this.error("Increment operator (++) must not be preceded by whitespace");
			}
			if(this.acceptTailingToken("operator","--")) {
				return this.instruction(trace,lib_Instr.Decrement,[v]);
			} else if(this.acceptRoamingToken("operator","--")) {
				this.error("Decrement operator (--) must not be preceded by whitespace");
			}
			this.trackBack();
		}
		return this.stmt7();
	}
	,stmt7: function() {
		if(this.acceptRoamingToken("ident")) {
			var trace = this.getTokenTrace();
			var v = this.token.raw;
			if(this.acceptRoamingToken("operator","+=")) {
				return this.instruction(trace,lib_Instr.Assign,[v,this.instruction(trace,lib_Instr.Add,[this.instruction(trace,lib_Instr.Var,[v]),this.expr1()])]);
			} else if(this.acceptRoamingToken("operator","-=")) {
				return this.instruction(trace,lib_Instr.Assign,[v,this.instruction(trace,lib_Instr.Sub,[this.instruction(trace,lib_Instr.Var,[v]),this.expr1()])]);
			} else if(this.acceptRoamingToken("operator","*=")) {
				return this.instruction(trace,lib_Instr.Assign,[v,this.instruction(trace,lib_Instr.Mul,[this.instruction(trace,lib_Instr.Var,[v]),this.expr1()])]);
			} else if(this.acceptRoamingToken("operator","/=")) {
				return this.instruction(trace,lib_Instr.Assign,[v,this.instruction(trace,lib_Instr.Div,[this.instruction(trace,lib_Instr.Var,[v]),this.expr1()])]);
			}
			this.trackBack();
		}
		return this.stmt8();
	}
	,stmt8: function(parentLocalized) {
		if(parentLocalized == null) {
			parentLocalized = false;
		}
		var localized = false;
		if(this.acceptRoamingToken("keyword","local")) {
			if(parentLocalized) {
				this.error("Assignment can't contain roaming local operator");
			}
			localized = true;
		}
		if(this.acceptRoamingToken("ident")) {
			var tbpos = this.index;
			var trace = this.getTokenTrace();
			var v = this.token.raw;
			if(this.acceptTailingToken("grammar","[")) {
				this.trackBack();
				var ind = this.acceptIndex();
				var indexs = [];
				if(ind != null) {
					var _g = 0;
					while(_g < ind.length) {
						var i = ind[_g];
						++_g;
						indexs.push(i);
					}
				}
				if(this.acceptRoamingToken("operator","=")) {
					if(localized || parentLocalized) {
						this.error("Invalid operator (local).");
					}
					var total = indexs.length;
					var inst = this.instruction(trace,lib_Instr.Var,[v]);
					var _g = 0;
					var _g1 = total;
					while(_g < _g1) {
						var i = _g++;
						var idx = indexs[i];
						var key = idx.key;
						var type = idx.type;
						var trace1 = idx.trace;
						if(i == total - 1) {
							inst = this.instruction(trace1,lib_Instr.IndexSet,[inst,key,this.stmt8(false),type]);
						} else {
							inst = this.instruction(trace1,lib_Instr.IndexGet,[inst,key,type]);
						}
					}
					return inst;
				}
			} else if(this.acceptRoamingToken("operator","=")) {
				if(localized || parentLocalized) {
					return this.instruction(trace,lib_Instr.LAssign,[v,this.stmt8(true)]);
				} else {
					return this.instruction(trace,lib_Instr.Assign,[v,this.stmt8(false)]);
				}
			} else if(localized) {
				this.error("Invalid operator (local) must be used for variable declaration.");
			}
			this.index = tbpos - 2;
			this.nextToken();
		} else if(localized) {
			this.error("Invalid operator (local) must be used for variable declaration.");
		}
		return this.stmt9();
	}
	,stmt9: function() {
		if(this.acceptRoamingToken("keyword","switch")) {
			var trace = this.getTokenTrace();
			if(!this.acceptRoamingToken("grammar","(")) {
				this.error("Left parenthesis (() expected before switch condition");
			}
			var expr = this.expr1();
			if(!this.acceptRoamingToken("grammar",")")) {
				this.error("Right parenthesis ()) expected after switch condition");
			}
			if(!this.acceptRoamingToken("grammar","{")) {
				this.error("Left curly bracket ({) expected after switch condition");
			}
			this.depth++;
			var cases = this.acceptSwitchBlock();
			this.depth--;
			return this.instruction(trace,lib_Instr.Switch,[expr,cases]);
		}
		return this.stmt10();
	}
	,stmt10: function() {
		if(this.acceptRoamingToken("keyword","function")) {
			var trace = this.getTokenTrace();
			var name = null;
			var ret = "void";
			var type = null;
			var name_token = null;
			var return_token = null;
			var type_token = null;
			var args = [];
			var used_vars = new haxe_ds_StringMap();
			if(this.acceptRoamingToken("lower_ident")) {
				name = this.token.raw;
				name_token = this.token;
				if(this.acceptRoamingToken("lower_ident")) {
					ret = name;
					return_token = name_token;
					name = this.token.raw;
					name_token = this.token;
				}
				if(this.acceptRoamingToken("grammar",":")) {
					if(this.acceptRoamingToken("lower_ident")) {
						type = name;
						type_token = name_token;
						name = this.token.raw;
						name_token = this.token;
					} else {
						this.error("Function name must appear after colon (:)");
					}
				}
			}
			if(ret != "void") {
				if(ret != ret.toLowerCase()) {
					this.error("Function return type must be lowercased",return_token);
				}
				ret = ret.toUpperCase();
			}
			if(type != null) {
				if(type != type.toLowerCase()) {
					this.error("Function object must be full lowercase",type_token);
				}
				if(type == "void") {
					this.error("Void cannot be used as function object type",type_token);
				}
				type = type.toUpperCase();
				used_vars.h["This"] = true;
				args[0] = { name : "This", type : type};
			}
			if(name == null) {
				this.error("Function name must follow function declaration");
			}
			var first_char = name.charAt(0);
			if(first_char != first_char.toLowerCase()) {
				this.error("Function name must start with a lower case letter",name_token);
			}
			if(!this.acceptRoamingToken("grammar","(")) {
				this.error("Left parenthesis (() must appear after function name");
			}
			this.acceptFunctionArgs(used_vars,args);
			var sig = name + "(";
			var _g = 1;
			var _g1 = args.length;
			while(_g < _g1) {
				var i = _g++;
				var arg = args[i];
				sig += lib_Std_types.h[arg.type].id;
				if(i == 1 && arg.name == "This" && type != "") {
					sig += ":";
				}
			}
			sig += ")";
			return this.instruction(trace,lib_Instr.Function,[name,ret,type,sig,args,this.acceptBlock("function declaration")]);
		} else if(this.acceptRoamingToken("keyword","return")) {
			var trace = this.getTokenTrace();
			if(this.acceptRoamingType("void") || this.readtoken != null && this.readtoken.raw == "}") {
				return this.instruction(trace,lib_Instr.Return,[]);
			}
			return this.instruction(trace,lib_Instr.Return,[this.expr1()]);
		} else if(this.acceptRoamingType("void")) {
			this.error("Void may only exist after return");
		}
		return this.stmt11();
	}
	,stmt11: function() {
		if(this.acceptRoamingToken("keyword","do")) {
			var trace = this.getTokenTrace();
			this.depth++;
			var block = this.acceptBlock("do keyword");
			if(!this.acceptRoamingToken("keyword","while")) {
				this.error("while expected after do block");
			}
			var condition = this.acceptCondition();
			var instr = this.instruction(trace,lib_Instr.While,[condition,block,true]);
			this.depth--;
			return instr;
		}
		return this.stmt12();
	}
	,stmt12: function() {
		if(this.acceptRoamingToken("keyword","try")) {
			var trace = this.getTokenTrace();
			var stmt = this.acceptBlock("try block");
			if(!this.acceptRoamingToken("keyword","catch")) {
				this.error("Try block must be followed by catch statement");
			}
			if(!this.acceptRoamingToken("grammar","(")) {
				this.error("Left parenthesis (() expected after catch keyword");
			}
			if(!this.acceptRoamingToken("ident")) {
				this.error("Variable expected after left parenthesis (() in catch statement");
			}
			var var_name = this.token.raw;
			if(!this.acceptRoamingToken("grammar",")")) {
				this.error("Right parenthesis ()) missing, to close catch statement");
			}
			return this.instruction(trace,lib_Instr.Try,[stmt,var_name,this.acceptBlock("catch block")]);
		}
		return this.expr1();
	}
	,expr1: function() {
		this.exprtoken = this.token;
		if(this.acceptRoamingToken("ident")) {
			if(this.acceptRoamingToken("operator","=")) {
				this.error("Assignment operator (=) must not be part of equation");
			}
			if(this.acceptRoamingToken("operator","+=")) {
				this.error("Additive assignment operator (+=) must not be part of equation");
			} else if(this.acceptRoamingToken("operator","-=")) {
				this.error("Subtractive assignment operator (-=) must not be part of equation");
			} else if(this.acceptRoamingToken("operator","*=")) {
				this.error("Multiplicative assignment operator (*=) must not be part of equation");
			} else if(this.acceptRoamingToken("operator","/=")) {
				this.error("Divisive assignment operator (/=) must not be part of equation");
			}
			this.trackBack();
		}
		return this.expr2();
	}
	,expr2: function() {
		var expr = this.expr3();
		if(this.acceptRoamingToken("operator","?")) {
			var trace = this.getTokenTrace();
			var exprtrue = this.expr1();
			if(!this.acceptRoamingToken("grammar",":")) {
				this.error("Conditional operator (:) must appear after expression to complete conditional",this.token);
			}
			return this.instruction(trace,lib_Instr.Ternary,[expr,exprtrue,this.expr1()]);
		}
		if(this.acceptRoamingToken("grammar","?:")) {
			var trace = this.getTokenTrace();
			return this.instruction(trace,lib_Instr.TernaryDefault,[expr,this.expr1()]);
		}
		return expr;
	}
	,expr3: function() {
		return this.recurseLeftOp($bind(this,this.expr4),["||"],[lib_Instr.Bor]);
	}
	,expr4: function() {
		return this.recurseLeftOp($bind(this,this.expr5),["&&"],[lib_Instr.BAnd]);
	}
	,expr5: function() {
		return this.recurseLeftOp($bind(this,this.expr6),["|"],[lib_Instr.Or]);
	}
	,expr6: function() {
		return this.recurseLeftOp($bind(this,this.expr7),["&"],[lib_Instr.And]);
	}
	,expr7: function() {
		return this.recurseLeftOp($bind(this,this.expr8),["^^"],[lib_Instr.BXor]);
	}
	,expr8: function() {
		return this.recurseLeftOp($bind(this,this.expr9),["==","!="],[lib_Instr.Equal,lib_Instr.NotEqual]);
	}
	,expr9: function() {
		return this.recurseLeftOp($bind(this,this.expr10),[">","<",">=","<="],[lib_Instr.GreaterThan,lib_Instr.LessThan,lib_Instr.GreaterThanEq,lib_Instr.LessThanEq]);
	}
	,expr10: function() {
		return this.recurseLeftOp($bind(this,this.expr11),[">>","<<"],[lib_Instr.BShl,lib_Instr.BShr]);
	}
	,expr11: function() {
		return this.recurseLeftOp($bind(this,this.expr12),["+","-"],[lib_Instr.Add,lib_Instr.Sub]);
	}
	,expr12: function() {
		return this.recurseLeftOp($bind(this,this.expr13),["*","/","%"],[lib_Instr.Mul,lib_Instr.Div,lib_Instr.Mod]);
	}
	,expr13: function() {
		return this.recurseLeftOp($bind(this,this.expr14),["^"],[lib_Instr.Exp]);
	}
	,expr14: function() {
		if(this.acceptLeadingToken("operator","+")) {
			return this.expr15();
		} else if(this.acceptRoamingToken("operator","+")) {
			this.error("Identity operator (+) must not be succeeded by whitespace");
		}
		if(this.acceptLeadingToken("operator","-")) {
			var trace = this.getTokenTrace();
			return this.instruction(trace,lib_Instr.Negative,[this.expr15()]);
		} else if(this.acceptRoamingToken("operator","-")) {
			this.error("Negation operator (-) must not be succeeded by whitespace");
		}
		if(this.acceptLeadingToken("operator","!")) {
			var trace = this.getTokenTrace();
			return this.instruction(trace,lib_Instr.Not,[this.expr14()]);
		} else if(this.acceptRoamingToken("operator","!")) {
			this.error("Logical not operator (!) must not be succeeded by whitespace");
		}
		return this.expr15();
	}
	,expr15: function() {
		var expr = this.expr16();
		while(true) if(this.acceptTailingToken("grammar",":")) {
			if(!this.acceptTailingToken("lower_ident")) {
				if(this.acceptRoamingToken("lower_ident")) {
					this.error("Method operator (:) must not be preceded by whitespace");
				} else {
					this.error("Method operator (:) must be followed by method name");
				}
			}
			var trace = this.getTokenTrace();
			var fun = this.token.raw;
			if(!this.acceptTailingToken("grammar","(")) {
				if(this.acceptRoamingToken("grammar","(")) {
					this.error("Left parenthesis (() must not be preceded by whitespace");
				} else {
					this.error("Left parenthesis (() must appear after method name");
				}
			}
			var token = this.token;
			if(this.acceptRoamingToken("grammar",")")) {
				expr = this.instruction(trace,lib_Instr.Methodcall,[fun,expr]);
			} else {
				var exprs = [this.expr1()];
				while(this.acceptRoamingToken("grammar",",")) exprs.push(this.expr1());
				if(!this.acceptRoamingToken("grammar",")")) {
					this.error("Right parenthesis ()) missing, to close method argument list",token);
				}
				expr = this.instruction(trace,lib_Instr.Methodcall,[fun,expr,exprs]);
			}
		} else if(this.acceptTailingToken("grammar","[")) {
			var trace1 = this.getTokenTrace();
			if(this.acceptRoamingToken("grammar","]")) {
				this.error("Indexing operator ([]) requires an index [X]");
			}
			var aexpr = this.expr1();
			if(this.acceptRoamingToken("grammar",",")) {
				var typ = this.assertRoamingType();
				var longtp = this.token.raw;
				if(!this.acceptRoamingToken("grammar","]")) {
					this.error("Right square bracket (]) missing, to close indexing operator [X,t]");
				}
				var typ1 = lib_Std_types.h[longtp];
				expr = this.instruction(trace1,lib_Instr.IndexGet,[expr,aexpr,typ1.id]);
			} else if(this.acceptRoamingToken("grammar","]")) {
				expr = this.instruction(trace1,lib_Instr.IndexGet,[expr,aexpr]);
			} else {
				this.error("Indexing operator ([]) needs to be closed with comma (,) or right square bracket (])");
			}
		} else if(this.acceptRoamingToken("grammar","[") && this.token.whitespaced) {
			this.error("Indexing operator ([]) must not be preceded by whitespace");
		} else if(this.acceptTailingToken("grammar","(")) {
			var trace2 = this.getTokenTrace();
			var token1 = this.token;
			var exprs1 = [];
			if(this.acceptRoamingToken("grammar",")")) {
				exprs1 = [];
			} else {
				exprs1 = [this.expr1()];
				while(this.acceptRoamingToken("grammar",",")) exprs1.push(this.expr1());
				if(!this.acceptRoamingToken("grammar",")")) {
					this.error("Right parenthesis ()) missing, to close function argument list",token1);
				}
			}
			if(this.acceptRoamingToken("grammar","[")) {
				if(!this.acceptRoamingType()) {
					this.error("Return type operator ([]) does not support the type [" + this.token.raw + "]");
				}
				var longtp1 = this.token.raw;
				if(!this.acceptRoamingToken("grammar","]")) {
					this.error("Right square bracket (]) missing, to close return type operator");
				}
				var stype = lib_Std_types.h[longtp1].id;
				expr = this.instruction(trace2,lib_Instr.Stringcall,[expr,exprs1,stype]);
			} else {
				expr = this.instruction(trace2,lib_Instr.Stringcall,[expr,exprs1,null]);
			}
		} else {
			break;
		}
		return expr;
	}
	,expr16: function() {
		if(this.acceptRoamingToken("grammar","(")) {
			var trace = this.getTokenTrace();
			var token = this.token;
			var expr = this.expr1();
			if(!this.acceptRoamingToken("grammar",")")) {
				this.error("Right parenthesis ()) missing, to close grouped equation",token);
			}
			return this.instruction(trace,lib_Instr.GroupedEquation,[expr]);
		}
		if(this.acceptRoamingToken("lower_ident")) {
			var trace = this.getTokenTrace();
			var fun = this.token.raw;
			if(!this.acceptTailingToken("grammar","(")) {
				if(this.acceptRoamingToken("grammar","(")) {
					this.error("Left parenthesis (() must not be preceded by whitespace");
				} else {
					this.error("Left parenthesis (() must appear after function name, variables must start with uppercase letter,");
				}
			}
			var token = this.token;
			if(this.acceptRoamingToken("grammar",")")) {
				return this.instruction(trace,lib_Instr.Call,[fun,[]]);
			} else {
				var kv_exprs = new haxe_ds_ObjectMap();
				var i_exprs = [];
				if(fun == "table" || fun == "array") {
					var kvtable = false;
					var key = this.expr1();
					if(this.acceptRoamingToken("operator","=")) {
						if(this.acceptRoamingToken("grammar",")")) {
							this.error("Expression expected, got right paranthesis ())",this.token);
						}
						var v = this.expr1();
						kv_exprs.set(key,v);
						kvtable = true;
					} else {
						i_exprs = [key];
					}
					if(kvtable) {
						while(this.acceptRoamingToken("grammar",",")) {
							var key = this.expr1();
							var token1 = this.token;
							if(this.acceptRoamingToken("operator","=")) {
								if(this.acceptRoamingToken("grammar",")")) {
									this.error("Expression expected, got right paranthesis ())",this.token);
								}
								var v = this.expr1();
								kv_exprs.set(key,v);
							} else {
								this.error("Assignment operator (=) missing, to complete expression",token1);
							}
						}
						if(!this.acceptRoamingToken("grammar",")")) {
							this.error("Right parenthesis ()) missing, to close function argument list",this.token);
						}
						if(fun == "table") {
							return this.instruction(trace,lib_Instr.KVTable,[kv_exprs,i_exprs]);
						} else {
							return this.instruction(trace,lib_Instr.KVArray,[kv_exprs,i_exprs]);
						}
					}
				} else {
					i_exprs = [this.expr1()];
				}
				while(this.acceptRoamingToken("grammar",",")) i_exprs.push(this.expr1());
				if(!this.acceptRoamingToken("grammar",")")) {
					this.error("Right parenthesis ()) missing, to close function argument list",token);
				}
				return this.instruction(trace,lib_Instr.Call,[fun,kv_exprs,i_exprs]);
			}
		}
		return this.expr17();
	}
	,expr17: function() {
		if(this.acceptRoamingToken("number")) {
			var trace = this.getTokenTrace();
			return this.instruction(trace,lib_Instr.Literal,[this.token.literal,this.token.raw]);
		}
		if(this.acceptRoamingToken("string")) {
			var trace = this.getTokenTrace();
			return this.instruction(trace,lib_Instr.Literal,[this.token.literal,this.token.raw]);
		}
		if(this.acceptRoamingToken("operator","~")) {
			var trace = this.getTokenTrace();
			if(!this.acceptTailingToken("ident")) {
				if(this.acceptRoamingToken("ident")) {
					this.error("Triggered operator (~) must not be succeeded by whitespace");
				} else {
					this.error("Triggered operator (~) must be preceded by variable");
				}
			}
			var v = this.getLiteralString();
			return this.instruction(trace,lib_Instr.Triggered,[v]);
		}
		if(this.acceptRoamingToken("operator","$")) {
			var trace = this.getTokenTrace();
			if(!this.acceptTailingToken("ident")) {
				if(this.acceptRoamingToken("ident")) {
					this.error("Delta operator ($) must not be succeeded by whitespace");
				} else {
					this.error("Delta operator ($) must be preceded by variable");
				}
			}
			var v = this.token.raw;
			this.delta.h[v] = true;
			return this.instruction(trace,lib_Instr.Delta,[v]);
		}
		if(this.acceptRoamingToken("operator","->")) {
			var trace = this.getTokenTrace();
			if(!this.acceptTailingToken("ident")) {
				if(this.acceptRoamingToken("ident")) {
					this.error("Connected operator (->) must not be succeeded by whitespace");
				} else {
					this.error("Connected operator (->) must be preceded by variable");
				}
			}
			var v = this.getLiteralString();
			return this.instruction(trace,lib_Instr.Connected,[v]);
		}
		return this.expr18();
	}
	,expr18: function() {
		if(this.acceptRoamingToken("ident")) {
			if(this.acceptTailingToken("operator","++")) {
				this.error("Increment operator (++) must not be part of equation");
			} else if(this.acceptRoamingToken("operator","++")) {
				this.error("Increment operator (++) must not be preceded by whitespace");
			}
			if(this.acceptTailingToken("operator","--")) {
				this.error("Decrement operator (--) must not be part of equation");
			} else if(this.acceptRoamingToken("operator","--")) {
				this.error("Decrement operator (--) must not be preceded by whitespace");
			}
			this.trackBack();
		}
		return this.expr19();
	}
	,expr19: function() {
		if(this.acceptRoamingToken("ident")) {
			return this.instruction(this.getTokenTrace(),lib_Instr.Var,[this.token.raw]);
		}
		return this.exprError();
	}
	,exprError: function() {
		if(!this.hasTokens()) {
			this.error("Further input required at } of code, incomplete expression",this.exprtoken);
		}
		if(this.acceptRoamingToken("operator","+")) {
			this.error("Addition operator (+) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","-")) {
			this.error("Subtraction operator (-) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","*")) {
			this.error("Multiplication operator (*) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","/")) {
			this.error("Division operator (/) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","%")) {
			this.error("Modulo operator (%) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","^")) {
			this.error("Exponentiation operator (^) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","=")) {
			this.error("Assignment operator (=) must be preceded by variable");
		} else if(this.acceptRoamingToken("operator","+=")) {
			this.error("Additive assignment operator (+=) must be preceded by variable");
		} else if(this.acceptRoamingToken("operator","-=")) {
			this.error("Subtractive assignment operator (-=) must be preceded by variable");
		} else if(this.acceptRoamingToken("operator","*=")) {
			this.error("Multiplicative assignment operator (*=) must be preceded by variable");
		} else if(this.acceptRoamingToken("operator","/=")) {
			this.error("Divisive assignment operator (/=) must be preceded by variable");
		} else if(this.acceptRoamingToken("operator","&")) {
			this.error("Logical and operator (&) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","|")) {
			this.error("Logical or operator (|) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","==")) {
			this.error("Equality operator (==) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","!=")) {
			this.error("Inequality operator (!=) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator",">=")) {
			this.error("Greater than or equal to operator (>=) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","<=")) {
			this.error("Less than or equal to operator (<=) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator",">")) {
			this.error("Greater than operator (>) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","<")) {
			this.error("Less than operator (<) must be preceded by equation or value");
		} else if(this.acceptRoamingToken("operator","++")) {
			this.error("Increment operator (++) must be preceded by variable");
		} else if(this.acceptRoamingToken("operator","--")) {
			this.error("Decrement operator (--) must be preceded by variable");
		} else if(this.acceptRoamingToken("grammar",")")) {
			this.error("Right parenthesis ()) without matching left parenthesis");
		} else if(this.acceptRoamingToken("grammar","(")) {
			this.error("Left curly bracket ({) must be part of an if/while/for-statement block");
		} else if(this.acceptRoamingToken("grammar","{")) {
			this.error("Right curly bracket (}) without matching left curly bracket");
		} else if(this.acceptRoamingToken("grammar","[")) {
			this.error("Left square bracket ([) must be preceded by variable");
		} else if(this.acceptRoamingToken("grammar","]")) {
			this.error("Right square bracket (]) without matching left square bracket");
		} else if(this.acceptRoamingToken("grammar",",")) {
			this.error("Comma (,) not expected here, missing an argument?");
		} else if(this.acceptRoamingToken("operator",":")) {
			this.error("Method operator (:) must not be preceded by whitespace");
		} else if(this.acceptRoamingToken("keyword","if")) {
			this.error("If keyword (if) must not appear inside an equation");
		} else if(this.acceptRoamingToken("keyword","elseif")) {
			this.error("Else-if keyword (} else if) must be part of an if-statement");
		} else if(this.acceptRoamingToken("keyword","else")) {
			this.error("Else keyword (else) must be part of an if-statement");
		} else {
			this.error("Unexpected token found (" + this.readtoken.id + ")");
		}
		return null;
	}
};
var base_Preprocessor = function() {
	this.repl_order_index = 0;
	this.repl_order = [];
	this.repl = new haxe_ds_ObjectMap();
	this.add_replacement(new EReg("#\\[[\\s\\S]*\\]#","g"),base_Preprocessor_FILL_WHITESPACE);
	this.add_replacement(new EReg("#[^\n]*","g"),base_Preprocessor_FILL_WHITESPACE);
	this.add_replacement(new EReg("@[^\n]*","g"),base_Preprocessor_FILL_WHITESPACE);
};
base_Preprocessor.__name__ = true;
base_Preprocessor.prototype = {
	process: function(script) {
		var processed = script;
		var _g = 0;
		var _g1 = this.repl_order;
		while(_g < _g1.length) {
			var regex = _g1[_g];
			++_g;
			processed = regex.map(processed,this.repl.h[regex.__id__]);
		}
		return processed;
	}
	,add_replacement: function(regex,$with) {
		this.repl_order[this.repl_order_index] = regex;
		this.repl_order_index++;
		this.repl.set(regex,$with);
	}
};
function base_Preprocessor_FILL_WHITESPACE(x) {
	return hx_strings_Strings.repeat(" ",x.matched(0).length);
}
var base_TokenType = $hxEnums["base.TokenType"] = { __ename__:true,__constructs__:null
	,Literal: {_hx_name:"Literal",_hx_index:0,__enum__:"base.TokenType",toString:$estr}
	,Identifier: {_hx_name:"Identifier",_hx_index:1,__enum__:"base.TokenType",toString:$estr}
	,Type: {_hx_name:"Type",_hx_index:2,__enum__:"base.TokenType",toString:$estr}
	,Constant: {_hx_name:"Constant",_hx_index:3,__enum__:"base.TokenType",toString:$estr}
	,Operator: {_hx_name:"Operator",_hx_index:4,__enum__:"base.TokenType",toString:$estr}
	,Grammar: {_hx_name:"Grammar",_hx_index:5,__enum__:"base.TokenType",toString:$estr}
	,Whitespace: {_hx_name:"Whitespace",_hx_index:6,__enum__:"base.TokenType",toString:$estr}
	,Keyword: {_hx_name:"Keyword",_hx_index:7,__enum__:"base.TokenType",toString:$estr}
	,Invalid: {_hx_name:"Invalid",_hx_index:8,__enum__:"base.TokenType",toString:$estr}
};
base_TokenType.__constructs__ = [base_TokenType.Literal,base_TokenType.Identifier,base_TokenType.Type,base_TokenType.Constant,base_TokenType.Operator,base_TokenType.Grammar,base_TokenType.Whitespace,base_TokenType.Keyword,base_TokenType.Invalid];
var base_TokenMatch = function(identifier,pattern,tt,flag,processor) {
	if(flag == null) {
		flag = 0;
	}
	this.id = identifier;
	this.tt = tt;
	this.flag = flag;
	this.pattern = pattern;
	this.processor = processor;
};
base_TokenMatch.__name__ = true;
base_TokenMatch.prototype = {
	match: function(haystack,pos) {
		if(pos == null) {
			pos = 0;
		}
		if(this.pattern.matchSub(haystack,pos)) {
			var matchedpos = this.pattern.matchedPos();
			if(matchedpos.pos == pos) {
				var tok = base_Token.from(matchedpos,this.pattern.matched(0),this);
				if(this.processor != null) {
					this.processor(tok,this.pattern);
				}
				return tok;
			}
		}
		return null;
	}
};
var base_Token = function(pos,len,raw,id,flag,tt) {
	if(tt == null) {
		tt = base_TokenType.Invalid;
	}
	if(flag == null) {
		flag = 0;
	}
	this.start = pos;
	this.end = pos + len;
	this.len = len;
	this.raw = raw;
	this.id = id;
	this.flag = flag;
	this.tt = tt;
	this.char = pos;
	this.line = 1;
	this.literal = lib_E2Value.Void;
	this.properties = new haxe_ds_StringMap();
};
base_Token.__name__ = true;
base_Token.from = function(result,raw,matcher) {
	return new base_Token(result.pos,result.len,raw,matcher.id,matcher.flag,matcher.tt);
};
base_Token.prototype = {
	toString: function() {
		return "Token [tt: " + Std.string(this.tt) + ", raw: \"" + this.raw + "\", id: " + this.id + ", %s: " + Std.string(this.whitespaced) + ", literal: " + Std.string(this.literal) + "]";
	}
};
var base_Tokenizer = function() {
	this.token_matchers = [new base_TokenMatch("whitespace",new EReg("\\s+",""),base_TokenType.Whitespace,1),new base_TokenMatch("grammar",new EReg("{|}|,|;|:|\\(|\\)|\\[|\\]",""),base_TokenType.Grammar),new base_TokenMatch("keyword",new EReg("\\belseif|if|else|break|continue|local|while|switch|case|default|try|catch|foreach|for|function|return|do\\b",""),base_TokenType.Keyword),new base_TokenMatch("string",new EReg("(\"[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*\")",""),base_TokenType.Literal,0,function(token,pattern) {
		token.literal = lib_E2Value.String(pattern.matched(0));
	}),new base_TokenMatch("number",new EReg("-?(0[xX][0-9a-fA-F]+)|(-?(\\d*\\.)?\\d+)",""),base_TokenType.Literal,0,function(token,pattern) {
		var value = parseFloat(pattern.matched(0));
		if(isNaN(value)) {
			throw haxe_Exception.thrown("Invalid number matched! Wtf????");
		}
		token.literal = lib_E2Value.Number(value);
	}),new base_TokenMatch("constant",new EReg("_\\w[_\\w]*",""),base_TokenType.Constant,0,function(token,pattern) {
		var name = pattern.matched(0);
		token.id = "number";
		token.literal = lib_E2Value.Number(1000);
		token.tt = base_TokenType.Literal;
		token.raw = "1000";
	}),new base_TokenMatch("lower_ident",new EReg("[a-z]\\w*",""),base_TokenType.Identifier,0,function(token,pattern) {
		var match = pattern.matched(0);
		if(hx_strings_Strings.isLowerCase(match)) {
			if(Object.prototype.hasOwnProperty.call(lib_Std_types.h,match)) {
				token.properties.h["type"] = true;
			}
			token.properties.h["lowercase"] = true;
		} else {
			token.properties.h["lowercase"] = false;
		}
	}),new base_TokenMatch("ident",new EReg("[A-Z]\\w*",""),base_TokenType.Identifier),new base_TokenMatch("operator",new EReg("==|!=|\\*=|\\+=|-=|/=|%=|<<|>>|&&|\\|{2}|\\+{2}|->|>=|<=|\\^{2}|\\?:|<|>|\\+|-|\\*|/|=|!|~|\\$|~|\\?|%|\\||\\^|&|:",""),base_TokenType.Operator)];
};
base_Tokenizer.__name__ = true;
base_Tokenizer.prototype = {
	process: function(script) {
		var out = [];
		var pointer = 0;
		var cur_line = 1;
		var whitespaced = false;
		var did_match;
		while(true) {
			did_match = false;
			var _g = 0;
			var _g1 = this.token_matchers;
			while(_g < _g1.length) {
				var tokenizer = _g1[_g];
				++_g;
				var token = tokenizer.match(script,pointer);
				if(token != null) {
					pointer = token.end;
					var v = 1;
					if((tokenizer.flag & v) != v) {
						token.line = cur_line;
						token.whitespaced = whitespaced;
						out.push(token);
					} else if(token.tt == base_TokenType.Whitespace) {
						cur_line += hx_strings_Strings.countMatches(token.raw,"\n");
					}
					whitespaced = token.tt == base_TokenType.Whitespace;
					did_match = true;
					break;
				}
			}
			if(!did_match) {
				throw new haxe_Exception("Unknown character [\"" + script.charAt(pointer) + "\"] at line " + cur_line + ", char " + pointer + " in script.");
			}
			if(!(pointer < script.length)) {
				break;
			}
		}
		return out;
	}
};
var base_transpiler_Instructions = function() { };
base_transpiler_Instructions.__name__ = true;
base_transpiler_Instructions.instr_root = function(instrs) {
	var _g = [];
	var _g1 = 0;
	while(_g1 < instrs.length) {
		var instr = instrs[_g1];
		++_g1;
		_g.push(base_transpiler_Lua_callInstruction(instr.id,instr.args));
	}
	var out = _g;
	return hx_strings_Strings.replaceAll(out.join("\n\n"),"\t\n","");
};
base_transpiler_Instructions.instr_call = function(name,kvargs,iargs) {
	if(iargs != null) {
		var result = new Array(iargs.length);
		var _g = 0;
		var _g1 = iargs.length;
		while(_g < _g1) {
			var i = _g++;
			var x = iargs[i];
			result[i] = base_transpiler_Lua_callInstruction(x.id,x.args);
		}
		var args = result;
		return "" + name + "(" + args.join(", ") + ")";
	}
	return "" + name + "()";
};
base_transpiler_Instructions.instr_methodcall = function(meta_fname,meta_obj,iargs) {
	var tmp = "" + base_transpiler_Lua_callInstruction(meta_obj.id,meta_obj.args) + ":" + meta_fname + "(";
	var tmp1;
	if(iargs != null) {
		var result = new Array(iargs.length);
		var _g = 0;
		var _g1 = iargs.length;
		while(_g < _g1) {
			var i = _g++;
			var x = iargs[i];
			result[i] = base_transpiler_Lua_callInstruction(x.id,x.args);
		}
		tmp1 = result.join(", ");
	} else {
		tmp1 = "";
	}
	return tmp + tmp1 + ")";
};
base_transpiler_Instructions.instr_literal = function(value,raw) {
	return raw;
};
base_transpiler_Instructions.instr_if = function(cond,block,ifeifs,is_else) {
	if(ifeifs != null) {
		var tmp = "if " + base_transpiler_Lua_callInstruction(cond.id,cond.args) + " then\n";
		var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
		var tmp1 = tmp + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n");
		var result = new Array(ifeifs.length);
		var _g = 0;
		var _g1 = ifeifs.length;
		while(_g < _g1) {
			var i = _g++;
			var x = ifeifs[i];
			result[i] = base_transpiler_Lua_callInstruction(x.id,x.args);
		}
		return tmp1 + result.join("") + "end";
	} else if(is_else) {
		var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
		return "else\n" + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n");
	} else {
		var tmp = "elseif " + base_transpiler_Lua_callInstruction(cond.id,cond.args) + " then\n";
		var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
		return tmp + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n");
	}
};
base_transpiler_Instructions.instr_for = function(varname,start,end,inc,block) {
	var startv = base_transpiler_Lua_callInstruction(start.id,start.args);
	var endv = base_transpiler_Lua_callInstruction(end.id,end.args);
	var incby = inc == null ? "1" : base_transpiler_Lua_callInstruction(inc.id,inc.args);
	var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
	return "for " + varname + " = " + startv + ", " + endv + ", " + incby + " do\n" + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n") + "\t::_continue_::\n" + "end";
};
base_transpiler_Instructions.instr_foreach = function(keyname,keytype,valname,valtype,tblexpr,block) {
	var tmp = "for " + keyname + ", " + valname + " in pairs(" + base_transpiler_Lua_callInstruction(tblexpr.id,tblexpr.args) + ") do\n";
	var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
	return tmp + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n") + "\t::_continue_::\n" + "end";
};
base_transpiler_Instructions.instr_while = function(cond,block,is_dowhile) {
	if(is_dowhile) {
		var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
		return "while true do\n" + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t")) + "\tif not cond then break end\n" + "\t::_continue_::\n" + "end";
	}
	var tmp = "while " + base_transpiler_Lua_callInstruction(cond.id,cond.args) + " do\n";
	var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
	return tmp + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n") + "\t::_continue_::\n" + "end";
};
base_transpiler_Instructions.instr_var = function(name) {
	return name;
};
base_transpiler_Instructions.instr_switch = function(topexpr,cases) {
	base_transpiler_Lua_IN_SWITCH = true;
	var topvar = base_transpiler_Lua_callInstruction(topexpr.id,topexpr.args);
	var out = "local _switch_result = " + topvar + "\n";
	var _g_current = 0;
	var _g_array = cases;
	while(_g_current < _g_array.length) {
		var _g1_value = _g_array[_g_current];
		var _g1_key = _g_current++;
		var key = _g1_key;
		var c = _g1_value;
		if(c.match != null) {
			var instr = c.match;
			var match = base_transpiler_Lua_callInstruction(instr.id,instr.args);
			var instr1 = c.block;
			var out1 = base_transpiler_Lua_callInstruction(instr1.id,[instr1.args]);
			out += "" + (key == 0 ? "" : "else") + "if _switch_result == " + match + " then\n" + ("\t" + hx_strings_Strings.replaceAll(out1,"\n","\n\t") + "\n");
		} else {
			var instr2 = c.block;
			var out2 = base_transpiler_Lua_callInstruction(instr2.id,[instr2.args]);
			out += "else\n" + ("\t" + hx_strings_Strings.replaceAll(out2,"\n","\n\t") + "\n");
			break;
		}
	}
	out += "end";
	base_transpiler_Lua_IN_SWITCH = false;
	return out;
};
base_transpiler_Instructions.instr_break = function() {
	if(base_transpiler_Lua_IN_SWITCH) {
		return "";
	} else {
		return "break";
	}
};
base_transpiler_Instructions.instr_continue = function() {
	return "goto _continue_";
};
base_transpiler_Instructions.instr_return = function(val) {
	return "return " + base_transpiler_Lua_callInstruction(val.id,val.args);
};
base_transpiler_Instructions.instr_not = function(v) {
	return "not " + base_transpiler_Lua_callInstruction(v.id,v.args);
};
base_transpiler_Instructions.instr_and = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " and " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_or = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " or " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_increment = function(varname) {
	return "" + varname + " = " + varname + " + 1";
};
base_transpiler_Instructions.instr_decrement = function(varname) {
	return "" + varname + " = " + varname + " - 1";
};
base_transpiler_Instructions.instr_negative = function(v) {
	return "-" + base_transpiler_Lua_callInstruction(v.id,v.args);
};
base_transpiler_Instructions.instr_mod = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " % " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_add = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " + " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_sub = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " - " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_div = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " / " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_mul = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " * " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_exp = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " ^ " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_equal = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " == " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_notequal = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " ~= " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_lessthaneq = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " <= " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_greaterthaneq = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " >= " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_greaterthan = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " > " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_lessthan = function(v1,v2) {
	return "" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + " < " + base_transpiler_Lua_callInstruction(v2.id,v2.args);
};
base_transpiler_Instructions.instr_groupedequation = function(v1) {
	return "(" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + ")";
};
base_transpiler_Instructions.instr_assign = function(varname,to) {
	return "" + varname + " = " + base_transpiler_Lua_callInstruction(to.id,to.args);
};
base_transpiler_Instructions.instr_lassign = function(varname,to) {
	return "local " + varname + " = " + base_transpiler_Lua_callInstruction(to.id,to.args);
};
base_transpiler_Instructions.instr_function = function(name,ret_type,meta_type,sig,args,decl) {
	var tmp = "function " + (meta_type != null ? "" + meta_type + "_" : "") + name + "(";
	var result = new Array(args.length);
	var _g = 0;
	var _g1 = args.length;
	while(_g < _g1) {
		var i = _g++;
		result[i] = args[i].name;
	}
	var tmp1 = tmp + result.join(", ") + ")\n";
	var out = base_transpiler_Lua_callInstruction(decl.id,[decl.args]);
	return tmp1 + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n") + "end";
};
base_transpiler_Instructions.instr_ternary = function(cond,success,fallback) {
	return "" + base_transpiler_Lua_callInstruction(cond.id,cond.args) + " and " + base_transpiler_Lua_callInstruction(success.id,success.args) + " or " + base_transpiler_Lua_callInstruction(fallback.id,fallback.args);
};
base_transpiler_Instructions.instr_try = function(block,var_name,catch_block) {
	var out = base_transpiler_Lua_callInstruction(block.id,[block.args]);
	var tmp = "xpcall(function()\n" + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n") + ("end, function(" + var_name + ")\n");
	var out = base_transpiler_Lua_callInstruction(catch_block.id,[catch_block.args]);
	return tmp + ("\t" + hx_strings_Strings.replaceAll(out,"\n","\n\t") + "\n") + "end)";
};
base_transpiler_Instructions.instr_stringcall = function(name,args,ret_type) {
	var tmp = "_G[" + base_transpiler_Lua_callInstruction(name.id,name.args) + "](";
	var result = new Array(args.length);
	var _g = 0;
	var _g1 = args.length;
	while(_g < _g1) {
		var i = _g++;
		var x = args[i];
		result[i] = base_transpiler_Lua_callInstruction(x.id,x.args);
	}
	return tmp + result.join(", ") + ")";
};
base_transpiler_Instructions.instr_indexget = function(tbl,key,type) {
	return "" + base_transpiler_Lua_callInstruction(tbl.id,tbl.args) + "[" + base_transpiler_Lua_callInstruction(key.id,key.args) + "]";
};
base_transpiler_Instructions.instr_indexset = function(tbl,key,value,type) {
	return "" + base_transpiler_Lua_callInstruction(tbl.id,tbl.args) + "[" + base_transpiler_Lua_callInstruction(key.id,key.args) + "] = " + base_transpiler_Lua_callInstruction(value.id,value.args);
};
base_transpiler_Instructions.instr_kvtable = function(kvmap,imap) {
	var _g = [];
	var map = kvmap;
	var _g1_map = map;
	var _g1_keys = map.keys();
	while(_g1_keys.hasNext()) {
		var key = _g1_keys.next();
		var _g2_value = _g1_map.get(key);
		var _g2_key = key;
		var k = _g2_key;
		var v = _g2_value;
		_g.push("[" + base_transpiler_Lua_callInstruction(k.id,k.args) + "] = " + base_transpiler_Lua_callInstruction(v.id,v.args));
	}
	var kvargs = _g;
	var tmp = "{\n" + ("\t" + kvargs.join(",\n\t") + "\n");
	var result = new Array(imap.length);
	var _g = 0;
	var _g1 = imap.length;
	while(_g < _g1) {
		var i = _g++;
		var x = imap[i];
		result[i] = base_transpiler_Lua_callInstruction(x.id,x.args);
	}
	return tmp + ("\t" + result.join(",\n\t") + "\n") + "}";
};
base_transpiler_Instructions.instr_kvarray = function(kvmap,imap) {
	var _g = [];
	var map = kvmap;
	var _g1_map = map;
	var _g1_keys = map.keys();
	while(_g1_keys.hasNext()) {
		var key = _g1_keys.next();
		var _g2_value = _g1_map.get(key);
		var _g2_key = key;
		var k = _g2_key;
		var v = _g2_value;
		_g.push("[" + base_transpiler_Lua_callInstruction(k.id,k.args) + "] = " + base_transpiler_Lua_callInstruction(v.id,v.args));
	}
	var kvargs = _g;
	var tmp = "{\n" + ("\t" + kvargs.join(",\n\t") + "\n");
	var result = new Array(imap.length);
	var _g = 0;
	var _g1 = imap.length;
	while(_g < _g1) {
		var i = _g++;
		var x = imap[i];
		result[i] = base_transpiler_Lua_callInstruction(x.id,x.args);
	}
	return tmp + ("\t" + result.join(",\n\t") + "\n") + "}";
};
base_transpiler_Instructions.instr_ternarydefault = function(val,els) {
	return "" + base_transpiler_Lua_callInstruction(val.id,val.args) + " or " + base_transpiler_Lua_callInstruction(els.id,els.args);
};
base_transpiler_Instructions.instr_include = function() {
	return "error('Not implemented in the parser.')";
};
base_transpiler_Instructions.instr_triggered = function(varname) {
	return "false";
};
base_transpiler_Instructions.instr_delta = function(varname) {
	return "false";
};
base_transpiler_Instructions.instr_connected = function(varname) {
	return "false";
};
base_transpiler_Instructions.instr_bor = function(v1,v2) {
	return "bit.bor(" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + ", " + base_transpiler_Lua_callInstruction(v2.id,v2.args) + ")";
};
base_transpiler_Instructions.instr_band = function(v1,v2) {
	return "bit.band(" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + ", " + base_transpiler_Lua_callInstruction(v2.id,v2.args) + ")";
};
base_transpiler_Instructions.instr_bxor = function(v1,v2) {
	return "bit.bxor(" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + ", " + base_transpiler_Lua_callInstruction(v2.id,v2.args) + ")";
};
base_transpiler_Instructions.instr_bshr = function(v1,v2) {
	return "bit.rshift(" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + ", " + base_transpiler_Lua_callInstruction(v2.id,v2.args) + ")";
};
base_transpiler_Instructions.instr_bshl = function(v1,v2) {
	return "bit.lshift(" + base_transpiler_Lua_callInstruction(v1.id,v1.args) + ", " + base_transpiler_Lua_callInstruction(v2.id,v2.args) + ")";
};
function base_transpiler_Lua_callInstruction(id,args) {
	var name = "instr_" + $hxEnums[id.__enum__].__constructs__[id._hx_index]._hx_name.toLowerCase();
	if(!Object.prototype.hasOwnProperty.call(base_transpiler_Instructions,name)) {
		throw new haxe_exceptions_NotImplementedException("Unknown instruction: " + name,null,{ fileName : "src/base/transpiler/Lua.hx", lineNumber : 299, className : "base.transpiler._Lua.Lua_Fields_", methodName : "callInstruction"});
	}
	return Reflect.field(base_transpiler_Instructions,name).apply(base_transpiler_Instructions,args);
}
var haxe_Exception = function(message,previous,native) {
	Error.call(this,message);
	this.message = message;
	this.__previousException = previous;
	this.__nativeException = native != null ? native : this;
};
haxe_Exception.__name__ = true;
haxe_Exception.thrown = function(value) {
	if(((value) instanceof haxe_Exception)) {
		return value.get_native();
	} else if(((value) instanceof Error)) {
		return value;
	} else {
		var e = new haxe_ValueException(value);
		return e;
	}
};
haxe_Exception.__super__ = Error;
haxe_Exception.prototype = $extend(Error.prototype,{
	toString: function() {
		return this.get_message();
	}
	,get_message: function() {
		return this.message;
	}
	,get_native: function() {
		return this.__nativeException;
	}
});
var haxe_ValueException = function(value,previous,native) {
	haxe_Exception.call(this,String(value),previous,native);
	this.value = value;
};
haxe_ValueException.__name__ = true;
haxe_ValueException.__super__ = haxe_Exception;
haxe_ValueException.prototype = $extend(haxe_Exception.prototype,{
});
var haxe_ds_ObjectMap = function() {
	this.h = { __keys__ : { }};
};
haxe_ds_ObjectMap.__name__ = true;
haxe_ds_ObjectMap.prototype = {
	set: function(key,value) {
		var id = key.__id__;
		if(id == null) {
			id = (key.__id__ = $global.$haxeUID++);
		}
		this.h[id] = value;
		this.h.__keys__[id] = key;
	}
	,get: function(key) {
		return this.h[key.__id__];
	}
	,keys: function() {
		var a = [];
		for( var key in this.h.__keys__ ) {
		if(this.h.hasOwnProperty(key)) {
			a.push(this.h.__keys__[key]);
		}
		}
		return new haxe_iterators_ArrayIterator(a);
	}
};
var haxe_ds_StringMap = function() {
	this.h = Object.create(null);
};
haxe_ds_StringMap.__name__ = true;
haxe_ds_StringMap.prototype = {
	get: function(key) {
		return this.h[key];
	}
	,keys: function() {
		return new haxe_ds__$StringMap_StringMapKeyIterator(this.h);
	}
};
var haxe_ds__$StringMap_StringMapKeyIterator = function(h) {
	this.h = h;
	this.keys = Object.keys(h);
	this.length = this.keys.length;
	this.current = 0;
};
haxe_ds__$StringMap_StringMapKeyIterator.__name__ = true;
haxe_ds__$StringMap_StringMapKeyIterator.prototype = {
	hasNext: function() {
		return this.current < this.length;
	}
	,next: function() {
		return this.keys[this.current++];
	}
};
var haxe_exceptions_PosException = function(message,previous,pos) {
	haxe_Exception.call(this,message,previous);
	if(pos == null) {
		this.posInfos = { fileName : "(unknown)", lineNumber : 0, className : "(unknown)", methodName : "(unknown)"};
	} else {
		this.posInfos = pos;
	}
};
haxe_exceptions_PosException.__name__ = true;
haxe_exceptions_PosException.__super__ = haxe_Exception;
haxe_exceptions_PosException.prototype = $extend(haxe_Exception.prototype,{
	toString: function() {
		return "" + haxe_Exception.prototype.toString.call(this) + " in " + this.posInfos.className + "." + this.posInfos.methodName + " at " + this.posInfos.fileName + ":" + this.posInfos.lineNumber;
	}
});
var haxe_exceptions_NotImplementedException = function(message,previous,pos) {
	if(message == null) {
		message = "Not implemented";
	}
	haxe_exceptions_PosException.call(this,message,previous,pos);
};
haxe_exceptions_NotImplementedException.__name__ = true;
haxe_exceptions_NotImplementedException.__super__ = haxe_exceptions_PosException;
haxe_exceptions_NotImplementedException.prototype = $extend(haxe_exceptions_PosException.prototype,{
});
var haxe_iterators_ArrayIterator = function(array) {
	this.current = 0;
	this.array = array;
};
haxe_iterators_ArrayIterator.__name__ = true;
haxe_iterators_ArrayIterator.prototype = {
	hasNext: function() {
		return this.current < this.array.length;
	}
	,next: function() {
		return this.array[this.current++];
	}
};
var js_Boot = function() { };
js_Boot.__name__ = true;
js_Boot.__string_rec = function(o,s) {
	if(o == null) {
		return "null";
	}
	if(s.length >= 5) {
		return "<...>";
	}
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) {
		t = "object";
	}
	switch(t) {
	case "function":
		return "<function>";
	case "object":
		if(o.__enum__) {
			var e = $hxEnums[o.__enum__];
			var con = e.__constructs__[o._hx_index];
			var n = con._hx_name;
			if(con.__params__) {
				s = s + "\t";
				return n + "(" + ((function($this) {
					var $r;
					var _g = [];
					{
						var _g1 = 0;
						var _g2 = con.__params__;
						while(true) {
							if(!(_g1 < _g2.length)) {
								break;
							}
							var p = _g2[_g1];
							_g1 = _g1 + 1;
							_g.push(js_Boot.__string_rec(o[p],s));
						}
					}
					$r = _g;
					return $r;
				}(this))).join(",") + ")";
			} else {
				return n;
			}
		}
		if(((o) instanceof Array)) {
			var str = "[";
			s += "\t";
			var _g = 0;
			var _g1 = o.length;
			while(_g < _g1) {
				var i = _g++;
				str += (i > 0 ? "," : "") + js_Boot.__string_rec(o[i],s);
			}
			str += "]";
			return str;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( _g ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString && typeof(tostr) == "function") {
			var s2 = o.toString();
			if(s2 != "[object Object]") {
				return s2;
			}
		}
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		var k = null;
		for( k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) {
			str += ", \n";
		}
		str += s + k + " : " + js_Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "string":
		return o;
	default:
		return String(o);
	}
};
var hx_strings_Strings = function() { };
hx_strings_Strings.__name__ = true;
hx_strings_Strings.countMatches = function(searchIn,searchFor,startAt) {
	if(startAt == null) {
		startAt = 0;
	}
	if(searchIn == null || searchIn.length == 0 || (searchFor == null || searchFor.length == 0) || startAt >= searchIn.length) {
		return 0;
	}
	if(startAt < 0) {
		startAt = 0;
	}
	var count = 0;
	var foundAt = startAt > -1 ? startAt - 1 : 0;
	while(true) {
		foundAt = searchIn.indexOf(searchFor,foundAt + 1);
		if(!(foundAt > -1)) {
			break;
		}
		++count;
	}
	return count;
};
hx_strings_Strings.isLowerCase = function(str) {
	if(str == null || str.length == 0) {
		return false;
	}
	return str == hx_strings_Strings.toLowerCase8(str);
};
hx_strings_Strings.repeat = function(str,count,separator) {
	if(separator == null) {
		separator = "";
	}
	if(str == null) {
		return null;
	}
	if(count < 1) {
		return "";
	}
	if(count == 1) {
		return str;
	}
	var _g = [];
	var _g1 = 0;
	var _g2 = count;
	while(_g1 < _g2) {
		var i = _g1++;
		_g.push(str);
	}
	return _g.join(separator);
};
hx_strings_Strings.replaceAll = function(searchIn,searchFor,replaceWith) {
	if(searchIn == null || (searchIn == null || searchIn.length == 0) || searchFor == null) {
		return searchIn;
	}
	if(replaceWith == null) {
		replaceWith = "null";
	}
	return StringTools.replace(searchIn,searchFor,replaceWith);
};
hx_strings_Strings.toLowerCase8 = function(str) {
	if(str == null || str.length == 0) {
		return str;
	}
	return str.toLowerCase();
};
var lib_ParseError = function(message,previous,native) {
	haxe_Exception.call(this,message,previous,native);
};
lib_ParseError.__name__ = true;
lib_ParseError.__super__ = haxe_Exception;
lib_ParseError.prototype = $extend(haxe_Exception.prototype,{
});
var lib_Instr = $hxEnums["lib.Instr"] = { __ename__:true,__constructs__:null
	,Root: {_hx_name:"Root",_hx_index:0,__enum__:"lib.Instr",toString:$estr}
	,Break: {_hx_name:"Break",_hx_index:1,__enum__:"lib.Instr",toString:$estr}
	,Continue: {_hx_name:"Continue",_hx_index:2,__enum__:"lib.Instr",toString:$estr}
	,For: {_hx_name:"For",_hx_index:3,__enum__:"lib.Instr",toString:$estr}
	,While: {_hx_name:"While",_hx_index:4,__enum__:"lib.Instr",toString:$estr}
	,If: {_hx_name:"If",_hx_index:5,__enum__:"lib.Instr",toString:$estr}
	,TernaryDefault: {_hx_name:"TernaryDefault",_hx_index:6,__enum__:"lib.Instr",toString:$estr}
	,Ternary: {_hx_name:"Ternary",_hx_index:7,__enum__:"lib.Instr",toString:$estr}
	,Call: {_hx_name:"Call",_hx_index:8,__enum__:"lib.Instr",toString:$estr}
	,Stringcall: {_hx_name:"Stringcall",_hx_index:9,__enum__:"lib.Instr",toString:$estr}
	,Methodcall: {_hx_name:"Methodcall",_hx_index:10,__enum__:"lib.Instr",toString:$estr}
	,Assign: {_hx_name:"Assign",_hx_index:11,__enum__:"lib.Instr",toString:$estr}
	,LAssign: {_hx_name:"LAssign",_hx_index:12,__enum__:"lib.Instr",toString:$estr}
	,IndexGet: {_hx_name:"IndexGet",_hx_index:13,__enum__:"lib.Instr",toString:$estr}
	,IndexSet: {_hx_name:"IndexSet",_hx_index:14,__enum__:"lib.Instr",toString:$estr}
	,Add: {_hx_name:"Add",_hx_index:15,__enum__:"lib.Instr",toString:$estr}
	,Sub: {_hx_name:"Sub",_hx_index:16,__enum__:"lib.Instr",toString:$estr}
	,Mul: {_hx_name:"Mul",_hx_index:17,__enum__:"lib.Instr",toString:$estr}
	,Div: {_hx_name:"Div",_hx_index:18,__enum__:"lib.Instr",toString:$estr}
	,Mod: {_hx_name:"Mod",_hx_index:19,__enum__:"lib.Instr",toString:$estr}
	,Exp: {_hx_name:"Exp",_hx_index:20,__enum__:"lib.Instr",toString:$estr}
	,Equal: {_hx_name:"Equal",_hx_index:21,__enum__:"lib.Instr",toString:$estr}
	,NotEqual: {_hx_name:"NotEqual",_hx_index:22,__enum__:"lib.Instr",toString:$estr}
	,GreaterThanEq: {_hx_name:"GreaterThanEq",_hx_index:23,__enum__:"lib.Instr",toString:$estr}
	,LessThanEq: {_hx_name:"LessThanEq",_hx_index:24,__enum__:"lib.Instr",toString:$estr}
	,GreaterThan: {_hx_name:"GreaterThan",_hx_index:25,__enum__:"lib.Instr",toString:$estr}
	,LessThan: {_hx_name:"LessThan",_hx_index:26,__enum__:"lib.Instr",toString:$estr}
	,BAnd: {_hx_name:"BAnd",_hx_index:27,__enum__:"lib.Instr",toString:$estr}
	,Bor: {_hx_name:"Bor",_hx_index:28,__enum__:"lib.Instr",toString:$estr}
	,BXor: {_hx_name:"BXor",_hx_index:29,__enum__:"lib.Instr",toString:$estr}
	,BShl: {_hx_name:"BShl",_hx_index:30,__enum__:"lib.Instr",toString:$estr}
	,BShr: {_hx_name:"BShr",_hx_index:31,__enum__:"lib.Instr",toString:$estr}
	,Increment: {_hx_name:"Increment",_hx_index:32,__enum__:"lib.Instr",toString:$estr}
	,Decrement: {_hx_name:"Decrement",_hx_index:33,__enum__:"lib.Instr",toString:$estr}
	,Negative: {_hx_name:"Negative",_hx_index:34,__enum__:"lib.Instr",toString:$estr}
	,Not: {_hx_name:"Not",_hx_index:35,__enum__:"lib.Instr",toString:$estr}
	,And: {_hx_name:"And",_hx_index:36,__enum__:"lib.Instr",toString:$estr}
	,Or: {_hx_name:"Or",_hx_index:37,__enum__:"lib.Instr",toString:$estr}
	,Triggered: {_hx_name:"Triggered",_hx_index:38,__enum__:"lib.Instr",toString:$estr}
	,Delta: {_hx_name:"Delta",_hx_index:39,__enum__:"lib.Instr",toString:$estr}
	,Connected: {_hx_name:"Connected",_hx_index:40,__enum__:"lib.Instr",toString:$estr}
	,Literal: {_hx_name:"Literal",_hx_index:41,__enum__:"lib.Instr",toString:$estr}
	,Var: {_hx_name:"Var",_hx_index:42,__enum__:"lib.Instr",toString:$estr}
	,Foreach: {_hx_name:"Foreach",_hx_index:43,__enum__:"lib.Instr",toString:$estr}
	,Function: {_hx_name:"Function",_hx_index:44,__enum__:"lib.Instr",toString:$estr}
	,Return: {_hx_name:"Return",_hx_index:45,__enum__:"lib.Instr",toString:$estr}
	,KVTable: {_hx_name:"KVTable",_hx_index:46,__enum__:"lib.Instr",toString:$estr}
	,KVArray: {_hx_name:"KVArray",_hx_index:47,__enum__:"lib.Instr",toString:$estr}
	,Switch: {_hx_name:"Switch",_hx_index:48,__enum__:"lib.Instr",toString:$estr}
	,Include: {_hx_name:"Include",_hx_index:49,__enum__:"lib.Instr",toString:$estr}
	,Try: {_hx_name:"Try",_hx_index:50,__enum__:"lib.Instr",toString:$estr}
	,GroupedEquation: {_hx_name:"GroupedEquation",_hx_index:51,__enum__:"lib.Instr",toString:$estr}
};
lib_Instr.__constructs__ = [lib_Instr.Root,lib_Instr.Break,lib_Instr.Continue,lib_Instr.For,lib_Instr.While,lib_Instr.If,lib_Instr.TernaryDefault,lib_Instr.Ternary,lib_Instr.Call,lib_Instr.Stringcall,lib_Instr.Methodcall,lib_Instr.Assign,lib_Instr.LAssign,lib_Instr.IndexGet,lib_Instr.IndexSet,lib_Instr.Add,lib_Instr.Sub,lib_Instr.Mul,lib_Instr.Div,lib_Instr.Mod,lib_Instr.Exp,lib_Instr.Equal,lib_Instr.NotEqual,lib_Instr.GreaterThanEq,lib_Instr.LessThanEq,lib_Instr.GreaterThan,lib_Instr.LessThan,lib_Instr.BAnd,lib_Instr.Bor,lib_Instr.BXor,lib_Instr.BShl,lib_Instr.BShr,lib_Instr.Increment,lib_Instr.Decrement,lib_Instr.Negative,lib_Instr.Not,lib_Instr.And,lib_Instr.Or,lib_Instr.Triggered,lib_Instr.Delta,lib_Instr.Connected,lib_Instr.Literal,lib_Instr.Var,lib_Instr.Foreach,lib_Instr.Function,lib_Instr.Return,lib_Instr.KVTable,lib_Instr.KVArray,lib_Instr.Switch,lib_Instr.Include,lib_Instr.Try,lib_Instr.GroupedEquation];
var lib_E2Value = $hxEnums["lib.E2Value"] = { __ename__:true,__constructs__:null
	,Void: {_hx_name:"Void",_hx_index:0,__enum__:"lib.E2Value",toString:$estr}
	,Number: ($_=function(val) { return {_hx_index:1,val:val,__enum__:"lib.E2Value",toString:$estr}; },$_._hx_name="Number",$_.__params__ = ["val"],$_)
	,String: ($_=function(val) { return {_hx_index:2,val:val,__enum__:"lib.E2Value",toString:$estr}; },$_._hx_name="String",$_.__params__ = ["val"],$_)
};
lib_E2Value.__constructs__ = [lib_E2Value.Void,lib_E2Value.Number,lib_E2Value.String];
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $global.$haxeUID++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = m.bind(o); o.hx__closures__[m.__id__] = f; } return f; }
$global.$haxeUID |= 0;
if(typeof(performance) != "undefined" ? typeof(performance.now) == "function" : false) {
	HxOverrides.now = performance.now.bind(performance);
}
String.__name__ = true;
Array.__name__ = true;
haxe_ds_ObjectMap.count = 0;
js_Boot.__toStr = ({ }).toString;
var Main_CODE = "@name ExpressionScript Test\r\nGlobalVar = 400\r\n\r\n#[\r\n\tLorem ipsum dolor sit amet, consectetur adipiscing elit.\r\n\tNam euismod, tortor sed cursus placerat, massa nunc lobortis turpis,\r\n\tut vehicula ante nunc eget eros.\r\n]#\r\n\r\nprint(_AAAAAAAAAAA)\r\n\r\nwhile(1) {\r\n\tprint(\"while true do end\")\r\n}\r\n\r\n\"helloworld\"()\r\n\r\nif(1) {\r\n\tprint(\"hi\")\r\n} elseif(2) {\r\n\tprint(\"no\")\r\n} elseif(3) {\r\n\tprint(\"bye\")\r\n} else {\r\n\tprint(\"else\")\r\n}\r\n\r\nVar = 500\r\nswitch (Var) {\r\n\tcase 500,\r\n\t\tprint(\"this will happen\")\r\n\tbreak\r\n\r\n\tdefault,\r\n\t\tprint(\"this won't\")\r\n\tbreak\r\n}\r\n\r\ntry {\r\n\terror(\"Hello world\")\r\n} catch(Err) {\r\n\tprint(Err)\r\n}\r\n\r\nT = table()\r\nT[1, vector] = vec()\r\n\r\nprint( T[1, vector] )\r\n\r\nlocal Tbl = table(\r\n    \"width\" = Width,\r\n    \"height\" = Height,\r\n    \"done\" = 0,\r\n    \"output\" = table(),\r\n    \"png\" = 1,\r\n    \"type\" = Type,\r\n\r\n    \"crc\" = 0,\r\n    \"adler\" = 1\r\n)";
var base_transpiler_Lua_IN_SWITCH = false;
var lib_Std_types = (function($this) {
	var $r;
	var _g = new haxe_ds_StringMap();
	_g.h["number"] = { id : "number"};
	_g.h["string"] = { id : "string"};
	_g.h["table"] = { id : "table"};
	_g.h["array"] = { id : "array"};
	_g.h["vector"] = { id : "vector"};
	_g.h["entity"] = { id : "entity"};
	_g.h["vector2"] = { id : "vector2"};
	_g.h["vector4"] = { id : "vector4"};
	$r = _g;
	return $r;
}(this));
Main_main();
})(typeof window != "undefined" ? window : typeof global != "undefined" ? global : typeof self != "undefined" ? self : this);
