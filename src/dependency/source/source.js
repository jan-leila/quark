const path = require('path')
const crypto = require('crypto')

const { read_file, list_dir, is_dir, create_read_stream } = require('../../util/files')

const get_identity = async (location) => {
    let identifier_file, signature_file
    try {
        identifier_file = JSON.parse(await read_file(path.join(location, 'identifier.json')))
        signature_file = JSON.parse(await read_file(path.join(location, 'signature.json')))
    }
    catch {
        return
    }

    let { key, uuid } = identifier_file
    let { hash_alg, signature } = signature_file

    let verifier = crypto.createVerify(hash_alg)

    // walk all files getting a hash of all of them
    let queue = (await list_dir(location)).filter(name => name !== 'signature.json')
    while (queue.length !== 0) {
        let target = queue.pop()
        let file = path.join(location, target)
        if (await is_dir(file)) {
            let files = (await list_dir(file)).map(child => path.join(target, child))
            queue.push(...files)
        }
        else {
            await new Promise((resolve, reject) => {
                verifier.write(target)
                let file_stream = create_read_stream(file)
                file_stream.on('finish', resolve)
                file_stream.on('error', reject)
                file_stream.pipe(verifier, { end: false })
            })
        }
    }

    if (!verifier.verify(key, signature)) {
        throw new Error('invalid package signature')
    }

    let kid = crypto.createHash('sha256')
        .update(key)
        .update(uuid)
        .update(hash_alg)
        .digest('hex')

    return kid
}

const source = ({ type, matcher, normalizer, identifier, installer }) => {

    const source = (identified, storage, cache) => {
        // get the location that the package is saved at
        const location = async (package, version) => {
            if (typeof identifier === 'function') {
                let location = await identifier({ storage, cache }, { package, version })
                let identity = await get_identity(location)
                if (identity !== undefined) {
                    return path.join(identified, identity, version)
                }
                return location
            }
        }
        // get package id of package or undefined if not existing
        const identify = async (package, version) => {
            if (typeof identifier === 'function') {
                let location = await identifier({ storage, cache }, { package, version })
                return await get_identity(location)
            }
        }
        // install a target package and version
        const install = async (package, version) => {
            if (typeof installer === 'function') {
                let identity = await identify(package, version)
                return await installer({ storage, cache }, { package, version }, identity ? path.join(identified, identity) : undefined)
            }
        }

        return {
            location,
            identify,
            install,
        }
    }

    return {
        type,
        match: async (url) => {
            if (typeof matcher !== 'function') {
                return false
            }
            return await matcher(url)
        },
        normalize: async (url) => {
            if (typeof normalizer !== 'function') {
                return url
            }
            return await normalizer(url)
        },
        source,
    }
}

module.exports = source
