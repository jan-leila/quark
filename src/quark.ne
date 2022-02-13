@{%
	const lexer = require('./lexer.js');
	const util = require('util');
%}
@lexer lexer

# ROOT -> _ (IMPORT _):* (BLOCK _ ):* _
ROOT -> (_ (IMPORT _):* (STATEMENT _ ):* _) {% (args) => {
	return {
		type: 'statment',
		value: [
			...args[0][1].map((value) => {
				return value[0];
			}),
			...args[0][2].map((value) => {
				return value[0];
			}),
		],
	}
} %}

IMPORT_NAME -> %identifier (_ "as" _ %identifier):?
IMPORT_MAP -> "{" (_ IMPORT_NAME (_ "," _ IMPORT_NAME):*):? _ "}"
IMPORT -> "import" _ ( IMPORT_NAME | IMPORT_MAP | (IMPORT_NAME _ "," _ IMPORT_MAP ) ) _ "from" _ %string _ BREAK

BLOCK -> ENUM_DECLARATION | STRUCTURE_DECLARATION | FUNCTION_DECLARATION | COMPONENT_DECLARATION | STATEMENT | EXPORT
EXPORT -> "export" (_ "default"):? BLOCK

DECLARATION -> ENUM_DECLARATION | VALUE_DECLARATION | STRUCTURE_DECLARATION | FUNCTION_DECLARATION | COMPONENT_DECLARATION

# defining a new enum type
ENUM_VALUES -> %identifier ( _ "," _ %identifier ):* BREAK
ENUM_DECLARATION -> "enum" _ %identifier _ "{" (_ ENUM_VALUES):? (_ (%access _):? DECLARATION):*  _ "}"

# defining a new structure type
STRUCTURE_VALUE_DECLARATION -> (%access _):? ("static" _ ):? DECLARATION
STRUCTURE_DECLARATION -> "struct" _ TYPE_DECLARATION ( _ "extends" _ TYPE ( _ "," TYPE):* ) _ "{" (_ STRUCTURE_VALUE_DECLARATION):* _ "}"

# defining a new function type
FUNCTION_ARGUMENT -> (TYPE _):? ASSIGNMENT_IDENTIFIER
FUNCTION_ARGUMENTS -> FUNCTION_ARGUMENT:? ( _ "," _ FUNCTION_ARGUMENT):*
FUNCTION_DECLARATION -> ("function" _ %identifier "(" _ FUNCTION_ARGUMENTS _ ")") | ("(" _ FUNCTION_ARGUMENTS _ ")" _ "=>") _ "{" STATEMENT "}"

# defining a new component type
COMPONENT_DECLARATION -> "component" _ %identifier "(" _ FUNCTION_ARGUMENTS _ ")" _ "{" STATEMENT "}"

# control structures or clauses
STATEMENT -> ((SWITCH | FOR | DO_WHILE | WHILE | IF | CLAUSE) {% (value) => {
	return value[0];
} %} | ("{" ( _ STATEMENT):* _ "}") {% (args) => {
	return args[0][1].map((value) => {
		return value[1];
	});
} %}) {% (value) => {
	return {
		type: 'statement',
		value: value[0],
	};
} %}

# control feature extractions
CONTROL_BLOCK -> STATEMENT | ("{" (_ STATEMENT):* "}")
CONTROL_CONDITION ->  "(" _ VALUE _ ")"

# control strucutres
IF -> "if" CONTROL_CONDITION _ CONTROL_BLOCK ( _ "else" _ "if" CONTROL_CONDITION _ CONTROL_BLOCK ):* ( _ "else" _ CONTROL_BLOCK):?
SWITCH -> "switch" CONTROL_CONDITION _ "{" ( _ "case" _ (LITERAL | %identifier) _ ":" ( _ CLAUSE):* ( _ "break" _ BREAK):?):* _ "}"
FOR -> "for" "(" (CLAUSE:? _ VALUE _ BREAK _ VALUE:?) | (TYPE _ ASSIGNMENT_IDENTIFIER _ ":" _ VALUE) ")" _ CONTROL_BLOCK
WHILE -> "while" CONTROL_CONDITION _ CONTROL_BLOCK
DO_WHILE -> "do" _ CONTROL_BLOCK _ "while" CONTROL_CONDITION

