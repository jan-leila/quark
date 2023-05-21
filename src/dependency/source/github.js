const path = require('path')

const source = require('./source')
const { exists, download, rename } = require('../../util/files')

const type = 'github'

const matcher_regex = /^(?:https?:\/\/)?(?:www.)?(github\.com\/(\w+))(?:\/(\w+)(?:\/releases\/tag\/(\w+)?)?|.+)?/
const matcher = (url) => {
    return matcher_regex.exec(url) !== null
}

const normalizer = (url) => {
    let [_, identifier, package, version] = matcher_regex.exec(url)
    return {
        identifier, package, version,
    }
}

const test_location = async (...paths) => {
    let location = path.join(...paths)
    if (await exists(location)) return location
}
const locate = async ({ storage, cache }, { package, version }) => {
    return (
        await test_location(storage, package, version)
        ?? await test_location(cache, package, version)
    )
}

const identifier = async ({ storage, cache }, { package, version }) => {
    let location = await locate({ storage, cache }, { package, version })
    if (location === undefined) {
        location = path.join(cache, package, version)
        await install({ package, version }, location)
    }
    return location
}

const installer = async ({ storage, cache }, { package, version }, location) => {
    if (location === undefined) {
        location = path.join(storage, package, version)
    }
    let cache_location = path.join(cache, package, version)
    if (await exists(cache_location)) {
        await rename(cache_location, location)
    }
    else {
        await install({ package, version }, location)
    }
}

const install = async ({ package, version }, location) => {
    const download_location = `${NAME}/${package}/archive/refs/tags/${version}.tar.gz`
    await download(location, download_location)
}

module.exports = source({
    type,
    matcher,
    normalizer,
    identifier,
    installer,
})
