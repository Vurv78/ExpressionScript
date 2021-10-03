package base;

import haxe.exceptions.NotImplementedException;
import lib.Type.E2Type;
using lib.Instructions;

using Iterators;
using Safety;

typedef Scope = Map<String, String>;
typedef ScopeSave = { scopes: Dynamic, id: Int, current: Scope };

typedef E2Context = Dynamic;
typedef E2Function = { runtime: haxe.Constraints.Function, ret: E2Type, signature: String, returns: E2Type };

// seq, _break, _continue, forloop,

final INSTRUCTIONS = Reflect.fields( haxe.rtti.Meta.getStatics(Instructions) );

class Compiler {
	var scopes: Array<Scope>;
	var scope_id: Int;
	var global_scope: Null<Scope>;
	var current_scope: Scope;
	var context: E2Context;

	var funcs: Map<String, E2Function>;

	//var persist: TodoTable;

	public function new() {
		this.scopes = [ [] ];
		this.scope_id = 0;
		this.current_scope = scopes[0];
		this.global_scope = this.current_scope;
	}

	function error(msg: String, instr: Instruction)
		throw '$msg at line ${ instr.trace.line }, char ${ instr.trace.char }';

	/**
	 * Compiles a Parser result.
	 * @param root Parser result from Parser.hx
	 */
	public function process(root: Instruction) {
		Compiler.callInstruction(root.name, root.args);
	}

	function setLocalVariableType(name: String, type: String, instr: Instruction) {
		var typ = this.current_scope[name];
		if (typ != type)
			this.error('Variable ($name) of type [$typ] cannot be assigned value of type [$type]', instr);

		this.current_scope[name] = type;
		return this.scope_id;
	}

	function setGlobalVariableType(name: String, type: String, instr: Instruction) {
		for ( i in this.scope_id.to(0) ) {
			var typ = this.scopes[i][name];
			if (typ != type) {
				this.error('Variable ($name) of type [$typ] cannot be assigned value of type [$type]', instr);
			} else if (typ != null) {
				return i;
			}
		}

		this.global_scope[name] = type;
		return 0;
	}

	function getVariableType(name: String, instr: Instruction):Null<{ t: String, i: Int }> {
		for (i in this.scope_id.to(0)) {
			var type = this.scopes[i][name];
			if (type != null) {
				return {t: type, i: i}
			}
		}

		this.error('Variable ($name) does not exist', instr);
		return null;
	}

	public static function callInstruction(name: String, args: Array<Dynamic>):Dynamic {
		if(!Reflect.hasField(Instructions, name))
			throw new NotImplementedException('Instruction $name does not exist.');

		return Reflect.callMethod(Instructions, Reflect.field(Instructions, name), args);
	}

	function evaluateStatement(instr: Instruction, index: Int) {
		var br = instr.args[index];
		return Compiler.callInstruction(instr.name, instr.args);
	}

	function evaluate(args: Instruction, index: Int) {
		var ex = evaluateStatement(args, index);
	}
}


class Instructions {
	@:keep
	static function root(instr: Instruction) {
		Compiler.callInstruction(instr.name, instr.args);
	}

	@:keep
	static function brk(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _continue(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _for(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _while(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _if(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _default(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	// Ternary ?
	@:keep
	static function cnd(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function call(name: String, kvexprs: Map<Dynamic, Instruction>, args: Array<Instruction>) {
		return 69;
	}

	@:keep
	static function string_call(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function method_call(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function assign(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function assign_local(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function get(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function set(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	// Generic function for + - / % * ^ << && == etc
	@:keep
	static function basic_op(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function increment(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function decrement(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function negative(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function not(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function and(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function or(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function triggered(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function delta(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	/**
	 * IWC / -> Operator
	 */
	@:keep
	static function connected(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	// Why tf
	@:keep
	static function literal(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _var(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function foreach(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _function(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _return(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function kv_table(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function kv_array(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function _switch(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function include(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}

	@:keep
	static function trycatch(instr: Instruction) {
		Sys.println("Test!");
		return 69;
	}
}