fx_version 'cerulean'
game 'gta5'

author 'Sky'
version '1.0.0'
lua54 'yes'

escrow 'yes'
ui_page 'web/index.html'


files {
    'web/index.html',
    'web/assets/*',
    'web/clothing/*.png',
    'web/logo.png',
    'web/sw.js'
}

client_scripts {
    'client/cl_framework.lua',
    'client/cl_camera.lua',
    'client/cl_shop.lua',
    'client/cl_clothing.lua',
    'client/cl_main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_*.lua',
}

shared_scripts {
    'shared/config.lua',
}

escrow_ignore {
    'shared/config.lua'
}


dependency '/assetpacks'
dependency '/assetpacks'