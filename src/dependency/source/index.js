const path = require('path')
const {
    identified_location,
    cache_location,
    storage_location
} = require('../storage')

const github = require('./github')

const source_list = [
    github,
]

const with_source = ({ type, normalize, source }) => {
    return async (source_url) => {
        const { identifier } = await normalize(source_url)
        const storage = path.join(storage_location, type, identifier)
        const cache = path.join(cache_location, type, identifier)

        return source(identified_location, storage, cache)
    }
}

const sources = Object.fromEntries(
    source_list.map(
        source => [
            source.type,
            with_source(source)
        ]
    )
)

const find_source = async (source_name) => {
    let index = await new Promise((resolve) => {
        Promise.all(source_list.map(async ({ match }, i) => {
            if (await match(source_name)) {
                resolve(i)
            }
        })).allSettled(() => resolve(-1))
    })
    if (index !== -1) {
        return source_list[index].type
    }
}

exports.sources = sources
exports.find_source = find_source
