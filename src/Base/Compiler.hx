package base;

import haxe.exceptions.NotImplementedException;
import lib.Type.E2Value;
using lib.Instructions;

using Iterators;
using Safety;

/*
typedef Scope = Map<String, String>;
typedef ScopeSave = { scopes: Any, id: Int, current: Scope };

typedef E2Context = Any;
typedef E2Function = { runtime: haxe.Constraints.Function, ret: E2Value, signature: String, returns: E2Value };

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

	public function process(root: Instruction) {
		Compiler.callInstruction(root.id, root.args);
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

	public static function callInstruction(id: Instr, args: Array<Any>):Any {
		throw new NotImplementedException("Not implemented.");
	}

	function evaluateStatement(instr: Instruction, index: Int) {
		var br = instr.args[index];
		return Compiler.callInstruction(instr.id, instr.args);
	}

	function evaluate(args: Instruction, index: Int) {
		var ex = evaluateStatement(args, index);
	}
}
*/