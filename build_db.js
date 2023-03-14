import { db, __dirname } from './functions.js'
import CMU from './CMU.json' assert { type: 'json' }
( async () => {
    await db.init()
    const max = Object.keys(CMU).length
    let i = 0;
    for(let key in CMU){
        await db.exec(`INSERT INTO yomi (word,kana) VALUES ("${key}","${CMU[key]}")`)
        //console.log(`\t${i++}/${max}\t${key}:${CMU[key]}`)
    }
})()