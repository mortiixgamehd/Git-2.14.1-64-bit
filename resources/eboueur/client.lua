-- Synchronisation des zones personnalisées serveur au panel
RegisterNetEvent('eboueur:receiveZones')
AddEventHandler('eboueur:receiveZones', function(zones)
    if type(zones) == 'table' then
        -- stocker localement et envoyer à la NUI pour mise à jour
        local serverZones = zones
        SendNUIMessage({ action = 'updateZones', zones = serverZones })
    end
end)

-- Demande des zones serveur à l'ouverture du panel
RegisterCommand('eboueur_synczones', function()
    TriggerServerEvent('eboueur:requestZones')
end)
-- NUI callback pour sauvegarder toutes les zones personnalisées côté serveur
RegisterNUICallback('saveAllZones', function(data, cb)
    if not data or not data.zones then cb({ ok = false }) return end
    TriggerServerEvent('eboueur:saveAllZones', data.zones)
    cb({ ok = true })
end)
local QBCore = nil
local ESX = nil
-- Config est fourni par `config.lua` (shared_script)
local Config = Config

-- Try to detect frameworks
Citizen.CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        pcall(function() QBCore = exports['qb-core']:GetCoreObject() end)
    end
    if not QBCore and GetResourceState('es_extended') == 'started' then
        pcall(function() ESX = exports['es_extended']:getSharedObject() end)
    end
    -- detect qb-clothing presence
    if GetResourceState('qb-clothing') == 'started' then
        print('[eboueur] qb-clothing detected')
    end
end)

-- Local mission state
local inMission = false
local currentTargets = {}
local truck = nil
local wearingWorkOutfit = false
local originalOutfit = nil

-- Helper: check if player is 'citizen' (simple heuristic)
local function IsCitizen()
    if QBCore then
        local playerData = QBCore.Functions.GetPlayerData()
        local job = nil
        if playerData and playerData.job then
            job = playerData.job.name or playerData.job
        end
        -- Consider 'unemployed' or 'citizen' as allowed
        if not job or job == 'citizen' or job == 'unemployed' then
            return true
        end
        return false
    elseif ESX then
        local playerData = ESX.GetPlayerData and ESX.GetPlayerData()
        local job = nil
        if playerData and playerData.job then
            job = playerData.job.name or playerData.job
        end
        if not job or job == 'citizen' or job == 'unemployed' then
            return true
        end
        return false
    else
        -- If no framework found, allow by default (adjust if needed)
        return true
    end
end

-- UI open
local uiOpen = false
RegisterCommand('eboueur_ui', function()
    toggleUI()
end)

function toggleUI()
    uiOpen = not uiOpen
    SetNuiFocus(uiOpen, uiOpen)
    SendNUIMessage({ action = 'toggle', open = uiOpen })
    if uiOpen then
        TriggerServerEvent('eboueur:requestData')
        TriggerServerEvent('eboueur:requestZones') -- Synchronisation auto des zones personnalisées
        -- envoyer l'état actuel des toggles au NUI
        SendNUIMessage({ action = 'updateSettings', jobBlipVisible = jobBlipVisible, garageMarkerVisible = garageMarkerVisible })
    end
end

-- Tenue de travail: sauvegarde et application
local function saveCurrentOutfit()
    local ped = PlayerPedId()
    originalOutfit = { comps = {}, props = {} }
    for i = 0, 11 do
        originalOutfit.comps[i] = { drawable = GetPedDrawableVariation(ped, i), texture = GetPedTextureVariation(ped, i), palette = 0 }
    end
    for i = 0, 7 do
        originalOutfit.props[i] = { prop = GetPedPropIndex(ped, i), texture = GetPedPropTextureIndex(ped, i) }
    end
end

