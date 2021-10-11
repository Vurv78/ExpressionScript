package lib;

abstract E2TypeSig(String) from String to String {}

typedef E2TypeDef = {
	id: String
};

// wire_expression_types
// Only adding types that would be possible to replicate outside of the game. (Ignore entity, that's just for convenience)
final types: Map<String, E2TypeDef> = [
	"number" => {
		id: "number"
	},
	"string" => {
		id: "string"
	},
	"table" => {
		id: "table"
	},
	"array" => {
		id: "array"
	},
	"entity" => {
		id: "entity"
	}, // temporary.
	"vector" => {
		id: "vector"
	},
	"vector2" => {
		id: "vector2"
	},
	"vector4" => {
		id: "vector4"
	},
	"angle" => {
		id: "angle"
	},
	"quaternion" => {
		id: "quaternion"
	},
	"complex" => {
		id: "complex"
	},
	"matrix" => {
		id: "matrix"
	},
	"matrix2" => {
		id: "matrix2"
	},
	"matrix4" => {
		id: "matrix4"
	}
];

// Signature for e2 functions.
// For example applyForce(s:v)
// TODO
abstract E2FunctionSig(String) from String to String {}