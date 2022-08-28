const { parse_name, infer_name } = require('../dependency/install')
const { install } = require('../util/package')
const project = require('../util/project')

exports.command = 'add <package>'

exports.describe = 'add dependencies to your project'

exports.builder = yargs => yargs
    .positional('package', {
        describe: 'target package name',
    })
    .option('peer', {
        alias: 'p',
        type: 'boolean',
        description: 'add package as a peer dependency',
    })
    .option('development', {
        alias: 'd',
        type: 'boolean',
        description: 'add package as a dev dependency',
    })
    .conflicts('d', 'p')
    .option('no-install', {
        alias: 'n',
        type: 'boolean',
        description: 'add package to dependency list without installing it',
    })

const package = Symbol()
const peer = Symbol()
const development = Symbol()

exports.handler = async argv => {
    let type = argv.development ? development : argv.peer ? peer : package
    
    let name = parse_name(argv.package)
    if (!name) {
        name = infer_name(argv.package)
    }
    if (!name) {
        throw new Error('unable to parse package')
    }
    let { package: package_name, version, source } = name
     
    if (!package_name) {
        // TODO: give hint on possible packages
        throw new Error('unable to resolve package name')
    }
    if (!source) {
        // TODO: give hint on possible packages
        throw new Error('unable to resolve package source')
    }
    if (!version) {
        // TODO: get latest version available
        throw new Error('unable to resolve target package version')
    }

    let dependency = `${package_name}:${version}@${source}`

    let config
    switch (type) {
        case package:
            config = await project.config.manifest ?? {}
            break;
        case peer:
            config = await project.config.manifest ?? {}
            break;
        case development:
            config = await project.config.development ?? {}
            break;
    }
    await project.useConfig(async () => {
        let packages = config.packages ?? {};
        config.packages = { ...packages, [dependency]: version }
    })
    
    if(!argv.n){
        install(package_name, version, config.sources[source].source, config.sources[source].type)
    }
}
