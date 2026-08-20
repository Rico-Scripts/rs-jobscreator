fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rs-jobscreator'
author 'RS Development'
description 'RS Jobs Creator - ESX + oxmysql + ox_lib + ox_inventory'
version '1.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bootstrap.lua',
    'server/scanner.lua',
    'server/main.lua',
    'server/stability.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/stability.js'
}

dependency 'es_extended'
dependency 'oxmysql'
dependency 'ox_lib'
