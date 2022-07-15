const project = require('../util/project')
const { confirm } = require('../util/user')

exports.command = 'alias <alias> [package]'

exports.describe = 'add an alias for a package'

exports.builder = yargs => yargs
    .positional('alias', {
        describe: 'target name for the source package',
    })
    .positional('package', {
        describe: 'name for the target source package',
    })
    .option('yes', {
        alias: 'y',
        type: 'boolean',
        description: 'add package without asking about replacements',
    })
    .option('delete', {
        alias: 'd',
        type: 'boolean',
        description: 'delete alias instead of adding one',
    })
    .conflicts('d', 'package')
    .check((argv) => {
        if (argv.delete && argv.package) {
            return false
        }
        return true
    })

exports.handler = async argv => {
    let config = await project.config.manifest
    let aliases = config.aliases ?? {}
    if (aliases[argv.alias] === argv.package) {
        console.log(`alias "${argv.alias}": "${argv.package}" already defined`);
        return
    }
    if (!argv.delete && !argv.yes && aliases[argv.alias] && !await confirm(`alias "${argv.alias}" already exits. Replace it?`)) {
        return
    }
    await project.useConfig(async () => {
        config.aliases = { ...aliases, [argv.alias]: argv.package }
    })
    if (!argv.delete) {
        console.log(`added alias "${argv.alias}": "${argv.package}"`);
    }
    else {
        console.log(`removed alias "${argv.alias}": "${aliases[argv.alias]}"`);
    }
}
