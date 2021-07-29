package lib;

// Parser found incorrect or missing syntax.
class SyntaxError extends haxe.Exception {}

// Unknown type found during parsing or compiling
class TypeError extends haxe.Exception {}

// Error in parsing that wasn't necessarily syntax
class ParseError extends haxe.Exception {}

// Compile error
class CompileError extends haxe.Exception {}