import express from 'express'
const app = express()
import dotenv from 'dotenv'
dotenv.config()

import { db, r2h, kanaToHira, exec, sleep, pr, __dirname } from './functions.js'

await db.init()
const text = 'はろー！！！'
const words = text.match(/([A-Za-z]+)|([^A-Za-z]+)/g)
let str = ''
for(let i = 0; i < words.length; i++){
    if(words[i] !== ''){
        const word = words[i].toLowerCase()
        const {result} = await db.exec(`SELECT * FROM yomi WHERE word="${word}"`)
        if(result.length){
            str += result[0].kana
        }else
        if(word.match(/^[a-z]+$/i)){
            str += r2h(word)
        }else{
            str += word
        }
    }
}
str
    // 特殊文字の除外
    .replace(/["#&\(\)\|`\*\+<>\\;\n]/g,' ')
    // ? の置換
    .replace(/\?/,'？')
const {stdout} = await exec(`echo "${str}" | mecab -Oyomi`)

console.log(stdout)