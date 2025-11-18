-- Stockage des zones personnalisées
local zonesFile = 'eboueur_zones.json'
local customZones = {}

local function loadZones()
    local f = io.open(zonesFile, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        local ok, d = pcall(function() return json.decode(content) end)
        if ok and d then customZones = d end
    end
end

local function saveZones()
    local f = io.open(zonesFile, 'w+')
    if f then
        f:write(json.encode(customZones))
        f:close()
    end
end

-- Sauvegarde des zones personnalisées depuis le client
RegisterServerEvent('eboueur:saveAllZones')
AddEventHandler('eboueur:saveAllZones', function(zones)
    if type(zones) == 'table' then
        customZones = zones
        saveZones()
        print('[eboueur] Zones personnalisées sauvegardées')
    end
end)

-- Envoi des zones personnalisées à un client
RegisterNetEvent('eboueur:requestZones')
AddEventHandler('eboueur:requestZones', function()
    local src = source
    TriggerClientEvent('eboueur:receiveZones', src, customZones)
end)

-- Charger les zones au démarrage
AddEventHandler('onResourceStart', function(name)
    if GetCurrentResourceName() == name then
        loadZones()
    end
end)
local jsonFile = 'eboueur_data.json'
local playerData = {}

-- Load/save helpers (simple file storage)
local function loadData()
    local f = io.open(jsonFile, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        local ok, d = pcall(function() return json.decode(content) end)
        if ok and d then playerData = d end
    end
end

local function saveData()
    local f = io.open(jsonFile, 'w+')
    if f then
        f:write(json.encode(playerData))
        f:close()
    end
end

AddEventHandler('onResourceStart', function(name)
    if GetCurrentResourceName() == name then
        loadData()
    end
end)

-- ensure structure for a player
local function ensurePlayer(src, identifier)
    if not playerData[identifier] then
        playerData[identifier] = { xp = 0, level = 1 }
        saveData()
    end
    return playerData[identifier]
end

-- Add XP and check level up
RegisterServerEvent('eboueur:addXP')
AddEventHandler('eboueur:addXP', function(amount)
    local src = source
    local identifier = tostring(src)
    local pdata = ensurePlayer(src, identifier)
    pdata.xp = pdata.xp + amount
    local nextXP = Config.XPForLevel(pdata.level + 1)
    while pdata.xp >= nextXP do
        pdata.xp = pdata.xp - nextXP
        pdata.level = pdata.level + 1
        nextXP = Config.XPForLevel(pdata.level + 1)
        TriggerClientEvent('eboueur:levelUp', src, pdata.level)
    end
    saveData()
    TriggerClientEvent('eboueur:updateData', src, pdata)
end)

-- Provide data on request
RegisterServerEvent('eboueur:requestData')
AddEventHandler('eboueur:requestData', function()
    local src = source
    local identifier = tostring(src)
    local pdata = ensurePlayer(src, identifier)
    TriggerClientEvent('eboueur:updateData', src, pdata)
end)

-- Simple admin command to reset data for a player (helpful during tests)
RegisterCommand('eboueur_resetme', function(source, args, raw)
    local src = source
    local identifier = tostring(src)
    playerData[identifier] = { xp = 0, level = 1 }
    saveData()
    TriggerClientEvent('eboueur:updateData', src, playerData[identifier])
end)