local function applyWorkOutfit()
    local ped = PlayerPedId()
    if not originalOutfit then saveCurrentOutfit() end
    -- Animation + durée lors de l'enfilage
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    Citizen.Wait(Config.ChangeOutfitTime or 2000)
    ClearPedTasks(ped)
    -- Try qb-clothing integration first (many servers expose events/exports differently).
    local applied = false
    if GetResourceState('qb-clothing') == 'started' and Config.WorkOutfit and type(Config.WorkOutfit) == 'table' then
        local ok, err = pcall(function()
            -- Try common client events (best-effort). If any exists it should apply the outfit.
            TriggerEvent('qb-clothing:client:loadOutfit', Config.WorkOutfit)
            TriggerEvent('qb-clothing:client:LoadOutfit', Config.WorkOutfit)
            -- Some servers provide client exports to apply outfit
            if exports and exports['qb-clothing'] then
                pcall(function() exports['qb-clothing']:loadOutfit(Config.WorkOutfit) end)
                pcall(function() exports['qb-clothing']:ApplyPlayerOutfit(Config.WorkOutfit) end)
            end
        end)
        applied = ok
        if not ok then
            print('[eboueur] qb-clothing apply attempt failed: ' .. tostring(err))
        end
    end
    -- Fallback: apply directly if qb-clothing not present or failed
    if not applied then
        if Config.WorkOutfit and Config.WorkOutfit.components then
            for k, v in pairs(Config.WorkOutfit.components) do
                SetPedComponentVariation(ped, k, v.drawable or 0, v.texture or 0, v.palette or 0)
            end
        end
        if Config.WorkOutfit and Config.WorkOutfit.props then
            for k, v in pairs(Config.WorkOutfit.props) do
                if v.prop and v.prop >= 0 then
                    SetPedPropIndex(ped, k, v.prop, v.texture or 0, true)
                else
                    ClearPedProp(ped, k)
                end
            end
        end
    end
    -- If qb-clothing present try to save this outfit as 'Eboueur' on the server (guarded)
    if type(saveOutfitToQbClothing) == 'function' and Config.WorkOutfit then
        local ok, err = pcall(saveOutfitToQbClothing, Config.WorkOutfit)
        if not ok then
            print('[eboueur] saveOutfitToQbClothing failed: ' .. tostring(err))
        end
    end
    FreezeEntityPosition(ped, false)
    wearingWorkOutfit = true
    TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Tenue de travail appliquée.' } })
end

-- Tentative de sauvegarde automatique de la tenue via qb-clothing (server event/export)
local function saveOutfitToQbClothing(outfit)
    if not outfit or type(outfit) ~= 'table' then
        print('[eboueur] saveOutfitToQbClothing: outfit is nil or not a table, skipping save')
        return false
    end
    -- Try explicit clothing event used by some qb-clothing versions
    if GetResourceState('qb-clothing') == 'started' or GetResourceState('clothing') == 'started' then
        local saved = false
        local ok, err = pcall(function()
            TriggerServerEvent('clothing:server:SaveOutfit', 'Eboueur', outfit)
            saved = true
        end)
        if not ok then
            -- fallback to other common event names
            local ok2, err2 = pcall(function()
                TriggerServerEvent('qb-clothing:server:saveOutfit', 'Eboueur', outfit)
                saved = true
            end)
            if not ok2 then
                local ok3, err3 = pcall(function()
                    TriggerServerEvent('qb-clothing:saveOutfit', 'Eboueur', outfit)
                    saved = true
                end)
                if not ok3 then
                    print('[eboueur] qb-clothing save attempts failed: ' .. tostring(err) .. ' / ' .. tostring(err2) .. ' / ' .. tostring(err3))
                end
            end
        end
        if saved then
            TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Tenue Eboueur sauvegardée (qb-clothing).' } })
        end
        return saved
    end
    return false
end