# value or declaration with break at end no to be used in conditions
CLAUSE -> ((VALUE | VALUE_DECLARATION | RETURN ) _ BREAK) {% (args) => {
	console.log(args[0][0]);
	return {
		type: 'clause',
		value: args[0][0][0],
	};
}%}

RETURN -> ("return" _ VALUE) {% (args) => {
	return {
		type: 'return',
		value: args[0][2],
	};
}%}

# declaring new variables (same as assignment but with a type attached)
DECLARATION_BLOCK -> ((ASSIGNMENT_IDENTIFIER | ("(" _ %identifier ( _ "," _ %identifier):* _ ")") {% (identifier) => {
		return [identifier[0][2], ...identifier[0][3].map((v) => {
			return v[3];
		})];
	} %}) (_ "=" _ VALUE):?) {% (args) => {
	if(args[0][1]){
		return {
			type: 'declaration_block',
			identifiers: args[0][0],
			value: args[0][1][3],
		};
	}
	return {
		type: 'declaration_block',
		identifiers: args[0][0],
	};
}%}
VALUE_DECLARATION -> (("final":? _) TYPE _ DECLARATION_BLOCK ( _  "," _ DECLARATION_BLOCK):*) {% (args) => {
	return {
		type: 'declaration',
		declaration_type: args[0][1],
		final: args[0][0][0] !== null,
		blocks: [ args[0][3], ...args[0][4].map((block) => {
			return block[3];
		}) ]
	};
} %}

# union type that gives anything that spits out another value
VALUE -> (%identifier | LITERAL | EXPRESSION | STRING_LITERAL | ARRAY_LITERAL | MAP_LITERAL | COMPONENT_LITERAL | FUNCTION_CALL | ASSIGNMENT | UNARY_ASSIGNMENT) {% (args) => {
	return args[0][0];
}%}

# destructuring arrays: [ value1, value2 ] = arr
ARRAY_DESTRUCTURE_DEFAULT -> ASSIGNMENT_IDENTIFIER ( _ "=" _ VALUE):?
ARRAY_DESTRUCTURE -> "[" _ ASSIGNMENT_IDENTIFIER ( _ "," _ ASSIGNMENT_IDENTIFIER ) _ "]"

# destructuring maps: {value:a = 2, value2} = map
MAP_DESTRUCTURE_RENAME -> ASSIGNMENT_IDENTIFIER _ ":" _ %identifier
MAP_DESTRUCTURE_DEFAULT -> MAP_DESTRUCTURE_RENAME ( _ "=" VALUE)
MAP_DESTRUCTURE -> "{" _ MAP_DESTRUCTURE_DEFAULT ( _ "," _ MAP_DESTRUCTURE_DEFAULT ) _ "}"

# union type for the different ways of writing and identifier
ASSIGNMENT_IDENTIFIER -> (%identifier | ARRAY_DESTRUCTURE | MAP_DESTRUCTURE) {% (args) => {
	return args[0][0];
} %}

# assigning a value to an already declaired identifier
ASSIGNMENT ->  DIRECT_ASSIGNMENT | MODIFIER_ASSIGNMENT | UNARY_ASSIGNMENT
DIRECT_ASSIGNMENT -> ASSIGNMENT_IDENTIFIER | ("(" _ %identifier ( _ "," _ %identifier) _ ")") _ "=" _ VALUE
MODIFIER_ASSIGNMENT -> %identifier _ ("+=" | "-=" | "*=" | "/=" | "%=" | "**=" | "&=" | "|=" | "~=" | "^=" | "<<<=" | ">>>=" | "<<=" | ">>=" | "&&=" | "||=" | "<<=" | ">>=") _ VALUE
UNARY_ASSIGNMENT -> %identifier ("++" | "--")

