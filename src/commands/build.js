const project = require('../util/project')

exports.command = 'build [file] [output]'

exports.describe = 'build quark with target file as main'

exports.builder = yargs => yargs
    .positional('file', {
        describe: 'target file for building',
        default: () => project.config.manifest.entry_point,
    })
    .positional('output', {
        describe: 'target file to output build as',
    })
    .option('platform', {
        alias: 'p',
        description: 'target platform to build for',
        // TODO: default to current platform
    })

exports.handler = async argv => {
    let file = path.join(await dir, argv.file)
    
}
