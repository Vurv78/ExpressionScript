# ExpressionScript
A language heavily derived from Expression2.  
This was originally created to be a template to rewrite E2 for S&box, however at this point I don't really care about S&box nor am I interested in C#.  

## Compiler
This currently does not support compiling. It's not quite done and I've been focusing on the transpiler first.

## Transpiler
This project allows you to convert ExpressionScript code to any language, as long as a transpiler is provided.  
By default a Lua transpiler is provided and more may come.  

## Differences

### No ``normal``
	Normal is a type that came before ``number``, however nobody uses it and it just complicates things.  

### No inputs
	For obvious reasons, there's no io or entities in this as this is meant to be run in the browser, or simply on your pc.  

### Fixed bitwise operators
	E2 randomly swapped || and | / & and &&. && was made into bitwise and rather than logical and.  
	It has been switched to match typical language spec.  

### Optimized
	The language is optimized for speed. E2 was known to be very slow, and this is no longer the case through typing and other optimizations.
