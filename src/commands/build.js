const project = require('../util/project')

exports.command = 'build [file]'

exports.describe = 'build quark with target file as main'

exports.builder = yargs => yargs
    .positional('file', {
        describe: 'target file for building',
        default: () => project.config.manifest.entry_point,
    })

exports.handler = async argv => {
    let file = path.join(await dir, argv.file)
    
}
