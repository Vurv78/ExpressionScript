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
	static function root(instrs: Array<Instruction>) {
		var out = [];
		for (instr in instrs)
			out.push( callInstruction(instr.name, instr.args) );
		return out.join('\n');
	}

	static function call(name: String, kvargs: Map<Dynamic, Instruction>, iargs: Array<Instruction>) {
		var args = [];
		if (iargs != null) {
			// Function was called with arguments
			var args = iargs.map( (x) -> { callInline(x); } );

			return '$name(${ args.join(", ") })';
		}
		// TODO: Kvargs (table())

		return '$name()';
	}

	static function methodcall(fname: String, instr: Instruction)
		return 'methodcall, idk';

	static function literal(value: E2Type, raw: String)
		return raw;

	static function _if(cond: Instruction, block: Instruction, is_elseif: Bool, ifeif: Instruction) {
		if (is_elseif) {
			return 'is_elseif';
		}

		if( ifeif == null ) {
			return 'ifeif is null; $block $cond';
		}

		if ( block == null ) {
			return 'block is null';
		}

		return '-- IfElse/Else is currently broken. \n'+
				'if ${ callInline(cond) } then\n' +
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

	static function _for(varname: String, start: Instruction, end: Instruction, ?inc: Instruction, block: Instruction) {
		final startv = callInline(start);
		final endv = callInline(end);

		final incby = inc==null ? '1' : callInline(inc);

		return 'for $varname = $startv, $endv, $incby do\n'
			+ '\t${ callBlock(block, true) }\n'
			+ '\t::continue::\n'
		+ 'end';
	}

	static function foreach(keyname: String, ?keytype: String, valname: String, valtype: String, tblexpr: Instruction, block: Instruction) {
		return 'for $keyname, $valname in pairs(${ callInline(tblexpr) }) do\n' +
			'\t${callBlock(block, true)}\n' +
			'\t::continue::\n' +
		'end';
	}

	static function _while(cond: Instruction, block: Instruction) {
		IN_SWITCH = false;
		var buf = new StringBuf();
		buf.add( 'while ${ callInline(cond) } do\n' );
			buf.add( '\t${callBlock(block, true)}\n' );
			buf.add( '\t::continue::\n' );
		buf.add( 'end' );
		return buf.toString();
	}

	static function variable(name: String)
		return name;

	static function _switch(topexpr: Instruction, cases: Array<{?match: Instruction, block: Instruction}>) {
		IN_SWITCH = true;
		var topvar = callInline(topexpr);

		var out = "-- Switch case --\n" +
			'local swc = $topvar\n';

		for (key => c in cases) {
			if (c.match != null) {
				var match = callInline(c.match);
				out += ('${key == 0 ? '' : 'else'}if swc == $match then\n' +
					'\t${ callBlock(c.block, true) }\n');
			} else {
				out += ('else\n' +
				'\t${ callBlock(c.block, true) }\n');
				break;
			}
		}
		out += 'end';
		IN_SWITCH = false;
		return out;
	}

	static function _break()
		return IN_SWITCH ? '' : "break";

	static function _continue()
		return 'goto continue';

	static function _return(val: Instruction)
		return 'return ${ callInline(val) }';

	static function increment(varname: String)
		return '$varname = $varname + 1';

	static function decrement(varname: String)
		return '$varname = $varname - 1';

	static function add(v: Instruction, addend: Instruction)
		return '(${ callInline(v) } + ${ callInline(addend) })';

	static function sub(v: Instruction, addend: Instruction)
		return '(${ callInline(v) } - ${ callInline(addend) })';

	static function div(v: Instruction, addend: Instruction)
		return '(${ callInline(v) } / ${ callInline(addend) })';

	static function mul(v: Instruction, addend: Instruction)
		return '(${ callInline(v) } * ${ callInline(addend) })';

	static function assign(varname: String, to: Instruction)
		return '$varname = ${ callInline(to) }';

	static function eq(v1: Instruction, v2: Instruction)
		return '(${ callInline(v1) } == ${ callInline(v2) })';

	static function neq(v1: Instruction, v2: Instruction)
		return '(${ callInline(v1) } ~= ${ callInline(v2) })';

	static function assignlocal(varname: String, to: Instruction)
		return 'local $varname = ${ callInline(to) }';

	static function function_decl(name: String, ret_type: String, type: String, sig: String, args: Array<{name: String, type: String}>, decl: Instruction) {
		return 'function $name(${ args.map( (v) -> v.name ).join(", ") })\n' +
			'\t${ callBlock(decl, true) }\n' +
		'end';
	}
}

// Expr -> Lua
function callInstruction(name: String, args: Array<Dynamic>): String {
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