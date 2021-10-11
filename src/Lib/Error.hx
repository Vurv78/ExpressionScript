package lib;

class BaseError extends haxe.Exception {
	public final trace: Null<Trace>;
	public function new(msg: String, ?tok_override: Trace) {
		super(msg);
		this.trace = tok_override;
	}
}

class ParseError extends BaseError {}
class CompileError extends BaseError {}
class TranspileError extends BaseError {}


/// Parser
class SyntaxError extends ParseError {} // Bad syntax
class TypeError extends ParseError {} // Unknown type
class UserError extends ParseError {} // Stuff like multiple defaults in a switch

class RuntimeError extends BaseError {}

// Generic traceback
typedef Trace = {
	line: Int,
	char: Int
}