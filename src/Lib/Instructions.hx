package lib;

import lib.Error.Trace;

typedef Instruction = {
	id: Instr,
	trace: Trace,
	args: InstructionArgs // Arguments to be passed to the compiler.
}

typedef SwitchCases = Array<{?match: Instruction, block: Instruction}>;

// To avoid Dynamic, make an enum of all possible instruction arguments to pass.
// This is since we use reflection instead of properly calling each function.
enum InstructionArg {
	ValueBool(i: Bool);
	ValueString(i: String);

	SwitchCases(i: SwitchCases);

	ArrInstruction(i: Array<Instruction>);
	Instruction(i: Instruction);
}

typedef InstructionArgs = Array<Dynamic>; // Temporary.
//typedef InstructionArgs = Array<InstructionArg>;

@:enum
enum Instr {
	Root; // "root" --- seq
	Break; // "break"
	Continue; // "continue"
	For; // "for"
	While; // "while"
	If; // "if"
	TernaryDefault; // ?:
	Ternary; // "ternary"
	Call; // "call"
	Stringcall; // "stringcall"
	Methodcall; // "methodcall"
	Assign; // "assign"
	LAssign; // "lassign"
	IndexGet; // "index_get"
	IndexSet; // "index_set"

	Add; // "add"
	Sub; // "sub"
	Mul; // "mul"
	Div; // "div"
	Mod; // "mod"
	Exp; // "exp"
	Equal; // "equals"
	NotEqual; // "nequals"
	GreaterThanEq; // "geq"
	LessThanEq; // "leq"
	GreaterThan; // "gt"
	LessThan; // "lt"

	BAnd; // "band"
	Bor; // "bor"
	BXor; // "bxor"
	BShl; // "bshl"
	BShr; // "bshr"

	Increment; // "increment"
	Decrement; // "decrement"
	Negative; // "negative"
	Not; // "not"
	And; // "and"
	Or; // "or"

	Triggered; // "triggered" // (~) Kept for backwards compat.
	Delta; // "delta" // $
	Connected; // "connected" // (->) Kept for backwards compat.
	Literal; // "literal"
	Var; // "var" // Variable reference
	Foreach; // "foreach"
	Function; // "function"
	Return; // "return"
	KVTable; // "kvtable"
	KVArray; // "kvarray"
	Switch; // "switch"
	Include; // "include"
	Try; // "try"
	GroupedEquation; // "grouped_equation"
}