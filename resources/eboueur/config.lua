-- Configuration pour la ressource eboueur
Config = {}

-- Points de spawn garage pour le camion
Config.Garage = vector3( -350.0, -1567.0, 25.2 ) -- exemple, modifier selon serveur

-- Modèle du camion poubelle
Config.TruckModel = 'trash' -- 'trash', 'trash2'


-- Types de poubelles et points de mission avancés
Config.BinTypes = {
    normal = { label = "Poubelle classique", xp = 10, reward = 0 },
    recycle = { label = "Recyclage", xp = 15, reward = 50 },
    toxic = { label = "Déchets toxiques", xp = 25, reward = 100 },
}


-- Missions avancées par zone
Config.AdvancedMissions = {
    ["Mission Row"] = {
        { pos = vector3(452.0, -981.0, 30.7), type = "normal" },
        { pos = vector3(440.0, -975.0, 30.7), type = "recycle" },
        { pos = vector3(428.0, -984.0, 30.7), type = "toxic" },
    },
    ["Mirror Park"] = {
        { pos = vector3(1035.0, -765.0, 57.9), type = "normal" },
        { pos = vector3(1050.0, -800.0, 58.0), type = "recycle" },
        { pos = vector3(1000.0, -750.0, 58.0), type = "toxic" },
    },
    ["Place des Cubes"] = {
        { pos = vector3(-1200.0, -1560.0, 4.0), type = "normal" },
        { pos = vector3(-1210.0, -1570.0, 4.0), type = "recycle" },
        { pos = vector3(-1220.0, -1580.0, 4.0), type = "toxic" },
    },
    ["Sandy Shores"] = {
        { pos = vector3(1950.0, 3730.0, 32.0), type = "normal" },
        { pos = vector3(1970.0, 3750.0, 32.0), type = "recycle" },
        { pos = vector3(1990.0, 3770.0, 32.0), type = "toxic" },
    },
}

-- XP gagnée par collecte
Config.XPPerPickup = 10

-- XP requis par niveau (exponentiel simple)
Config.XPForLevel = function(level)
    return 100 + (level - 1) * 75
end

-- Durée de l'animation de ramassage (ms)
Config.CollectTime = 3000

-- Distances
Config.PickupRadius = 3.0

-- Job restriction: only players whose job is 'citizen' or no job
-- The script tries to detect ESX or QBCore jobs. Adjust as needed.

-- Wardrobe / tenue de travail (position et tenue à appliquer)
Config.Wardrobe = vector3(Config.Garage.x, Config.Garage.y, Config.Garage.z)

-- Exemple d'une tenue de travail (valeurs exemples, adaptez selon vos modèles)
-- components keys: 0-11, props keys: 0-7
Config.WorkOutfit = {
    components = {
        [3] = { drawable = 15, texture = 0 }, -- Torse
        [4] = { drawable = 14, texture = 0 }, -- Pantalon
        [6] = { drawable = 25, texture = 0 }, -- Chaussures
        [8] = { drawable = 58, texture = 0 }, -- Accessoires (ex: gilet)
    },
    props = {
        [0] = { prop = -1, texture = 0 }, -- Chapeaux
        [1] = { prop = -1, texture = 0 },
    }
}

-- Durée (ms) pour enfiler/retirer la tenue de travail
Config.ChangeOutfitTime = 2500

return Config
