const project = require('../util/project')

exports.command = 'install <package>'

exports.describe = 'add dependencies to your project'

exports.builder = yargs => yargs
    .positional('package', {
        describe: 'target folder to create project in',
    })
    .option('peer', {
        alias: 'p',
        type: 'boolean',
        description: 'install package as a peer dependency',
    })
    .option('development', {
        alias: 'd',
        type: 'boolean',
        description: 'install package as a dev dependency',
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
    
    let source = 'source'
    let package_name = 'package_name'
    let version = 'version'
    
    let dependency = `${package_name}@${source}`

    await project.useConfig(async () => {
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
        let packages = config.packages ?? {};
        config.packages = { ...packages, [dependency]: version }
    })

    if(!argv.n){
        // TODO: install package
    }
}
