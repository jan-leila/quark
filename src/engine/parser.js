const nearley = require("nearley");
const grammar = require("../../build/grammar.js");

// Create a Parser object from our grammar.
module.exports = new nearley.Parser(nearley.Grammar.fromCompiled(grammar));
