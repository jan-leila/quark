const fs = require('fs');
const lexer = require('../src/engine/lexer.js');

let file = fs.readFileSync('examples/example-project/index.qk', "utf-8");
lexer.reset(file);

let line;
while ((line = lexer.next())) {
    console.log(line.value);
}