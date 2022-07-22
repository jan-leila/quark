const fs = require('fs')
const path = require('path')
const zlib = require('zlib')
const https = require('https')

const exists = async (file) => {
    return await fs.promises.access(file, fs.constants.F_OK)
        .then(() => true)
        .catch(() => false)
}

const mkdir = async (dir) => {
    return await fs.promises.mkdir(dir, { recursive: true })
}


const read_file = async (file) => {
    return await fs.promises.readFile(
        file,
        {
            encoding: 'utf-8',
        },
    )
}

const write_file = async (file, data) => {
    await mkdir(path.dirname(file))
    return await fs.promises.writeFile(
        file,
        data,
        {
            encoding: 'utf-8',
        },
    )
}

const delete_file = async (file) => {
    return await fs.promises.unlink(file)
}

const downalod = async (uri, output) => {
    try {
        const file_stream = fs.createWriteStream(download_folder)
        const gz = zlib.createGzip()
        await new Promise((resolve, reject) => {
            file_stream.on('finish', resolve)
            file_stream.on('error', reject)
            gz.on('error', reject)
            request.on('error', reject)

            gz.pipe(file_stream)
            https.get(download_url, res => res.pip(gz))
        })
        gz.end()
        return true
    }
    catch {
        return false
    }
}


module.exports = {
    exists,
    mkdir,
    read_file,
    write_file,
    delete_file,
}