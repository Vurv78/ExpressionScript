package base;

final COMMENT = ~/#[^\n]*/;
final ML_COMMENT = ~/#\[.*\]#/;
final DIRECTIVE = ~/@[^\n]*/;

// TODO: Make this work, pretty sure it doesn't right now. Woo

function process(script: String) {
	var processed = ML_COMMENT.replace(script, "");
	processed = COMMENT.replace(script, "");
	processed = DIRECTIVE.replace(script, "");
	return processed;
}