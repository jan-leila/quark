
exports.command = 'alias [alias] [package]'

exports.describe = 'add an alias for a package'

exports.builder = yargs => yargs
    .positional('alias', {
        describe: 'target name for the source package',
    })
    .positional('package', {
        describe: 'name for the target source package',
    })

exports.handler = async argv => {
    project.config.manifest.aliases[argv.alias] = argv.package
}
