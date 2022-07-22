const os = require('os')
const path = require('path')
const { delete_file, exists, downalod } = require('./files')

const registry_path = path.join(os.homedir(), '.quark', 'registry')

const sources = {
    github: Symbol()
}

const use_loader = async (lambda) => {
    return (opts) => {
        let package = await lambda(opts)
        if (!package) {
            return installer[opts.type](opts)
        }
        return package
    }
}

const installer = {
    [sources.github]: async ({ source, package, version, force }) => {
        const download_url = `${source}/${package}/archive/refs/tags/${version}.tar.gz`
        const download_folder = path.join(registry_path, 'github', source, version)
        if (force) {
            await delete_file(download_folder)
        }
        if (!await exists(download_folder)) {
            await downalod(download_url, download_folder)
        }
        // TODO: return that package somehow?
    }
}

const loader = {
    [sources.github]: use_loader(async ({ source, package, version }) => {
        // TODO: return that package somehow?
    })
}

const type_regex = {
    [sources.github]: /^(?:https?:\/\/)?(?:www.)?github\.com\/(\w+)/
}
const type_regex_keys = Object.keys(type_regex)

infer_type = (source) => {
    return type_regex_keys.find((type) => {
        return type_regex[type].exec(source) !== null
    })
}

exports.parse_name = (name) => {
    let source_index = name.lastIndexOf('@')
    let version_index = name.lastIndexOf(':', source_index)

    return {
        package: name.substring(0, version_index),
        version: version_index === -1 ? undefined : name.substring(version_index + 1, source_index === -1 ? undefined : source_index),
        source: source_index === -1 ? undefined : name.substring(source_index + 1),
    }
}

exports.install = async (package, version, source, type, opts) => {
    if (!source) {
        throw new Error('no source found')
    }
    if (!type) {
        type = infer_type(source)
    }
    if (!type) {
        throw new Error('no source type found')
    }
    return await installer[type]({ package, version, source, type, ...opts })
}

exports.load = async (package, version, source, type) => {
    if (!source) {
        throw new Error('no source found')
    }
    if (!type) {
        type = infer_type(source)
    }
    if (!type) {
        throw new Error('no source type found')
    }
    return await loader[type]({ package, version, source, type})
}