local function restoreOutfit()
    local ped = PlayerPedId()
    if not originalOutfit then return end
    -- Animation + durée lors du retrait
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    Citizen.Wait(Config.ChangeOutfitTime or 2000)
    ClearPedTasks(ped)
    -- If qb-clothing present try to restore via its API (best-effort)
    local restored = false
    if GetResourceState('qb-clothing') == 'started' then
        local ok, err = pcall(function()
            -- Try events/exports to restore the saved original outfit
            TriggerEvent('qb-clothing:client:loadOutfit', originalOutfit)
            TriggerEvent('qb-clothing:client:LoadOutfit', originalOutfit)
            if exports and exports['qb-clothing'] then
                pcall(function() exports['qb-clothing']:loadOutfit(originalOutfit) end)
                pcall(function() exports['qb-clothing']:ApplyPlayerOutfit(originalOutfit) end)
            end
        end)
        restored = ok
        if not ok then
            print('[eboueur] qb-clothing restore attempt failed: ' .. tostring(err))
        end
    end
    -- Fallback: restore saved components/props
    if not restored then
        for i = 0, 11 do
            local c = originalOutfit.comps[i]
            if c then SetPedComponentVariation(ped, i, c.drawable, c.texture, c.palette or 0) end
        end
        for i = 0, 7 do
            local p = originalOutfit.props[i]
            if p and p.prop and p.prop >= 0 then
                SetPedPropIndex(ped, i, p.prop, p.texture or 0, true)
            else
                ClearPedProp(ped, i)
            end
        end
    end
    FreezeEntityPosition(ped, false)
    wearingWorkOutfit = false
    TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Tenue de travail retirée.' } })
end

-- NUI callbacks
RegisterNUICallback('startMission', function(data, cb)
    if not IsCitizen() then
        cb({ ok = false, msg = 'Job réservé aux citoyens' })
        return
    end
    if data.custom and type(data.custom) == 'table' and #data.custom > 0 then
        -- Mission personnalisée
        inMission = true
        currentTargets = {}
        for i, v in ipairs(data.custom) do
            currentTargets[i] = { pos = vector3(v.pos.x, v.pos.y, v.pos.z), type = v.type }
        end
        spawnTruck()
        CreateTargetsBlips()
        TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Mission personnalisée : '..(data.zone or 'zone')..'. Nettoyez tous les points !' } })
        cb({ ok = true })
        return
    end
    local zone = data.zone or "Mission Row"
    startAdvancedMission(zone)
    cb({ ok = true })
end)

RegisterNUICallback('close', function(data, cb)
    toggleUI()
    cb({ ok = true })
end)

-- Receive server data updates
RegisterNetEvent('eboueur:updateData', function(pdata)
    SendNUIMessage({ action = 'updateData', data = pdata })
end)

RegisterNetEvent('eboueur:levelUp', function(level)
    -- simple notification
    TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Niveau atteint: ' .. tostring(level) } })
end)

-- Mission control
-- Nouvelle fonction pour choisir une zone de mission avancée
function startAdvancedMission(zoneName)
    if inMission then return end
    local zonePoints = Config.AdvancedMissions[zoneName]
    if not zonePoints then
        TriggerEvent('chat:addMessage', { args = { '^1EBOUEUR', 'Zone inconnue.' } })
        return
    end
    inMission = true
    currentTargets = {}
    for i, v in ipairs(zonePoints) do
        currentTargets[i] = { pos = v.pos, type = v.type }
    end
    spawnTruck()
    CreateTargetsBlips()
    TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Mission avancée : '..zoneName..'. Nettoyez tous les points !' } })
end

-- Pour compatibilité, startMission lance la mission sur Mission Row par défaut
function startMission()
    startAdvancedMission("Mission Row")
end

function endMission()
    inMission = false
    currentTargets = {}
    if truck and DoesEntityExist(truck) then
        SetEntityAsMissionEntity(truck, true, true)
        DeleteVehicle(truck)
        truck = nil
    end
    RemoveTargetsBlips()
    TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Mission terminée.' } })
end

-- Truck spawn
function spawnTruck()
    local model = GetHashKey(Config.TruckModel)
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(10) end
    local spawnPos = Config.Garage
    truck = CreateVehicle(model, spawnPos.x, spawnPos.y, spawnPos.z, 90.0, true, false)
    SetVehicleNumberPlateText(truck, 'EBOUEUR')
    SetEntityAsMissionEntity(truck, true, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), truck, -1)
