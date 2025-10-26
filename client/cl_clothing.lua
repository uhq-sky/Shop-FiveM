--========================================================
-- nvCloth – Client (CLEAN)
-- - Prévisualisation et application de vêtements/props
-- - Compatible "skinchanger" (si Config.AppearanceRessource == "skinchanger")
-- - Callbacks NUI: sélection article, textures, reset, achat, etc.
-- - Événements: nvCloth:getClothes, nvCloth:resetClothes
-- - Envoi des “counts” (variations disponibles) au NUI au chargement
--========================================================

--========================================================
-- ÉTAT / CONFIG
--========================================================

outfitToBuy = nil

-- Map des champs skinchanger par catégorie (si utilisé)
local SKINCHANGER_FIELDS = {
  tshirt   = { d = "tshirt_1",  t = "tshirt_2"  },
  torso    = { d = "torso_1",   t = "torso_2"   },
  pants    = { d = "pants_1",   t = "pants_2"   },
  shoes    = { d = "shoes_1",   t = "shoes_2"   },
  arms     = { d = "arms"                        }, -- pas de texture
  chains   = { d = "chain_1",   t = "chain_2"   },
  mask     = { d = "mask_1",    t = "mask_2"    },
  bags     = { d = "bags_1",    t = "bags_2"    },
  hat      = { d = "helmet_1",  t = "helmet_2"  },
  glasses  = { d = "glasses_1", t = "glasses_2" },
  earrings = { d = "ears_1",    t = "ears_2"    },
  watches  = { d = "watches_1", t = "watches_2" },
}

--========================================================
-- HELPERS
--========================================================

--- Applique un changement via skinchanger (si activé), sinon renvoie false.
---@param category string
---@param drawable integer
---@param texture integer|nil
---@return boolean applied
local function ApplyWithSkinchanger(category, drawable, texture)
  if Config.AppearanceRessource ~= "skinchanger" then
    return false
  end

  local map = SKINCHANGER_FIELDS[category]
  if not map then return false end

  if map.d then
    TriggerEvent("skinchanger:change", map.d, drawable)
  end

  if map.t then
    TriggerEvent("skinchanger:change", map.t, texture or 0)
  end

  return true
end

--- Raccourci de notification localisée
local function notifyKey(key)
  local T = Config.Translations[Config.Lang]
  if showNotification and T and T[key] then
    showNotification(T[key])
  end
end

--- Extrait un tableau d’items depuis une charge utile hétérogène (cart/selected/outfit/etc.)
---@param payload table
---@return table items, string outfitName
local function extractItemsAndName(payload)
  local items = payload.items or payload.cart or payload.selectedItems or payload.selected
  if not items and payload.outfit and payload.outfit.items then
    items = payload.outfit.items
  end
  items = items or {}

  local name = payload.name
  if not name and payload.outfit and payload.outfit.name then
    name = payload.outfit.name
  end
  name = name or "Tenue"

  return items, name
end

--- Applique un item (component ou prop) selon la table `categories`
---@param ped number
---@param category string
---@param drawable integer
---@param texture integer
local function applyItem(ped, category, drawable, texture)
  local cat = categories[category]
  if not cat then
    notifyKey("invalid-category")
    return
  end

  if cat.type == "component" then
    -- D’abord essayer skinchanger
    if not ApplyWithSkinchanger(category, drawable, texture) then
      SetPedComponentVariation(ped, cat.index, drawable, texture, 0)
    end
  elseif cat.type == "prop" then
    if drawable ~= -1 then
      if not ApplyWithSkinchanger(category, drawable, texture) then
        SetPedPropIndex(ped, cat.index, drawable, texture, true)
      end
    else
      -- Clear prop
      if not ApplyWithSkinchanger(category, -1, 0) then
        ClearPedProp(ped, cat.index)
      end
    end
  end
end

