const { install } = require('../dependency/install')
const project = require('../util/project')

exports.command = 'install <package> [source] [type]'

exports.describe = 'install dependency locally'

exports.builder = yargs => yargs
    .positional('package', {
        describe: 'target package name',
    })
    .positional('source', {
        describe: 'source url to install the package from',
    })
    .positional('type', {
        describe: 'source type',
    })

exports.handler = async argv => {
    let name = parse_name(argv.package)
    if (!name) {
        name = infer_name(argv.package)
    }
    if (!name) {
        throw new Error('unable to parse package')
    }
    let { package, version, source } = name

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

    if (argv.source) {
        return await install(package, version, argv.source, argv.type)
    }

    if (package !== undefined) {
        let source_info = (await project.config.manifest).sources[source] ?? (await project.config.development).sources[source]
        if (source_info) {
            return await install(package, version, source_info.source, source_info.type)
        }
    }
    else {
        return await install(undefined, undefined, source, undefined)
    }
}