end

-- Blips management
local targetBlips = {}
local jobBlip = nil
local jobBlipVisible = true
local garageMarkerVisible = true
local targetZones = {}

local function CreateJobBlip()
    if not jobBlipVisible then return end
    if jobBlip and DoesBlipExist(jobBlip) then return end
    local g = Config.Garage
    jobBlip = AddBlipForCoord(g.x, g.y, g.z)
    SetBlipSprite(jobBlip, Config.JobBlip.sprite or 318)
    SetBlipColour(jobBlip, Config.JobBlip.color or 5)
    SetBlipScale(jobBlip, Config.JobBlip.scale or 0.9)
    SetBlipAsShortRange(jobBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.JobBlip.name or 'Job Éboueur')
    EndTextCommandSetBlipName(jobBlip)
end

local function RemoveJobBlip()
    if jobBlip and DoesBlipExist(jobBlip) then
        RemoveBlip(jobBlip)
        jobBlip = nil
    end
end
function CreateTargetsBlips()
    for i, v in ipairs(currentTargets) do
        local blip = AddBlipForCoord(v.pos.x, v.pos.y, v.pos.z)
        local binType = v.type or "normal"
        local sprite = 318
        local color = 5
        if binType == "recycle" then color = 2 end
        if binType == "toxic" then color = 46 end
        SetBlipSprite(blip, sprite)
        SetBlipColour(blip, color)
        SetBlipScale(blip, 0.8)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.BinTypes[binType].label .. ' #' .. tostring(i))
        EndTextCommandSetBlipName(blip)
        table.insert(targetBlips, blip)
        -- Register qb-target zone for this point if available
        if GetResourceState('qb-target') == 'started' then
            local zoneName = 'eboueur_point_' .. tostring(i) .. '_' .. tostring(math.random(1000,9999))
            targetZones[#targetZones+1] = zoneName
            local ok, err = pcall(function()
                exports['qb-target']:AddCircleZone(zoneName, v.pos, Config.PickupRadius or 3.0, {
                    name = zoneName,
                    debugPoly = false
                }, {
                    options = {
                        {
                            event = 'eboueur:client:collectPoint',
                            icon = 'fas fa-dumpster',
                            label = 'Ramasser'
                        }
                    },
                    distance = 3.5
                })
            end)
            if not ok then
                print('[eboueur] qb-target AddCircleZone failed: ' .. tostring(err))
            end
        end
    end
end

-- Create job blip on resource start
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    jobBlipVisible = Config.JobBlip.enabled ~= false
    garageMarkerVisible = Config.GarageMarker.enabled ~= false
    if jobBlipVisible then CreateJobBlip() end
end)

-- Remove job blip on resource stop (cleanup)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        RemoveJobBlip()
    end
end)

-- NUI callbacks pour toggle Blip/Marker
RegisterNUICallback('toggleBlip', function(data, cb)
    if data and type(data.visible) == 'boolean' then
        jobBlipVisible = data.visible
        if jobBlipVisible then CreateJobBlip() else RemoveJobBlip() end
        -- envoyer mise à jour aux NUI
        SendNUIMessage({ action = 'updateSettings', jobBlipVisible = jobBlipVisible, garageMarkerVisible = garageMarkerVisible })
        cb({ ok = true })
        return
    end
    cb({ ok = false })
end)

RegisterNUICallback('toggleMarker', function(data, cb)
    if data and type(data.visible) == 'boolean' then
        garageMarkerVisible = data.visible
        SendNUIMessage({ action = 'updateSettings', jobBlipVisible = jobBlipVisible, garageMarkerVisible = garageMarkerVisible })
        cb({ ok = true })
        return
    end
    cb({ ok = false })
end)

