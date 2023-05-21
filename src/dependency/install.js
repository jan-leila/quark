const { sources, find_source } = require('./source')

const install = async (package, version, source, type) => {    if (!type) {
        type = await find_source(source)
    }
    if (!type) {
        throw new Error('no source type found')
    }

    // version
    
    return await sources[type](source).install(package, version)
}

const locate = async (package, version, source, type) => {
    if (!source) {
        throw new Error('no source found')
    }
    if (!type) {
        type = await find_source(source)
    }
    if (!type) {
        throw new Error('no source type found')
    }

    // TODO: version

    return await sources[type](source).location(package, version)
}

const parse_name = (name) => {
    let source_index = name.lastIndexOf('@')
    let has_source = source_index === -1
    let version_index = name.lastIndexOf(':', has_source ? source_index : 0)
    let has_version = version_index === -1
    if (has_source && has_version)
        return {
            package: name.substring(0, version_index),
            version: name.substring(version_index + 1, source_index),
            source: name.substring(source_index + 1),
        }
    if (has_source)
        return {
            package: name.substring(0, source_index),
            source: name.substring(source_index + 1),
        }
    if (has_version)
        return {
            package: name.substring(0, version_index),
            version: name.substring(version_index + 1),
        }
}

const infer_name = (name) => {
    let source = find_source(name)
    return source?.normalize?.(name)
}

exports.install = install
exports.locate = locate
exports.parse_name = parse_name
exports.infer_name = infer_name