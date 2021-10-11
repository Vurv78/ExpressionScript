package base;

// Fails to compile too lazy to fix my recent changes to the InstructionResult

import haxe.exceptions.NotImplementedException;
import lib.Type.E2Value;
using lib.Instructions;
using lib.Instructions.InstructionArgE;

using Iterators;
using Safety;
using hx.strings.Strings;
using lib.Std;
using lib.Error;

typedef ScopeID = UInt;
typedef Scope = Map<String, String>;
typedef ScopeSave = { scopes: Array<Scope>, id: ScopeID, scope: Scope };

typedef E2Context = {
	/*inputs: Array<Input>,
	outputs: Array<Output>,
	*/
	persist: Map<String, Bool>,
	//includes: Array<Include>,
	prf_counter: UInt,
	prf_counters: Array<UInt>,

	//delta_vars: Todo,
	function_returns: Map<E2FunctionSig, E2TypeDef>,
	functions: Map<E2FunctionSig, E2Function>,

};
typedef E2Function = {
	runtime: (self: Null<E2Value>, args: Array<E2Value>) -> E2Value, // TODO: Type this
	op_cost: UInt,
	ret: E2Value,
	signature: E2FunctionSig,
	returns: E2Value
};

typedef InstructionResult = {
	runtime: (instance: E2Context)->E2Value,
	?type: E2TypeSig
}

class ScopeManager {
	var scopes: Array<Scope>;
	var scope: Scope;
	public var scope_id: ScopeID;

	// scope[0] should always be the global scope.
	public inline function new() {
		this.scope_id = 0;
		this.scopes = [ [] ];
		this.scope = this.scopes[0];
	}

	public function reset() {
		this.scope_id = 0;
		this.scopes = [ [] ];
		this.scope = this.scopes[0];
	}

	public function push(?scope: Scope) {
		this.scope_id++;

		switch (scope) {
			case null: { this.scope = []; }
			case v: { this.scope = v; }
		}

		this.scopes[this.scope_id] = this.scope;
	}

	public function pop() {
		this.scope_id--;
		this.scope = this.scopes[this.scope_id];
		return this.scopes[++this.scope_id];
	}

	public inline function save(): ScopeSave
		return { scopes: this.scopes, id: this.scope_id, scope: this.scope };

	public function load(save: ScopeSave) {
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
	var trace: Trace;

	final instructions: Map<Instr, (instrs: InstructionArgs)->InstructionResult>;

	//var persist: TodoTable;

	public function new() {
		this.context = {
			persist: [],
			prf_counter: 0,
			prf_counters: [],
			function_returns: [],
			functions: []
		};

		this.funcs = [];
		this.ops = [];
		this.scopes = new ScopeManager();
		this.trace = { line: 1, char: 0 };

		this.instructions = [
			Root => (args) -> {
				return () -> {
					for(iarg in args) {
						var instr_maybe: Null<Instruction> = iarg.sure();
						instr_maybe.run( (i) -> {
							trace('Running ${ i.id }');
							callInstruction(i.id, i.args)();
						});
					}
				}
			},
			Break => (args)-> {
				return {
					rt: (self) -> {
						return Void;
					}
				}
			},
			Continue => (args)-> {
				return () -> {
					throw new RuntimeError("continue");
				}
			},
			For => (args)-> {
				final var_name: Null<String> = args[0].sure();
				final start_expr: Null<Instruction> = args[1].sure();
				final stop_expr: Null<Instruction> = args[2].sure();
				final step_expr: Null<Instruction> = args[3].sure();
				final body: Null<Instruction> = args[4].sure();

				return () -> {
					throw new NotImplementedException();
				};
			},
			While => (args)-> {
				final condition: Instruction = args[0].sure();
				final body: Instruction = args[1].sure();

				final is_dowhile: Bool = args[2].sure();

				this.scopes.push();

				final cond = this.callInstruction( condition.id, condition.args );
				final body = this.callInstruction( condition.id, condition.args );

				this.scopes.pop();

				return () -> {
					throw new NotImplementedException();
				};
			},
			If => (args) -> {
				final condition: Instruction = args[0].sure();
				final body: Instruction = args[1].sure();
				final ifeifs: Null<Array<Instruction>> = args[2].sure();
				final is_else: Bool = args[3].sure();

				this.scopes.push();
					final body_eval = this.evaluate(body);
				this.scopes.pop();

				// TODO..

				return () -> {
					throw new NotImplementedException();
				};
			},
			Ternary => (args) -> {
				final expr: Instruction = args[0].sure();
				final iff: Instruction = args[1].sure();
				final els: Instruction = args[2].sure();

				return () -> {
					throw new NotImplementedException();
				}
			},
			TernaryDefault => (args) -> {
				final iff: Instruction = args[0].sure();
				final els: Instruction = args[1].sure();

				return () -> {
					throw new NotImplementedException();
				}
			},
			Call => (args) -> {
				final exprs = [false];

			},
			Var => (args) -> {
				final var_name: String = args[0].sure();
				final data = this.getVariableType(var_name);

				return {
					rt: (self) -> {
					},
					type: data.type,
				}
			}
		];
	}

	function setLocalVariableType(name: String, type: String) {
		var typ = this.scopes.getType(name);
		if (typ != type)
			throw new CompileError('Variable ($name) of type [$typ] cannot be assigned value of type [$type]');

		this.scopes.setType(name, type);
		return this.scopes.scope_id;
	}

	function setGlobalVariableType(name: String, type: String) {
		for ( i in this.scopes.scope_id.to(0) ) {
			var typ = this.scopes.getScope(i)[name];
			if (typ != type) {
				throw new CompileError('Variable ($name) of type [$typ] cannot be assigned value of type [$type]');
			} else if (typ != null) {
				return i;
			}
		}

		this.scopes.getScope(0)[name] = type;
		return 0;
	}

	function getVariableType(name: String):Null<{ type: String, id: ScopeID }> {
		for (i in this.scopes.scope_id.to(0)) {
			var type = this.scopes.getScope(i)[name];
			if (type != null) {
				return {type: type, id: i}
			}
		}

		throw new CompileError('Variable ($name) does not exist');
	}

	function has_operator() {

	}

	public function process(root: Instruction) {
		this.scopes.push();

		var script;
		try {
			script = this.evaluate(root);
		} catch(err: CompileError) {
			final trace = err.trace;
			this.scopes.pop();

			if (trace != null) {
				throw new CompileError('${ err.message } at line ${ trace.line }, char ${ trace.char }', trace);
			}

			throw err;
		}

		this.scopes.pop();

		return script;
	}

	function callInstruction(id: Instr, args: InstructionArgs) {
		switch this.instructions.get(id) {
			case null: throw new CompileError('Unknown instruction: $id');
			case fn: return fn(args);
		}
	}

	function evaluate(expr: Instruction) {
		this.trace = expr.trace;
		return this.callInstruction(expr.id, expr.args);
	}
}