-- Draw garage marker when enabled
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if garageMarkerVisible then
            local ped = PlayerPedId()
            local ppos = GetEntityCoords(ped)
            local dist = #(ppos - Config.Garage)
            if dist < 50.0 then
                local m = Config.GarageMarker
                DrawMarker(m.type or 2, Config.Garage.x, Config.Garage.y, Config.Garage.z - 1.0, 0,0,0, 0,0,0, m.scale.x, m.scale.y, m.scale.z, m.color.r, m.color.g, m.color.b, m.color.a, false, false, 2, false, nil, nil, false)
            else
                Citizen.Wait(500)
            end
        else
            Citizen.Wait(500)
        end
    end
end)

function RemoveTargetsBlips()
    for _, b in ipairs(targetBlips) do
        RemoveBlip(b)
    end
    targetBlips = {}
    -- Remove qb-target zones
    if GetResourceState('qb-target') == 'started' then
        for _, zname in ipairs(targetZones) do
            local ok, err = pcall(function()
                if exports and exports['qb-target'] and exports['qb-target'].RemoveZone then
                    exports['qb-target']:RemoveZone(zname)
                else
                    -- Some versions expose a RemoveZone global function
                    pcall(function() exports['qb-target']:RemoveZone(zname) end)
                end
            end)
            if not ok then
                print('[eboueur] qb-target RemoveZone failed: ' .. tostring(err))
            end
        end
    end
    targetZones = {}
end

-- Handler called by qb-target interaction
RegisterNetEvent('eboueur:client:collectPoint')
AddEventHandler('eboueur:client:collectPoint', function()
    local ped = PlayerPedId()
    local ppos = GetEntityCoords(ped)
    for i, v in ipairs(currentTargets) do
        if v.pos and #(ppos - v.pos) <= (Config.PickupRadius or 3.0) then
            collectAt(i)
            return
        end
    end
    TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Aucun point à ramasser à proximité.' } })
end)

-- Main loop: check for player near targets and handle pickup
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local ped = PlayerPedId()
        local ppos = GetEntityCoords(ped)
        local distWard = #(ppos - Config.Wardrobe)
        if distWard <= 3.0 then
            DrawText3D(Config.Wardrobe.x, Config.Wardrobe.y, Config.Wardrobe.z + 0.5, '[E] Tenue de travail')
            if IsControlJustReleased(0, 38) then -- E
                if not wearingWorkOutfit then
                    applyWorkOutfit()
                else
                    restoreOutfit()
                end
            end
        end
        if inMission and #currentTargets > 0 then
            ped = PlayerPedId()
            ppos = GetEntityCoords(ped)
            for i, v in ipairs(currentTargets) do
                local dist = #(ppos - v)
                if dist <= Config.PickupRadius then
                    DrawText3D(v.x, v.y, v.z + 0.5, '[E] Ramasser')
                    if IsControlJustReleased(0, 38) then -- E
                        if truck and GetVehiclePedIsIn(ped, false) == truck then
                            collectAt(i)
                        else
                            TriggerEvent('chat:addMessage', { args = { '^2EBOUEUR', 'Vous devez être dans le camion pour ramasser.' } })
                        end
                    end
                end
            end
        end
    end
end)

function collectAt(index)
    local ped = PlayerPedId()
    local target = currentTargets[index]
    local binType = target and target.type or "normal"
    local binConf = Config.BinTypes[binType] or Config.BinTypes["normal"]
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_BUM_BIN', 0, true)
    Citizen.Wait(Config.CollectTime)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    -- give XP and reward
    TriggerServerEvent('eboueur:addXP', binConf.xp)
    if binConf.reward and binConf.reward > 0 then
        -- Donner la récompense côté serveur (argent)
        TriggerServerEvent('eboueur:giveReward', binConf.reward)
    end
    -- remove target
    table.remove(currentTargets, index)
    RemoveTargetsBlips()
    CreateTargetsBlips()
    if #currentTargets == 0 then
        endMission()
    end
end

-- Simple 3D text helper
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- NUI open key mapping (F6 example)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsControlJustReleased(0, 167) then -- F6
            toggleUI()
        end
    end
end)
