--========================================================
-- nvCloth – Utils (Framework / Appearance / Notifications)
--========================================================

-- Framework bootstrap (ESX / QBCore)
do
  if Config.Framework == "esx" then
    local esx = exports["es_extended"]
    ESX = esx:getSharedObject()
  elseif Config.Framework == "qbcore" then
    local qb = exports["qb-core"]
    QBCore = qb:GetCoreObject()
  end
end

--========================================================
-- NOTIFICATIONS
--========================================================

--- Affiche une notification simple selon le framework
---@param msg string
function showNotification(msg)
  if Config.Framework == "esx" and ESX and ESX.ShowNotification then
    ESX.ShowNotification(msg)
  elseif Config.Framework == "qbcore" and QBCore and QBCore.Functions and QBCore.Functions.Notify then
    QBCore.Functions.Notify(msg, "primary")
  end
end

--- Affiche une “help notification” (hint) à l’écran
---@param msg string
function showHelpNotification(msg)
  if Config.Framework == "esx" and ESX and ESX.ShowHelpNotification then
    ESX.ShowHelpNotification(msg)
  else
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
  end
end

--========================================================
-- APPEARANCE (lecture / écriture)
--========================================================

--- Récupère l’apparence du ped selon la ressource d’apparence utilisée
---@return table|nil
function getPedAppearance()
  local ped = PlayerPedId()

  if Config.AppearanceRessource == "illenium-appearance" then
    return exports["illenium-appearance"]:getPedAppearance(ped)

  elseif Config.AppearanceRessource == "fivem-appearance" then
    return exports["fivem-appearance"]:getPedAppearance(ped)

  elseif Config.AppearanceRessource == "skinchanger" then
    -- skinchanger est event/callback-based -> on utilise promise + Await
    local p = promise.new()
    TriggerEvent("skinchanger:getSkin", function(skin)
      p:resolve(skin)
    end)
    return Citizen.Await(p)
  end
end

--- Applique une apparence sur le ped selon la ressource d’apparence
---@param appearance table
function savePedAppearance(appearance)
  local ped = PlayerPedId()

  if Config.AppearanceRessource == "illenium-appearance" then
    exports["illenium-appearance"]:setPedAppearance(ped, appearance)

  elseif Config.AppearanceRessource == "fivem-appearance" then
    exports["fivem-appearance"]:setPedAppearance(ped, appearance)

  elseif Config.AppearanceRessource == "skinchanger" then
    TriggerEvent("skinchanger:loadSkin", appearance)
  end

  -- Intégrations éventuelles avec l’inventaire
  if Config.Inventory == "core-inventory" then
    exports.core_inventory:addClothingItemFromPedSkinInInventory(PlayerPedId(), false, true, true)
  end

  if Config.Inventory == "qs-inventory" then
    exports["qs-inventory"]:setInClothing(false)
  end
end

--========================================================
-- NUI CALLBACKS
--========================================================

-- Renvoie le genre (male/female) au NUI
RegisterNUICallback("getGender", function(_, cb)
  local ped = PlayerPedId()

  -- Cas skinchanger : on infère via le model du ped
  if Config.AppearanceRessource == "skinchanger" then
    local model = GetEntityModel(ped)
    local maleHash = GetHashKey("mp_m_freemode_01")
    local gender = (model == maleHash) and "male" or "female"
    cb({ gender = gender })
    return
  end

  -- Autres ressources d’apparence : on lit l’apparence
  local app = nil
  if Config.AppearanceRessource == "illenium-appearance" then
    app = exports["illenium-appearance"]:getPedAppearance(ped)
  elseif Config.AppearanceRessource == "fivem-appearance" then
    app = exports["fivem-appearance"]:getPedAppearance(ped)
  end

  -- app.model pour illenium/fivem-appearance
  local gender = (app and app.model == "mp_m_freemode_01") and "male" or "female"
  cb({ gender = gender })
end)

--========================================================
-- PLAYER LOADED FLAGS (ESX / QBCore)
--========================================================

loaded = false

-- QBCore
RegisterNetEvent("QBCore:Client:OnPlayerLoaded", function()
  loaded = true
end)

-- ESX
RegisterNetEvent("esx:playerLoaded", function()
  loaded = true
end)

--========================================================
-- RELAY NOTIFICATION EVENT
--========================================================

-- Utilisation: TriggerClientEvent("nvCloth:showNotification", src, type, duration, message)
RegisterNetEvent("nvCloth:showNotification")
AddEventHandler("nvCloth:showNotification", function(_type, _duration, message)
  -- le code source appelait showNotification avec le 3e paramètre (message)
  showNotification(message)
end)
