-- Stockage des zones personnalisées
local zonesFile = 'eboueur_zones.json'
local customZones = {}

local function hasOxmysql()
    return GetResourceState('oxmysql') == 'started' or (exports and exports['oxmysql'] ~= nil)
end

local function loadZonesFromFile()
    local f = io.open(zonesFile, 'r')
    if f then
        local content = f:read('*a')
        f:close()
        local ok, d = pcall(function() return json.decode(content) end)
        if ok and d then customZones = d end
    end
end

local function saveZonesToFile()
    local f = io.open(zonesFile, 'w+')
    if f then
        f:write(json.encode(customZones))
        f:close()
    end
end

local function loadZonesFromDB()
    if not hasOxmysql() then return end
    exports.oxmysql:execute('SELECT name, data FROM eboueur_zones', {}, function(rows)
        if rows then
            for _, r in ipairs(rows) do
                local ok, d = pcall(function() return json.decode(r.data) end)
                if ok and d then customZones[r.name] = d end
            end
            print('[eboueur] Zones chargées depuis la base (oxmysql).')
        end
    end)
end

local function saveZonesToDB()
    if not hasOxmysql() then return end
    for name, data in pairs(customZones) do
        local encoded = json.encode(data)
        exports.oxmysql:execute('INSERT INTO eboueur_zones (`name`, `data`) VALUES (@name, @data) ON DUPLICATE KEY UPDATE `data` = @data', {['@name']=name, ['@data']=encoded})
    end
    print('[eboueur] Zones sauvegardées dans la base (oxmysql).')
end

-- Sauvegarde des zones personnalisées depuis le client
RegisterServerEvent('eboueur:saveAllZones')
AddEventHandler('eboueur:saveAllZones', function(zones)
    if type(zones) == 'table' then
        customZones = zones
        if hasOxmysql() then
            saveZonesToDB()
        else
            saveZonesToFile()
        end
        print('[eboueur] Zones personnalisées sauvegardées')
    end
end)

-- Server debug/admin commands
RegisterCommand('eboueur_savezones', function(source, args, raw)
    -- source == 0 means console
    if source == 0 or IsPlayerAceAllowed(source, 'command') then
        if hasOxmysql() then
            saveZonesToDB()
        else
            saveZonesToFile()
        end
        print(('[eboueur] Zones sauvegardées manuellement par %s'):format(tostring(source)))
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1EBOUEUR', 'Permission refusée.' } })
    end
end, false)

RegisterCommand('eboueur_dumpplayers', function(source, args, raw)
    if source == 0 or IsPlayerAceAllowed(source, 'command') then
        if hasOxmysql() then
            exports.oxmysql:execute('SELECT identifier, xp, level FROM eboueur_players', {}, function(rows)
                if rows and #rows > 0 then
                    for _, r in ipairs(rows) do
                        print(('[eboueur] Player: %s xp=%s level=%s'):format(tostring(r.identifier), tostring(r.xp), tostring(r.level)))
                    end
                else
                    print('[eboueur] Aucun joueur trouvé dans eboueur_players.')
                end
            end)
        else
            for id, pdata in pairs(playerData) do
                print(('[eboueur] Player: %s xp=%s level=%s'):format(tostring(id), tostring(pdata.xp), tostring(pdata.level)))
            end
        end
    else
        TriggerClientEvent('chat:addMessage', source, { args = { '^1EBOUEUR', 'Permission refusée.' } })
    end
end, false)

-- Envoi des zones personnalisées à un client
RegisterNetEvent('eboueur:requestZones')
AddEventHandler('eboueur:requestZones', function()
    local src = source
    if hasOxmysql() then
        exports.oxmysql:execute('SELECT name, data FROM eboueur_zones', {}, function(rows)
            if rows then
                local tz = {}
                for _, r in ipairs(rows) do
                    local ok, d = pcall(function() return json.decode(r.data) end)
                    if ok and d then tz[r.name] = d end
                end
                TriggerClientEvent('eboueur:receiveZones', src, tz)
                return
            end
            TriggerClientEvent('eboueur:receiveZones', src, customZones)
        end)
    else
        TriggerClientEvent('eboueur:receiveZones', src, customZones)
    end
end)