# things like: name(), name(value), name(...array), name(key=value), name(value1, value2)
FUNCTION_ARGUMENT -> (VALUE | (KEY_WORD _ "=" _ VALUE) | ARRAY_SPREAD | MAP_SPREAD) {% (args) => {
	return {
		type: 'argument',
		value: args[0][0],
	};
}%}
FUNCTION_CALL -> (VALUE "(" ( _ FUNCTION_ARGUMENT ( _  "," _ FUNCTION_ARGUMENT):*):? _  ")") {% (args) => {
	let arguments_obj = args[0][2];
	let arguments = [ ...([arguments_obj[1]]??[]), ...arguments_obj[2].map((arg) => {
		return arg[3];
	})];
	
	return {
		type: 'function_call',
		value: {
			target: args[0][0],
			arguments,
		},
	};
}%}

# an expression is something that takes in values and evaluates to a new value
EXPRESSION -> COMPARISON | BITWISE | BOOLEAN | SUM | PRODUCT | EXPONENT | UNARY | TERNARY

# function to make things below a lot cleaner
# @{%
# 	function operator(data){
# 		return {
# 			type: "operator",
# 			operator: data[2][0].value,
# 			a: data[0][0],
# 			b: data[4][0],
# 		};
# 	}
# %}

# match things like value1? value2:value3
TERNARY -> VALUE _ "?" _ VALUE _ ":" _ VALUE

# ordering is for order of operations
COMPARISON -> VALUE _ ("!=" | ">=" | "<=" | ">" | "<" | "==") _ VALUE
BITWISE -> VALUE _ ("&" | "|" | "^" | "<<<" | ">>>" | "<<" | ">>") _ VALUE
BOOLEAN -> VALUE _ ("&&" | "||" ) _ VALUE
SUM -> VALUE _ ("+" | "-") _ VALUE
PRODUCT -> VALUE _ ("*" | "/" | "%") _ VALUE
EXPONENT -> VALUE _ "**" _ VALUE

# an operator that operates on a single value
UNARY -> 
	"(" _ VALUE _ ")" |
	(("-" | "!" | "~") VALUE)

# things like: `text`, `more text ${value} stuff`, `stuff \${}`
STRING_LITERAL -> "${" (
	%str_content
	| %escape
	| (%interp VALUE  "}")
) %lit_str_end

# things like: [], [ 1234 ], [ ...array ]
ARRAY_SPREAD -> "..." (ARRAY_LITERAL | %identifier)
ARRAY_COMPONENT -> ARRAY_SPREAD | VALUE
ARRAY_LITERAL -> "[" ( _ ARRAY_COMPONENT ( _  "," _ ARRAY_COMPONENT):*):? _ "]"

# things like: {}, { a: "value"}, { ...map }, { [key]: value }
MAP_SPREAD -> "..." (ARRAY_LITERAL | %identifier)
MAP_COMPONENT -> MAP_SPREAD | (KEY_WORD _ ":" _ VALUE)
MAP_LITERAL ->  "{" ( _ MAP_COMPONENT ( _  "," _ MAP_COMPONENT):*):? _  "}"

# things like: <Tag prop="value"/>, <Tag prop="value">thing</>
COMPONENT_LITERAL -> "<" %identifier ( _ %identifier "=" VALUE):* ("/>" | (">" _ VALUE _  "</>"))

# primitive object type
LITERAL -> 
	(%int	|
	%float	|
	%hex    |
	%string |
	%null) {% ([[{ type, value, line, col}]]) => {
		return {
			type: 'literal',
			literal_type: type,
			value,
			line,
			col,
		}
	} %}

KEY_WORD -> %identifier | ("[" _ %identifier _ "]")

# a type for an object
TYPE -> (%type | %identifier) GENERIC:? {% (args) => {
	if(args[1]){
		return {
			type: 'type',
			value: args[0],
			generic: args[1],
		};
	}
	return {
		type: 'type',
		value: args[0],
	};
}%}
TYPE_DECLARATION -> %identifier GENERIC_DECLARATION:?

# a generic type
GENERIC -> "<" _ TYPE:? ( _  "," _ TYPE):* _ ">"
GENERIC_DECLARATION -> "<" _ (TYPE _ %identifier):? ( _  "," _ (TYPE _ %identifier)):* _ ">"

# things we dont care about
BREAK -> ";" {% () => {} %}
_ -> %whitespace:? {% () => {} %}