
const fs = require('fs');
const path = require('path');

const Package = require('./src/package');

function compileFile(file, std = false){
	fs.readFile(file, "utf-8", (err, file) => {
		if(err){
			throw new Error(err);
		}
		console.log(file);
	});
}


let entry = {
	file: "tmp.qk"
}
// let entry = {
// 	file: "stdout.qk",
// 	method: "main"
// }

new Package(path.join(__dirname, "../std")).compile(entry);
