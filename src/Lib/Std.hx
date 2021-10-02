package lib;

typedef E2TypeDef = {
	id: String
};

// wire_expression_types
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
	"vector" => {
		id: "vector"
	},
	"entity" => {
		id: "entity"
	}, // temporary.
	"vector2" => {
		id: "vector2"
	},
	"vector4" => {
		id: "vector4"
	}
];

// wire_expression2_funcs
final functions = [];