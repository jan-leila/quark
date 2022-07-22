const { parse_name, install } = require("../util/package")

exports.command = 'install <package> [source] [type]'

exports.describe = 'install dependency localy'

exports.builder = yargs => yargs
    .positional('package', {
        describe: 'target package name',
    })
    .positional('source', {
        describe: 'source to install the package from',
    })
    .positional('type', {
        describe: 'source type',
    })

exports.handler = async argv => {
    let { package, version, source } = parse_name(argv.package)

    const project = require('../util/project')

    let source_uri;
    let source_type;

    if (argv.source) {
        source_uri = argv.source
        source_type = argv.type
    }
    else if (source) {
        let manifest_source = (await project.config.manifest).sources[source]
        if (manifest_source) {
            source_uri = manifest_source.source
            source_type = manifest_source.type
        }
        else {
            let development_source = (await project.config.development).sources[source]
            if (development_source) {
                source_uri = development_source.source
                source_type = development_source.type
            }
        }
    }

    install(package, version, source_uri, source_type)
}