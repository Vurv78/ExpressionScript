package base.transpiler;

import lib.Type.E2Value;
import haxe.exceptions.NotImplementedException;

using lib.Instructions;
using hx.strings.Strings;
using Safety;

var IN_SWITCH: Bool = false;

@:keep
class Instructions {
	static public function instr_root(instrs: Array<Instruction>) {
		var out = [ for(instr in instrs) callInstruction(instr.id, instr.args) ];
		return out.join('\n\n').replaceAll("\t\n", '');
	}

	static function instr_call(name: String, kvargs: Map<Instruction, Instruction>, iargs: Array<Instruction>) {
		var args = [];
		if (iargs != null) {
			// Function was called with arguments
			var args = iargs.map( (x) -> { callInline(x); } );

			return '$name(${ args.join(", ") })';
		}
		// TODO: Kvargs (table())

		return '$name()';
	}

	static function instr_methodcall(meta_fname: String, meta_obj: Instruction, iargs: Array<Instruction>)
		return '${ callInline(meta_obj) }:$meta_fname(${ (iargs!=null) ? iargs.map(x -> callInline(x)).join(", ") : '' })';

	static function instr_literal(value: E2Value, raw: String)
		return raw;

	static function instr_if(cond: Instruction, block: Instruction, ifeifs: Array<Instruction>, is_else: Bool) {
		if (ifeifs != null) {
			// Top If
			return 'if ${ callInline(cond) } then\n' +
				'\t${ callBlock(block, true) }\n' +
				ifeifs.map(x -> callInline(x)).join('') +
			"end";
		} else {
			if (is_else) {
				// Chain final else
				return 'else\n' +
					'\t${ callBlock(block,true) }\n';
			} else {
				return 'elseif ${ callInline(cond) } then\n' +
					'\t${ callBlock(block,true) }\n';
			}
		}
	}

	static function instr_for(varname: String, start: Instruction, end: Instruction, ?inc: Instruction, block: Instruction) {
		final startv = callInline(start);
		final endv = callInline(end);

		final incby = inc==null ? '1' : callInline(inc);

		return 'for $varname = $startv, $endv, $incby do\n'
			+ '\t${ callBlock(block, true) }\n'
			+ '\t::_continue_::\n'
		+ 'end';
	}

	static function instr_foreach(keyname: String, ?keytype: String, valname: String, valtype: String, tblexpr: Instruction, block: Instruction) {
		return 'for $keyname, $valname in pairs(${ callInline(tblexpr) }) do\n' +
			'\t${callBlock(block, true)}\n' +
			'\t::_continue_::\n' +
		'end';
	}

	static function instr_while(cond: Instruction, block: Instruction, is_dowhile: Bool) {
		if (is_dowhile) {
			// Not using a repeat until
			return 'while true do\n' +
				'\t${ callBlock(block, true) }\n' +
				'\tif not ${ callInline(cond) } then break end\n' +
				'\t::_continue_::\n' + // This might have to go on the line above.
			'end';
		}

		return 'while ${ callInline(cond) } do\n' +
			'\t${ callBlock(block, true) }\n' +
			'\t::_continue_::\n' +
		'end';
	}

	static function instr_var(name: String)
		return name;

	static function instr_switch(topexpr: Instruction, cases: Array<{?match: Instruction, block: Instruction}>) {
		IN_SWITCH = true;
		var topvar = callInline(topexpr);

		var out = 'local _switch_result = $topvar\n';
		for (key => c in cases) {
			if (c.match != null) {
				var match = callInline(c.match);
				out += ('${key == 0 ? '' : 'else'}if _switch_result == $match then\n' +
					'\t${ callBlock(c.block, true) }\n');
			} else {
				out += 'else\n' +
				'\t${ callBlock(c.block, true) }\n';
				break;
			}
		}
		out += 'end';
		IN_SWITCH = false;
		return out;
	}

	static function instr_break()
		return IN_SWITCH ? '' : "break";

	static function instr_continue()
		return 'goto _continue_';

	static function instr_return(val: Instruction)
		return 'return ${ callInline(val) }';

	static function instr_not(v: Instruction)
		return 'not ${ callInline(v) }';

	static function instr_and(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } and ${ callInline(v2) }';

	static function instr_or(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } or ${ callInline(v2) }';

	// Math ops

	static function instr_increment(varname: String)
		return '$varname = $varname + 1';

	static function instr_decrement(varname: String)
		return '$varname = $varname - 1';

	static function instr_negative(v: Instruction)
		return '-${ callInline(v) }';

	static function instr_mod(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } % ${ callInline(v2) }';

	static function instr_add(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } + ${ callInline(v2) }';

	static function instr_sub(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } - ${ callInline(v2) }';

	static function instr_div(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } / ${ callInline(v2) }';

	static function instr_mul(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } * ${ callInline(v2) }';

	static function instr_exp(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } ^ ${ callInline(v2) }';

	// Eq ops

	static function instr_equal(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } == ${ callInline(v2) }';

	static function instr_notequal(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } ~= ${ callInline(v2) }';

	static function instr_lessthaneq(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } <= ${ callInline(v2) }';

	static function instr_greaterthaneq(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } >= ${ callInline(v2) }';

	static function instr_greaterthan(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } > ${ callInline(v2) }';