--- Change uniquement la texture de l’élément actuellement porté dans la catégorie
---@param ped number
---@param category string
---@param texture integer
local function changeCurrentTexture(ped, category, texture)
  local cat = categories[category]
  if not cat then
    notifyKey("invalid-category")
    return
  end

  if cat.type == "prop" then
    local cur = GetPedPropIndex(ped, cat.index)
    if cur ~= -1 then
      if not ApplyWithSkinchanger(category, cur, texture) then
        SetPedPropIndex(ped, cat.index, cur, texture, true)
      end
    else
      -- rien porté -> clear
      if not ApplyWithSkinchanger(category, -1, 0) then
        ClearPedProp(ped, cat.index)
      end
    end
  else
    local cur = GetPedDrawableVariation(ped, cat.index)
    if not ApplyWithSkinchanger(category, cur, texture) then
      SetPedComponentVariation(ped, cat.index, cur, texture, 0)
    end
  end
end

--- Applique une tenue complète (items = { {category, drawable, texture}, ... })
---@param items table
local function setOutfit(items)
  local ped = PlayerPedId()
  for _, it in ipairs(items or {}) do
    if it.category and it.drawable ~= nil and it.texture ~= nil then
      applyItem(ped, it.category, it.drawable, it.texture)
    end
  end
end

--- Restaure une catégorie depuis `saveClothes[category]`
---@param ped number
---@param category string
local function restoreCategoryFromSaved(ped, category)
  local cat = categories[category]
  if not (cat and saveClothes and saveClothes[category]) then
    notifyKey("no-saved-outfit")
    return
  end

  local d = saveClothes[category].drawable
  local t = saveClothes[category].texture

  if cat.type == "prop" then
    if d ~= -1 then
      if not ApplyWithSkinchanger(category, d, t) then
        SetPedPropIndex(ped, cat.index, d, t, true)
      end
    else
      if not ApplyWithSkinchanger(category, -1, 0) then
        ClearPedProp(ped, cat.index)
      end
    end
  else
    if not ApplyWithSkinchanger(category, d, t) then
      SetPedComponentVariation(ped, cat.index, d, t, 0)
    end
  end
end

--- Attend que le modèle du joueur soit freemode (mp_m_freemode_01 / mp_f_freemode_01)
local function WaitForFreemodeModel()
  local tries, maxTries = 0, 1000
  while true do
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    if model == `mp_m_freemode_01` or model == `mp_f_freemode_01` then
      break
    end
    tries = tries + 1
    if tries >= maxTries then break end
    Wait(200)
  end
end

--========================================================
-- NUI: ACTIONS SUR ARTICLES
--========================================================

-- Applique l’article choisi et renvoie le nombre de textures possibles
RegisterNUICallback("sendSelectedArticle", function(data, cb)
  local ped = PlayerPedId()
  local cat = categories[data.category]
  local drawable = data.drawable
  local texture  = data.texture

  if not cat then
    notifyKey("invalid-category")
    cb({ success = false })
    return
  end
  if type(drawable) ~= "number" or type(texture) ~= "number" then
    showNotification("Valeurs de vêtement invalides.")
    cb({ success = false })
    return
  end

  -- Appliquer
  applyItem(ped, data.category, drawable, texture)

  -- Nombre de textures disponibles pour ce drawable
  local count
  if cat.type == "component" then
    count = GetNumberOfPedTextureVariations(ped, cat.index, drawable)
  else
    count = GetNumberOfPedPropTextureVariations(ped, cat.index, drawable)
  end
  cb({ count = count })
end)

-- Reset d’une catégorie depuis la sauvegarde locale `saveClothes`
RegisterNUICallback("resetCloth", function(data, cb)
  local category = data.category
  local ped = PlayerPedId()
  local cat = categories[category]

  if not cat then
    notifyKey("invalid-category")
    cb({ success = false })
    return
  end

  if not saveClothes or not saveClothes[category] then
    notifyKey("no-saved-outfit")
    cb({ success = false })
    return
  end

  restoreCategoryFromSaved(ped, category)
  cb({ success = true })
end)

-- Changement de texture de l’élément en cours
RegisterNUICallback("changeTexture", function(data, cb)
  local ped = PlayerPedId()
  local cat = categories[data.category]
  local texture = data.texture

  if not cat then
    notifyKey("invalid-category")
    cb({ success = false })
    return
  end

  changeCurrentTexture(ped, data.category, texture)
  cb({ success = true })
end)

