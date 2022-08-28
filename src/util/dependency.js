const path = require('path')
const { read_file } = require('./files')

exports.dependency = (folder) => {

    let manifest
    const getManifest = async () => {
        if (!manifest) {
            manifest = JSON.parse(await read_file(path.join(folder, 'manifest.json')))
        }
        return manifest
    }

    return {
        async getDependencies(){
            await getManifest()
        },
        async getIdentifier(){
            
        },
    }
}