-- Charger les zones au démarrage
AddEventHandler('onResourceStart', function(name)
    if GetCurrentResourceName() == name then
        if hasOxmysql() then
            loadZonesFromDB()
        else
            loadZonesFromFile()
        end
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

-- DB helpers for player data using oxmysql
local function getPlayerIdentifier(src)
    -- Try QBCore / ESX for persistent identifier, fallback to server id
    local ok, QBCore = pcall(function() return exports['qb-core'] and exports['qb-core']:GetCoreObject() end)
    if ok and QBCore then
        local success, Player = pcall(function() return QBCore.Functions.GetPlayer(src) end)
        if success and Player and Player.PlayerData and Player.PlayerData.citizenid then
            return 'citizenid:' .. tostring(Player.PlayerData.citizenid)
        end
    end
    local ok2, ESX = pcall(function() return exports['es_extended'] and exports['es_extended']:getSharedObject() end)
    if ok2 and ESX then
        local xPlayer = ESX.GetPlayerFromId and ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.identifier then
            return tostring(xPlayer.identifier)
        end
    end
    return 'serverid:' .. tostring(src)
end

local function loadPlayerFromDB(identifier, cb)
    if not hasOxmysql() then cb(nil) return end
    exports.oxmysql:execute('SELECT xp, level FROM eboueur_players WHERE identifier = @identifier', {['@identifier']=identifier}, function(rows)
        if rows and #rows > 0 then
            cb({ xp = rows[1].xp or 0, level = rows[1].level or 1 })
        else
            cb(nil)
        end
    end)
end

local function savePlayerToDB(identifier, pdata)
    if not hasOxmysql() or not identifier or not pdata then return end
    exports.oxmysql:execute('INSERT INTO eboueur_players (`identifier`, `xp`, `level`) VALUES (@identifier, @xp, @level) ON DUPLICATE KEY UPDATE `xp` = @xp, `level` = @level', {['@identifier']=identifier, ['@xp']=pdata.xp or 0, ['@level']=pdata.level or 1})
end

AddEventHandler('onResourceStart', function(name)
    if GetCurrentResourceName() == name then
        loadData()
    end
end)

-- Tentative d'enregistrement du job dans QBCore (si présent)
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and QBCore and QBCore.Shared and QBCore.Shared.Jobs then
        if not QBCore.Shared.Jobs['eboueur'] then
            QBCore.Shared.Jobs['eboueur'] = {
                label = 'Eboueur',
                grades = {
                    ['0'] = { name = 'Recrue', payment = 50 },
                    ['1'] = { name = 'Éboueur', payment = 75 },
                    ['2'] = { name = 'Chef', payment = 150, isboss = true },
                }
            }
            print('[eboueur] Job "eboueur" ajouté à QBCore.Shared.Jobs (temporaire).')
        else
            print('[eboueur] Le job "eboueur" existe déjà dans QBCore.Shared.Jobs.')
        end
    else
        print('[eboueur] QBCore non détecté ou version incompatible — ajoutez manuellement le job dans qb-core/shared/jobs.lua si nécessaire.')
    end
end)

-- Donne de l'argent comme récompense (server-side), compatible QBCore si présent
RegisterServerEvent('eboueur:giveReward')
AddEventHandler('eboueur:giveReward', function(amount)
    local src = source
    if type(amount) ~= 'number' then return end
    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddMoney('bank', amount, 'eboueur-reward')
            -- Notification côté client
            local successNotify, _ = pcall(function()
                TriggerClientEvent('QBCore:Notify', src, 'Vous avez reçu $'..tostring(amount), 'success')
            end)
            if not successNotify then
                TriggerClientEvent('chat:addMessage', src, { args = { '^2EBOUEUR', 'Vous avez reçu $'..tostring(amount) } })
            end
            -- Log serveur
            print(('[eboueur] Récompense distribuée: joueur=%s montant=%s'):format(tostring(src), tostring(amount)))
            return
        end
    end
    -- Fallback : envoyer événement qu'un script tiers peut écouter pour donner de l'argent
    print(('[eboueur] QBCore non disponible pour verser $%s au joueur %s — déclenchement du fallback.'):format(tostring(amount), tostring(src)))
    TriggerEvent('eboueur:giveReward_fallback', src, amount)
end)