-- Applique une tenue (prévisualisation ou finale)
RegisterNUICallback("setOutfit", function(data, cb)
  local ped = PlayerPedId()
  local outfit = data.outfit or {}
  setOutfit(outfit)

  if not data.preview then
    notifyKey("outfit-applied")
  end

  cb({ success = true })
end)

--========================================================
-- NUI: RESET / CLEAR (restaurent simplement la tenue sauvegardée)
--========================================================

local function resetToSaved(cb)
  setOutfit(saveClothes)
  cb({ success = true })
end

RegisterNUICallback("resetAllClothes", resetToSaved)
RegisterNUICallback("resetCart",        resetToSaved)
RegisterNUICallback("clearCart",        resetToSaved)

RegisterNUICallback("reset", function(_, cb)
  setOutfit(saveClothes)
  cb("ok")
end)

RegisterNUICallback("clear", function(_, cb)
  setOutfit(saveClothes)
  cb("ok")
end)

RegisterNUICallback("resetCartItems", function(_, cb)
  setOutfit(saveClothes)
  cb("ok")
end)

RegisterNUICallback("clearCartItems", function(_, cb)
  setOutfit(saveClothes)
  cb("ok")
end)

--========================================================
-- ACHATS
--========================================================

local function buyCommon(data, payment)
  local items, name = extractItemsAndName(data)
  outfitToBuy = { items = items, name = name }
  TriggerServerEvent("nvCloth:buyClothes", payment, outfitToBuy)
end

RegisterNUICallback("buyClothes", function(data, cb)
  local method = data.paymentMethod
  if method == "card" then method = "bank" end -- compat UI
  buyCommon(data, method)
  cb("ok")
end)

RegisterNUICallback("buy", function(data, cb)
  local method = data.paymentMethod
  if method == "card" then method = "bank" end
  buyCommon(data, method)
  cb("ok")
end)

RegisterNUICallback("buyCash", function(data, cb)
  buyCommon(data, "cash")
  cb("ok")
end)

RegisterNUICallback("buyBank", function(data, cb)
  buyCommon(data, "bank")
  cb("ok")
end)

RegisterNUICallback("buyCard", function(data, cb)
  buyCommon(data, "card") -- côté serveur, traite "card" comme il faut si nécessaire
  cb("ok")
end)

--========================================================
-- EVENTS
--========================================================

-- Applique une tenue reçue du serveur
RegisterNetEvent("nvCloth:getClothes", function(payload)
  local ped = PlayerPedId()
  if not payload then return end

  local items = payload.items or {}
  for _, it in ipairs(items) do
    local cat = categories[it.category]
    if cat then
      -- Comme applyItem mais inline pour limiter appels
      if cat.type == "prop" then
        if it.drawable ~= -1 then
          if not ApplyWithSkinchanger(it.category, it.drawable, it.texture) then
            SetPedPropIndex(ped, cat.index, it.drawable, it.texture, true)
          end
        else
          if not ApplyWithSkinchanger(it.category, -1, 0) then
            ClearPedProp(ped, cat.index)
          end
        end
      else
        if not ApplyWithSkinchanger(it.category, it.drawable, it.texture) then
          SetPedComponentVariation(ped, cat.index, it.drawable, it.texture, 0)
        end
      end
    end
  end
end)

-- Reset complet -> restore `saveClothes`
RegisterNetEvent("nvCloth:resetClothes", function()
  setOutfit(saveClothes)
end)

--========================================================
-- ENVOI DES COMPTEURS (variations) AU NUI
--========================================================

CreateThread(function()
  -- Attendre la session + le ped + freemode
  while true do
    if NetworkIsSessionStarted() and DoesEntityExist(PlayerPedId()) then
      break
    end
    Wait(100)
  end

  WaitForFreemodeModel()

  local ped = PlayerPedId()
  local counts = {}

  for key, cat in pairs(categories) do
    if cat.type == "component" then
      counts[key] = GetNumberOfPedDrawableVariations(ped, cat.index)
    elseif cat.type == "prop" then
      counts[key] = GetNumberOfPedPropDrawableVariations(ped, cat.index)
    end
  end

  SendNUIMessage({
    type   = "clothingCounts",
    counts = counts
  })
end)
