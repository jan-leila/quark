@{%
	const lexer = require('./lexer.js');
	const util = require('util');
%}
@lexer lexer

ROOT -> (_ IMPORT):* (_ BLOCK):* {%(args) => {
    return {
        imports: args[0].map((args) => {
            return args[1];
        }),
        blocks: args[1].map((args) => {
            return args[1];
        }),
    }
}%}

IMPORT_NAME -> %identifier (_ "as" _ %identifier):?
IMPORT_MAP -> "{" (_ IMPORT_NAME (_ "," _ IMPORT_NAME):*):? _ "}"
IMPORT -> "import" _ (IMPORT_MAP | IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string BREAK
DIRECT_EXPORT -> "export" _ (IMPORT_MAP | "*" | IMPORT_NAME ( _ IMPORT_MAP):?) _ "from" _ %string BREAK

# statements that can only be used at the top level
BLOCK -> ("export" (_ "default"):? _):? (STATEMENT | STRUCT_DECLARATION | ENUM_DECLARATION) {% (args) => {
    if(args[0]){
        return {
            node: 'export',
            default: args[0][1] !== null,
            value: args[1][0],
        }
    }
    return args[1][0];
}%}

# chunks of code that do an action
STATEMENT -> (
    HANDLE
    | VARIABLE_DECLARATION
    | ASSIGNMENT
    | FUNCTION_DECLARATION
    | SEQUENCE_STATEMENT
    | RETURN_STATEMENT
    | CALL
    | BREAK_STATEMENT
    | RETURN_STATEMENT
    | IF
    | SWITCH
    | WHILE
    | DO_WHILE
    | FOR
) _ BREAK {% (args) => {
    return args[0][0];
} %} | SCOPE_STATEMENT {% (args) => {
    return {
        node: 'scope',
        statements: args[0],
    };
}%}

SCOPE_STATEMENT -> "{" (_ STATEMENT):* _ "}" {% (args) => {
    return args[1].map((args) => {
        return args[1];
    })
}%}
BREAK_STATEMENT -> "break"
RETURN_STATEMENT -> "return" _ EXPRESSION
SEQUENCE_STATEMENT -> EXPRESSION "?>" STATEMENT

# control feature extractions
CONTROL_CONDITION ->  "(" _ EXPRESSION _ ")"

HANDLE_EFFECT -> (
    ("with" | "catch") _
    # this shouldnt be a var declaration because it cant be nullable
    "(" _ VARIABLE_DECLARATION _ ")" _
    "{" 
        STATEMENT:*
    "}"
)

HANDLE -> (
    "handle" _ "{"
        STATEMENT:*
    "}"
    ( _ HANDLE_EFFECT ):*
)

FUNCTION_DECLARATION -> (
    "async":? "function" _ FUNCTION_PARAMETERS _ "{"
        STATEMENT:*
    "}"
)

STRUCT_DECLARATION -> (
    "struct" _ TYPE_DECLARATION _ "{"
        ( _ ( VARIABLE_DECLARATION | CONSTRUCTOR )):*
        _
    "}"
)

# Type<T>, Type<ParentType T>, Type<T, K>
TYPE_DECLARATION_PARAM -> ( TYPE _ ):? %identifier
TYPE_DECLARATION -> %identifier ( "<" _ TYPE_DECLARATION_PARAM:? ( _  "," _ TYPE_DECLARATION_PARAM):* _ ">" ):?

ENUM_DECLARATION -> (
    "enum" _ "{"
        ( _ %identifier _ ";"):*
        _
    "}"
)

IF -> "if" _ CONTROL_CONDITION _ STATEMENT ( _ "else" _ "if" CONTROL_CONDITION _ STATEMENT ):* ( _ "else" _ STATEMENT):?
SWITCH -> "switch" _ CONTROL_CONDITION _ "{" (
    _ "case" _ EXPRESSION _ ":"
    (
        _ ("case" _ EXPRESSION _ ":" | STATEMENT )
    ):*
    _
):? _ "}"
WHILE -> "while" _ CONTROL_CONDITION _ STATEMENT
DO_WHILE -> "do" _ STATEMENT _ "while" CONTROL_CONDITION

FOR_CONDITIONS -> STATEMENT _ ";" _ EXPRESSION _ ";" _ STATEMENT
ENHANCED_FOR_CONDITIONS -> PARAMETER_DECLARATION _ ":" _ EXPRESSION
FOR -> "for" _ "(" _ ( FOR_CONDITIONS | ENHANCED_FOR_CONDITIONS ) _ ")" _ STATEMENT

# something that resolves to a value
EXPRESSION -> (
    %identifier
    | NATIVE_LITERAL
    | STRING_TEMPLATE
    | ELEMENT_LITERAL
    | TERNARY
    | ASSIGNMENT
    | CALL
    | PROPERTY
    | COMPARISON
    | BITWISE
    | BOOLEAN
    | SUM
    | PRODUCT
    | EXPONENT
    | UNARY
    | COALESCE
    | SEQUENCE_EXPRESSION
    | ARRAY
    | ANONYMOUS_STRUCT
    | ANONYMOUS_FUNCTION
) {% (args) =>{
    return args[0][0];
} %}

TERNARY -> EXPRESSION _ "?" _ EXPRESSION (_ ":" _ EXPRESSION):?

CALL -> ("await" _ ):? EXPRESSION _ ("(" | "?(") _ (EXPRESSION ( _ "," _ EXPRESSION ):* _ ):? ")"

PROPERTY -> EXPRESSION ("." | "?.") %identifier
# TODO: array property

# ordering is for order of operations
COMPARISON -> EXPRESSION _ ("!=" | ">=" | "<=" | ">" | "<" | "==") _ EXPRESSION
BITWISE -> EXPRESSION _ ("&" | "|" | "^" | "<<<" | ">>>" | "<<" | ">>") _ EXPRESSION
BOOLEAN -> EXPRESSION _ ("&&" | "||" ) _ EXPRESSION
SUM -> EXPRESSION _ ("+" | "-") _ EXPRESSION
PRODUCT -> EXPRESSION _ ("*" | "/" | "%") _ EXPRESSION
EXPONENT -> EXPRESSION _ "**" _ EXPRESSION

UNARY -> 
	"(" _ EXPRESSION _ ")" |
	("-" | "!" | "~") EXPRESSION

COALESCE -> EXPRESSION "??" EXPRESSION
SEQUENCE_EXPRESSION -> EXPRESSION "?>" EXPRESSION

ARRAY -> "[" (_ EXPRESSION (_ "," _ EXPRESSION):* ):? _ "]"

ANONYMOUS_STRUCT_VALUE -> %identifier | (%identifier _ "=" EXPRESSION)
ANONYMOUS_STRUCT -> "{"
    (_ ANONYMOUS_STRUCT_VALUE (_ "," _ ANONYMOUS_STRUCT_VALUE):* ):? _
"}"

CONSTRUCTOR_PARAMETERS -> (
    PARAMETER_DECLARATION ( _ "," _ PARAMETER_DECLARATION):*
)
CONSTRUCTOR -> "async":? "function" _ "(" ( _ FUNCTION_PARAMETERS ):? _ ")" _ "{"
    STATEMENT:*
"}"

# things like:
# param?, param ?? value, param { param? }
DESTRUCTURED_PARAMETER -> FUNCTION_PARAMETER ("?" | (_ "??" STATEMENT | PARAMETER_DESTRUCTUR)):?
# things like:
# { param1?, param2? }
PARAMETER_DESTRUCTUR -> (
    "{"
        DESTRUCTURED_PARAMETER:? ( _ "," _ DESTRUCTURED_PARAMETER):*
        ( _ "..." _ %identifier):?
        _
    "}"
)
# things like:
# value, int value, { value }
FUNCTION_PARAMETER -> PARAMETER_DECLARATION | PARAMETER_DESTRUCTUR
FUNCTION_PARAMETERS -> "(" _ (
    FUNCTION_PARAMETER ( _ "," _ FUNCTION_PARAMETER):*
):? _ ")"
ANONYMOUS_FUNCTION -> (
    "async":? ("function" _ FUNCTION_PARAMETERS | FUNCTION_PARAMETERS _ "=>") _ "{"
        STATEMENT:*
    "}"
)

ASSIGNMENT_TARGET -> %identifier {% (args) => {
    let { col, line, value } = args[0];
    return {
        type: 'direct',
        target: value,
        col, line,
    };
} %} | ASSIGNMENT_TARGET "." %identifier {% (args) => {
    let { col, line, value } = args[2];
    return {
        type: 'property',
        parent: args[0],
        target: value,
        col, line,
    };
}%} | ASSIGNMENT_TARGET "[" _ EXPRESSION _ "]" {% (args) => {
    let { col, line, value } = args[3];
    return {
        type: 'index',
        parent: args[0],
        target: value,
        col, line,
    };
}%}
# a = 1, b = "test"
ASSIGNMENT -> ASSIGNMENT_TARGET _ %assignment _ EXPRESSION {% (args) => {
    return {
        node: 'assignment',
        target: args[0],
        type: args[2].value,
        value: args[4],
    };
}%} | ASSIGNMENT_TARGET ("++" | "--") {% (args) => {
    return {
        node: args[1][0].value === '++' ? 'increment' : 'decrement',
        target: args[0],
    };
} %}

# let a[]?, int b = 1;
VARIABLE_DECLARATION -> TYPE _ VARIABLE_KEYWORD (_ "=" _ EXPRESSION):? {% (args) => {
    let { line, col, value } = args[2];
    if(args[3]){
        return {
            node: 'variable_declaration',
            type: args[0],
            target: value,
            value: args[3][3],
            line, col,
        };
    }
    return {
        node: 'variable_declaration',
        type: args[0],
        target: value,
        line, col,
    };
} %}
# let a, int b, stirng c[]?, d
PARAMETER_DECLARATION -> (TYPE _):? VARIABLE_KEYWORD {% (args) => {
    let { line, col, value } = args[1];
    if(args[0]){
        return {
            node: 'parameter_declaration',
            type: args[0][0],
            target: value,
            line, col,
        };
    }
    return {
        node: 'parameter_declaration',
        target: value,
        line, col,
    };
} %}
# a[]?, b?, c[], d
VARIABLE_KEYWORD -> %identifier ("[" _ "]"):* "?":? {% (args) => {
    let { line, col, value } = args[0];
    return {
        value,
        depth: args[1].length,
        nullable: !!args[2],
        line, col,
    };
} %}

# Type, Type<int>, Type1<Type2<int>>, Type1<int, int>
TYPE -> %type {% (args) => {
    let { line, col, value } = args[0]
    return {
        node: 'native_type',
        target: value,
        line, col,
    };
} %} | %identifier ("<" _ TYPE:? ( _  "," _ TYPE):* _ ">"):? {% (args) => {
    let { line, col, value } = args[0];

    if(args[1]){
        return {
            node: 'type',
            target: value,
            generic: [ args[1][2], ...args[1][3].map((args) => {
                return args[3];
            })].filter((arg) => arg),
            line, col,
        };
    }

    return {
        node: 'type',
        target: value,
        line, col,
    };
} %}

# <></>, <tag></>, <tag value=1/> <tag>value</>
ELEMENT_LITERAL -> "<" _ %identifier (_ %identifier _ "=" _ EXPRESSION):* _ ("/>" | ">" (_ EXPRESSION):* _ %tag_close (_ %identifier):? _ ">") {% (args) => {
    let children;
    if(args[5][0].type === 'impl_tag_close'){
        children = [];
    }
    else {
        if(args[5][4]){
            let closeTag = args[5][4][1];
            if(closeTag.value !== args[2].value){
                return {
                    node: 'error',
                    type: 'tag_missmatch',
                    col: closeTag.col, line: closeTag.line,
                };
            }
        }
        children = args[5][1].map((args) => {
            return args[1];
        });
    }
    return {
        node: 'element',
        target: args[2],
        props: args[3].map((args) => {
            return {
                key: args[1],
                value: args[5],
            };
        }),
        children,
    };
} %}

# `this is some text ${getValue()} more text`
STRING_TEMPLATE -> %lit_str_start (
    %str_content
    | %escape
    | (%interp _ EXPRESSION _ "}")
):* %lit_str_end {% (args) => {
    return {
        node: 'template_string',
        value: args[1].reduce((out, [ value ]) => {
            if(Array.isArray(value)){
                out.push({
                    type: 'interp',
                    value: value[2],
                });
            }
            else {
                let last = out[out.length - 1];
                if(last?.type === 'text'){
                    last.value += value.value;
                }
                else {
                    let { line, col } = value;
                    out.push({
                        type: 'text',
                        line, col,
                        value: value.value,
                    });
                }
            }
            return out;
        }, []),
    };
}%}

# literal values such as numbers text and undefined
NATIVE_LITERAL -> (
    %int	|
	%float	|
	%hex    |
	%string |
	%undefined
) {% (args) => {
    let { line, col, type, value } = args[0][0];
    return { node: 'value', line, col, type, value };
} %}

# semantic things
BREAK -> ";" {% () => {} %}
_ -> %whitespace:? {% () => {} %}