-- Fallback handler: essayer ESX puis log si aucun système monétaire détecté
RegisterNetEvent('eboueur:giveReward_fallback')
AddEventHandler('eboueur:giveReward_fallback', function(targetSrc, amount)
    local src = targetSrc or source
    if type(amount) ~= 'number' then return end
    local given = false

    -- Try ESX (es_extended)
    local ok, ESX = pcall(function() return exports['es_extended'] and exports['es_extended']:getSharedObject() end)
    if ok and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            -- Try common methods to give money
            if xPlayer.addAccountMoney then
                xPlayer.addAccountMoney('bank', amount)
            elseif xPlayer.addMoney then
                xPlayer.addMoney(amount)
            elseif xPlayer.addBank then
                xPlayer.addBank(amount)
            end
            TriggerClientEvent('chat:addMessage', src, { args = { '^2EBOUEUR', 'Vous avez reçu $'..tostring(amount) } })
            print(('[eboueur] Récompense (ESX) distribuée: joueur=%s montant=%s'):format(tostring(src), tostring(amount)))
            given = true
        end
    end

    if not given then
        -- Aucun système détecté : log pour action manuelle ou extension
        print(('[eboueur] Aucun système monétaire détecté. Impossible de verser $%s au joueur %s.'):format(tostring(amount), tostring(src)))
    end
end)

-- ensure structure for a player
local function ensurePlayer(src, identifier)
    if not playerData[identifier] then
        playerData[identifier] = { xp = 0, level = 1 }
        saveData()
        -- Persist to DB if available
        savePlayerToDB(identifier, playerData[identifier])
    end
    return playerData[identifier]
end

-- Add XP and check level up
RegisterServerEvent('eboueur:addXP')
AddEventHandler('eboueur:addXP', function(amount)
    local src = source
    if type(amount) ~= 'number' then return end
    local identifier = getPlayerIdentifier(src)

    local function processAdd(pdata)
        pdata.xp = (pdata.xp or 0) + amount
        local nextXP = Config.XPForLevel(pdata.level + 1)
        while pdata.xp >= nextXP do
            pdata.xp = pdata.xp - nextXP
            pdata.level = pdata.level + 1
            nextXP = Config.XPForLevel(pdata.level + 1)
            TriggerClientEvent('eboueur:levelUp', src, pdata.level)
        end
        playerData[identifier] = pdata
        saveData()
        savePlayerToDB(identifier, pdata)
        TriggerClientEvent('eboueur:updateData', src, pdata)
    end

    if not playerData[identifier] then
        if hasOxmysql() then
            loadPlayerFromDB(identifier, function(d)
                if d then
                    processAdd(d)
                else
                    processAdd({ xp = 0, level = 1 })
                end
            end)
            return
        else
            local p = ensurePlayer(src, identifier)
            processAdd(p)
            return
        end
    else
        processAdd(playerData[identifier])
    end
end)

-- Provide data on request
RegisterServerEvent('eboueur:requestData')
AddEventHandler('eboueur:requestData', function()
    local src = source
    local src = source
    local identifier = getPlayerIdentifier(src)
    local system = Config and Config.CurrencySystem or 'auto'

    -- Load player data from DB if available, otherwise use in-memory/file fallback
    if hasOxmysql() then
        loadPlayerFromDB(identifier, function(d)
            if d then
                playerData[identifier] = d
            else
                if not playerData[identifier] then playerData[identifier] = { xp = 0, level = 1 } end
            end
            TriggerClientEvent('eboueur:updateData', src, playerData[identifier])
        end)
        return
    else
        if not playerData[identifier] then playerData[identifier] = { xp = 0, level = 1 } end
        TriggerClientEvent('eboueur:updateData', src, playerData[identifier])
        return
    end
