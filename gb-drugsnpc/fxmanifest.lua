fx_version 'cerulean'
game 'gta5'

author 'GrossBean'
description 'QBCore - Sell Drugs to NPCs (Optimized & Realistic)'
version '1.0.3'

lua54 'yes'

shared_script 'config.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    '@qb-core/server/main.lua',
    'server.lua'
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-inventory',
    'qb-menu'
}
