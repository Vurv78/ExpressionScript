package base.transpiler;

import haxe.ds.Vector;
import haxe.Int32;
import sys.io.File;
import lib.Type.E2Type;
import haxe.exceptions.NotImplementedException;
import base.Parser.Instruction;

using hx.strings.Strings;
using Safety;

final INSTRUCTIONS = Reflect.fields( haxe.rtti.Meta.getStatics(Instructions) );
var IN_SWITCH: Bool = false;

@:keep
class Instructions {
	static function instr_root(instrs: Array<Instruction>) {
		var out = [];
		for (instr in instrs)
			out.push( callInstruction(instr.name, instr.args) );
		return out.join('\n\n').replaceAll("\t\n", '');
	}

	static function instr_call(name: String, kvargs: Map<Dynamic, Instruction>, iargs: Array<Instruction>) {
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

	static function instr_literal(value: E2Type, raw: String)
		return raw;

	static function instr_if(cond: Instruction, block: Instruction, is_elseif: Bool, ifeif: Instruction) {
		if (is_elseif) {
			return 'is_elseif';
		}

		if( ifeif == null ) {
			return 'ifeif is null; $block $cond';
		}

		if ( block == null ) {
			return 'block is null';
		}

		return 'if ${ callInline(cond) } then\n' +
			'\t${ callBlock(block, true) }\n' +
		'end';

		/*return 'if ${ callInline(cond) } then\n' +
			'\t$block\n' +
			'\t${ callBlock(ifeif, true) }\n' +
		(is_elseif ? '<iselseif>' : 'end');*/

		/*return build +
			'\t${ callBlock(block, true) }\n' +
		'end [${ ifeif != null ? callBlock(ifeif, false) : "" }]';*/
	}

	static function instr_for(varname: String, start: Instruction, end: Instruction, ?inc: Instruction, block: Instruction) {
		final startv = callInline(start);
		final endv = callInline(end);

		final incby = inc==null ? '1' : callInline(inc);

		return 'for $varname = $startv, $endv, $incby do\n'
			+ '\t${ callBlock(block, true) }\n'
			+ '\t::continue::\n'
		+ 'end';
	}

	static function instr_foreach(keyname: String, ?keytype: String, valname: String, valtype: String, tblexpr: Instruction, block: Instruction) {
		return 'for $keyname, $valname in pairs(${ callInline(tblexpr) }) do\n' +
			'\t${callBlock(block, true)}\n' +
			'\t::continue::\n' +
		'end';
	}

	static function instr_while(cond: Instruction, block: Instruction, is_dowhile: Bool) {
		if (is_dowhile) {
			// Not using a repeat until
			return 'while true do\n' +
				'\t${ callBlock(block, true) }' +
				'\tif not cond then break end\n' +
			'end';
		}

		return 'while ${ callInline(cond) } do\n' +
			'\t${ callBlock(block, true) }\n' +
			'\t::continue::\n' +
		'end';
	}

	static function instr_variable(name: String)
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
		return 'goto continue';

	static function instr_return(val: Instruction)
		return 'return ${ callInline(val) }';

	static function instr_increment(varname: String)
		return '$varname = $varname + 1';

	static function instr_decrement(varname: String)
		return '$varname = $varname - 1';

	static function instr_add(v: Instruction, addend: Instruction)
		return '${ callInline(v) } + ${ callInline(addend) }';

	static function instr_sub(v: Instruction, addend: Instruction)
		return '${ callInline(v) } - ${ callInline(addend) }';

	static function instr_div(v: Instruction, addend: Instruction)
		return '${ callInline(v) } / ${ callInline(addend) }';

	static function instr_mul(v: Instruction, addend: Instruction)
		return '${ callInline(v) } * ${ callInline(addend) }';

	static function instr_eq(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } == ${ callInline(v2) }';

	static function instr_neq(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } ~= ${ callInline(v2) }';

	static function instr_leq(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } <= ${ callInline(v2) }';

	static function instr_geq(v1: Instruction, v2: Instruction)
		return '${ callInline(v1) } >= ${ callInline(v2) }';

	static function instr_grouped_equation(v1: Instruction)
		return '(${ callInline(v1) })';

	static function instr_assign(varname: String, to: Instruction)
		return '$varname = ${ callInline(to) }';

	static function instr_assignlocal(varname: String, to: Instruction)
		return 'local $varname = ${ callInline(to) }';

	static function instr_fndecl(name: String, ret_type: String, meta_type: String, sig: String, args: Array<{name: String, type: String}>, decl: Instruction) {
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

	// Bitwise ops
	static function instr_bor(v1: Instruction, v2: Instruction) {
		#if LUA54
			return '${ callInline(v1) } | ${ callInline(v2) }';
		#else
			return 'bit.bor(${ callInline(v1) }, ${ callInline(v2) })';
		#end
	}
}

// Expr -> Lua
function callInstruction(name: String, args: Array<Dynamic>): String {
	var name = 'instr_' + name;

	if(!Reflect.hasField(Instructions, name))
		throw new NotImplementedException('Instruction ["$name"] does not exist.');

	return Reflect.callMethod(Instructions, Reflect.field(Instructions, name), args);
}

inline function callInline(instr: Instruction) {
	return callInstruction(instr.name, instr.args);
}

inline function callBlock(instr: Instruction, indent: Bool) {
	var out = callInstruction(instr.name, [instr.args]);
	if (indent) return out.replaceAll('\n', "\n\t");
	return out;
}

inline function process(toks: Instruction): String {
	return callBlock(toks, false);
}