	static function instr_lessthan(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } < ${ callInline(v2) }';

	static function instr_groupedequation(v1: Instruction)
		return '(${ callInline(v1) })';

	static function instr_assign(varname: String, to: Instruction)
		return '$varname = ${ callInline(to) }';

	static function instr_lassign(varname: String, to: Instruction)
		return 'local $varname = ${ callInline(to) }';

	static function instr_function(name: String, ret_type: String, meta_type: String, sig: String, args: Array<{name: String, type: String}>, decl: Instruction) {
		return 'function ${(meta_type != null) ? '${meta_type}_' : ''}$name(${ args.map( (v) -> v.name ).join(", ") })\n' +
			'\t${ callBlock(decl, true) }\n' +
		'end';
	}

	static function instr_ternary(cond: Instruction, success: Instruction, fallback: Instruction)
		return '${ callInline(cond) } and ${ callInline(success) } or ${ callInline(fallback) }';

	static function instr_try(block: Instruction, var_name: String, catch_block: Instruction) {
		return 'xpcall(function()\n' +
			'\t${ callBlock(block, true) }\n' +
		'end, function($var_name)\n' +
			'\t${ callBlock(catch_block, true) }\n' +
		'end)';
	}

	static function instr_stringcall(name:Instruction, args: Array<Instruction>, ret_type: Null<String>)
		return '_G[${ callInline(name) }](${ args.map( (x) -> callInline(x) ).join(", ") })';

	static function instr_indexget(tbl: Instruction, key: Instruction, type: Null<String>)
		return '${ callInline(tbl) }[${ callInline(key) }]';

	static function instr_indexset(tbl: Instruction, key: Instruction, value: Instruction, type: Null<String>)
		return '${ callInline(tbl) }[${ callInline(key) }] = ${ callInline(value) }';

	static function instr_kvtable(kvmap: Map<Instruction, Instruction>, imap: Array<Instruction>) {
		var kvargs = [ for (k => v in kvmap.keyValueIterator()) '[${ callInline(k) }] = ${ callInline(v) }' ];

		return '{\n' +
			'\t${ kvargs.join(",\n\t") }\n' +
			'\t${ imap.map( (x) -> callInline(x) ).join(",\n\t") }\n' +
		'}';
	}

	static function instr_kvarray(kvmap: Map<Instruction, Instruction>, imap: Array<Instruction>) {
		var kvargs = [ for (k => v in kvmap.keyValueIterator()) '[${ callInline(k) }] = ${ callInline(v) }' ];

		return '{\n' +
			'\t${ kvargs.join(",\n\t") }\n' +
			'\t${ imap.map( (x) -> callInline(x) ).join(",\n\t") }\n' +
		'}';
	}

	static function instr_ternarydefault(val: Instruction, els: Instruction)
		return '${ callInline(val) } or ${ callInline(els) }';

	static function instr_include()
		return "error('Not implemented in the parser.')";

	// TODO: there should be a system for these three
	static function instr_triggered(varname: String)
		return "false";

	static function instr_delta(varname: String)
		return "false";

	static function instr_connected(varname: String)
		return "false";

	// Bitwise ops
	static function instr_bor(v1: Instruction, v2: Instruction) {
		#if LUA54
			return '${ callInline(v1) } | ${ callInline(v2) }';
		#else
			return 'bit.bor(${ callInline(v1) }, ${ callInline(v2) })';
		#end
	}

	static function instr_band(v1: Instruction, v2: Instruction) {
		#if LUA54
			return '${ callInline(v1) } & ${ callInline(v2) }';
		#else
			return 'bit.band(${ callInline(v1) }, ${ callInline(v2) })';
		#end
	}

	static function instr_bxor(v1: Instruction, v2: Instruction) {
		#if LUA54
			return '${ callInline(v1) } ~ ${ callInline(v2) }';
		#else
			return 'bit.bxor(${ callInline(v1) }, ${ callInline(v2) })';
		#end
	}

	static function instr_bshr(v1: Instruction, v2: Instruction) {
		#if LUA54
			return '${ callInline(v1) } >> ${ callInline(v2) }';
		#else
			return 'bit.rshift(${ callInline(v1) }, ${ callInline(v2) })';
		#end
	}

	static function instr_bshl(v1: Instruction, v2: Instruction) {
		#if LUA54
			return '${ callInline(v1) } << ${ callInline(v2) }';
		#else
			return 'bit.lshift(${ callInline(v1) }, ${ callInline(v2) })';
		#end
	}
}

// Expr -> Lua
@:nullSafety(Strict)
function callInstruction(id: Instr, args: InstructionArgs): String {
	var name = 'instr_${Type.enumConstructor(id).toLowerCase()}';
	if (!Reflect.hasField(Instructions, name))
		throw new NotImplementedException('Unknown instruction: $name');

	return Reflect.callMethod(Instructions, Reflect.field(Instructions, name), args);
}

inline function callInline(instr: Instruction) {
	return callInstruction(instr.id, instr.args);
}

inline function callBlock(instr: Instruction, indent: Bool) {
	var out = callInstruction(instr.id, cast [instr.args]);
	if (indent) return out.replaceAll('\n', "\n\t");
	return out;
}

inline function process(toks: Instruction): String {
	return callBlock(toks, false);
}