
const fs = require('fs');
const path = require('path');

const nearley = require("nearley");
const grammar = require("./grammar.js");

// Create a Parser object from our grammar.
const parser = new nearley.Parser(nearley.Grammar.fromCompiled(grammar));

class Package {

	static normalizeVersion(version, padding = "x"){
		return version.split(".").concat(Array(3).fill(padding)).slice(0,3).join(".");
	}

	static matchVersionLable(version, min, exact = false){
		if(min == "x"){
			return true;
		}

		let parts = version.split("-")
		let minParts = min.split("-");

		let _version = parseInt(parts);
		let _min = parseInt(minParts);

		if(exact){
			if(_version != min){
				return false;
			}
		}

		if(_version >= _min){
			return true;
		}

		if(parts[1] || minParts[1] && parts[1] != minParts[1]){
			return false;
		}

		return false;
	}

	static matchVersion(version, minVersion){
		let versionLabels = version.split(".");
		let minVersionLabels = minVersion.split(".");

		for(let i = 0; i < 3; i++){
			// make sure the major versions match
			if(!Package.matchVersionLable(versionLabels[0], minVersionLabels[0], i == 0)){
				return false;
			}
		}
		return true;
	}

	static isNetworkLocation(location){
		try {
			new URL(location);
			return true;
		}
		catch {
			return false;
		}
	}

	constructor(locations, minVersion = "x"){
		if(Array.isArray(locations)){
			// TODO: find the location with the highest matching patch and lowest matching minor and major version
			this.location = locations[0];
		}
		else {
			this.location = locations;
		}

		this.minVersion = Package.normalizeVersion(minVersion);

		let version = Package.normalizeVersion(this.getMetadata().version || "0", "0");

		if(!Package.matchVersion(version, this.minVersion)){
			throw new Error("incorect package version");
		}
	}

	getFile(file, location){
		if(location == undefined){
			location = this.location;
		}

		if(Package.isNetworkLocation(location)){
			// TODO:
		}
		else {
			return fs.readFileSync(path.join(location, file), "utf-8");
		}
		throw new Error("package file not found");
	}

	getMetadata(force = false, location){
		if(force || this.metadata == undefined){
			try {
				this.metadata = JSON.parse(this.getFile("package.json", location));
			}
			catch(e){
				throw new Error("cant read package.json for package");
			}
		}
		return this.metadata;
	}

	compile(entryPoint, std = false){
		let metadata = this.getMetadata();
	
		let dependencyNames = (metadata.dependencies || []);
		
		let dependencies = {};
	
		for(let i in dependencyNames){
			let { name, location, version } = dependencyNames[i];
			let dependency = new Package(location, version);
			let dependencyMetadata = dependency.getMetadata();
			dependencies[name || dependencyMetadata.name] = dependency;
		}
		
		let file = this.getFile(entryPoint.file);

		// Parse something!
		parser.feed(file);
		let ast = parser.results;
		console.log(JSON.stringify(ast, (key, value) => {
			if(value && value.parent){
				delete value.parent;
			}
			return value;
		}, 2));
	}
}

module.exports = Package;