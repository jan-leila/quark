const moo = require('moo');

let lexer = moo.states({
	main: {
		whitespace: [{ match: /[ \n\t]+/, lineBreaks: true }, /[ \t]+/s],
		comment: [
			/\/\/[^\n]*/,
			{ match: /\/\*[^]*?\*\//, lineBreaks: true },
		],

		binary: /0b[01]+/,
		hex: /0x[0-9a-fA-F]+/,
		int: /[0-9]+(?![0-9]*\.)/,
		float: /(?:0|[1-9][0-9]*)(?:\.[0-9])?[0-9]*/,
		color: [
			/#[0-9a-fA-F]{3}/,
			/#[0-9a-fA-F]{6}/,
			/#[0-9a-fA-F]{8}/,
		],

		regex: /\/(?=(?:(?:\\.)?[^\\\/\n]+)+\/)/,

		string: [
			{ match: /".*?(?<!\\)(?:\\\\)*"/s, lineBreaks: true },
			{ match: /'.*?(?<!\\)(?:\\\\)*'/s, lineBreaks: true }
		],
		lit_str_start: { match: '`', push: 'str_lit' },

		lcbracket: { match: '{', push: 'main' },
		rcbracket: { match: '}', pop: true },

		misc_tokens: [
			'<<<=', '>>>=',
			'...', '<<<', '>>>',

			'<<=', '>>=', '&&=', '||=', '<<=', '>>=', '**=',
			'??', '++', '--', '==', '<<', '>>', '&&', '||', '<<', '>>', '**',

			'+=', '-=', '*=', '/=', '%=', '&=', '|=', '~=', '^=', '=>', '/>', '</', '!=', '>=', '<=',
			'=', '<', '>', '?', ':', '.', ',', '(', ')', '[', ']', '&', '|', '^', '+', '-', '*', '/', '%', '!', '~',
		],

		identifier: {
			match: /\w+/, type: moo.keywords({
				keywords: [
					'import', 'from', 'as', 'export', 'default',
					'if', 'else', 'switch', 'case', 'default', 'do', 'while', 'for', 'break', 'continue', 'return',
					'try', 'with', 'handle', 'use', 'throw', 'catch',
					'enum', 'struct', 'function', 'effect', 'from', 'to', 'monad', 'bind', 'reduce',
					'let', 'symbol', 'boolean', 'int', 'float', 'string', 'char', 'func',
					'null',
				],
			})
		},
		break: ';',
	},
	str_lit: {
		interp: { match: '${', push: 'main' },
		str_content: { match: /(?:(?:\\.)+|[^\\$`]+)+/, lineBreaks: true },
		lit_str_end: { match: '`', pop: true },
	},
	regex: {
		// TODO: replace with real regex parsing
		regex: /(?:(?:\\.)?[^\\\/\n]+)+/,
		// regex_literals: /(?:\\.)+/,
		regex_end: { match: '/', pop: true },
	}
});

module.exports = lexer;