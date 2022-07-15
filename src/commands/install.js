
exports.command = 'install <package>'

exports.describe = 'add dependencies to your project'

exports.builder = yargs => yargs
    .positional('package', {
        describe: 'target folder to create project in',
    })
    .option('peer', {
        alias: 'p',
        type: 'boolean',
        description: '',
    })
    .option('development', {
        alias: 'd',
        type: 'boolean',
        description: '',
    })
    .conflicts('d', 'p')
    .option('no-install', {
        alias: 'n',
        type: 'boolean',
        description: '',
    })

const package = Symbol()
const peer = Symbol()
const development = Symbol()

exports.handler = async argv => {
    let type = argv.development ? development : argv.peer ? peer : package
    
    let source = undefined
    let package_name = undefined
    let version = undefined
    
    let dependency = `${package_name}@${source}`

    switch (type) {
        case package:
            project.config.manifest.packages[dependency] = version
            break;
        case peer:
            project.config.manifest.peers[dependency] = version
            break;
        case development:
            project.config.development.packages[dependency] = version
            break;
    }

    if(!argv.n){
        // TODO: install package
    }
}
