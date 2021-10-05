package base;

import haxe.exceptions.NotImplementedException;
import lib.Type.E2Value;
using lib.Instructions;

using Iterators;
using Safety;
using hx.strings.Strings;
using lib.Std;

typedef ScopeID = UInt;
typedef Scope = Map<String, String>;
typedef ScopeSave = { scopes: Array<Scope>, id: ScopeID, scope: Scope };

typedef E2Context = Any;
typedef E2Function = { runtime: haxe.Constraints.Function, ret: E2Value, signature: String, returns: E2Value };

class ScopeManager {
	var scopes: Array<Scope>;
	var scope: Scope;
	public var scope_id: ScopeID;

	// scope[0] should always be the global scope.
	public inline function new() {
		this.reset();
	}

	function reset() {
		this.scope_id = 0;
		this.scopes = [ [] ];
		this.scope = this.scopes[0];
	}

	function push(?scope: Scope) {
		this.scope_id++;

		switch (scope) {
			case null: { this.scope = []; }
			case v: { this.scope = v; }
		}

		this.scopes[this.scope_id] = this.scope;
	}

	function pop() {
		this.scope_id--;
		this.scope = this.scopes[this.scope_id];
		return this.scopes[++this.scope_id];
	}

	public inline function save(): ScopeSave
		return { scopes: this.scopes, id: this.scope_id, scope: this.scope };

	function load(save: ScopeSave) {
		this.scopes = save.scopes;
		this.scope_id = save.id;
		this.scope = save.scope;
	}

	public inline function getType(name: String)
		return this.scope[name];

	public inline function setType(name: String, type: String)
		this.scope[name] = type;

	public inline function getScope(id: ScopeID)
		return this.scopes[id];

}

class Compiler {
	final context: E2Context;
	final funcs: Map<E2FunctionSig, E2Function>;
	final ops: Map<E2FunctionSig, E2Function>; // Operators

	// Scopes
	final scopes: ScopeManager;

	//var persist: TodoTable;

	public function new() {
		this.context = null;
		this.funcs = [];
		this.ops = [];
		this.scopes = new ScopeManager();
	}

	function error(msg: String, instr: Instruction)
		throw '$msg at line ${ instr.trace.line }, char ${ instr.trace.char }';

	public function process(root: Instruction) {
		Compiler.callInstruction(root.id, root.args);
	}

	function setLocalVariableType(name: String, type: String, instr: Instruction) {
		var typ = this.scopes.getType(name);
		if (typ != type)
			this.error('Variable ($name) of type [$typ] cannot be assigned value of type [$type]', instr);

		this.scopes.setType(name, type);
		return this.scopes.scope_id;
	}

	function setGlobalVariableType(name: String, type: String, instr: Instruction) {
		for ( i in this.scopes.scope_id.to(0) ) {
			var typ = this.scopes.getScope(i)[name];
			if (typ != type) {
				this.error('Variable ($name) of type [$typ] cannot be assigned value of type [$type]', instr);
			} else if (typ != null) {
				return i;
			}
		}

		this.scopes.getScope(0)[name] = type;
		return 0;
	}

	function getVariableType(name: String, instr: Instruction):Null<{ type: String, id: ScopeID }> {
		for (i in this.scopes.scope_id.to(0)) {
			var type = this.scopes.getScope(i)[name];
			if (type != null) {
				return {type: type, id: i}
			}
		}

		this.error('Variable ($name) does not exist', instr);
		return null;
	}

	function evaluateStatement(instr: Instruction, index: Int) {
		var br = instr.args[index];
		return callInstruction(instr.id, instr.args);
	}

	function evaluate(args: Instruction, index: Int) {
		var ex = evaluateStatement(args, index);
	}

	function has_operator() {

	}
}

class Instructions {}

@:nullSafety(Strict)
function callInstruction(id: Instr, args: InstructionArgs) {
	var name = 'instr_${Type.enumConstructor(id).toLowerCase()}';
	if (!Reflect.hasField(Instructions, name))
		throw new NotImplementedException('Unknown instruction: $name');

	return Reflect.callMethod(Instructions, Reflect.field(Instructions, name), args);
}

inline function process(toks: Instruction): String {
	return callInstruction(toks.id, toks.args);
}