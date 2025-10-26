-- nvCloth - serveur (version clean)
-- Remplace le fichier précédent contenant la "NEVA protection" agressive.

---------------------------------------
-- Dépendances optionnelles (ESX/QB) --
---------------------------------------
local ESX = nil
local QBCore = nil

CreateThread(function()
  if GetResourceState('es_extended') == 'started' then
    local ex = exports['es_extended']
    if ex and ex.getSharedObject then ESX = ex:getSharedObject() end
  end
  if not ESX and GetResourceState('qb-core') == 'started' then
    local qb = exports['qb-core']
    if qb and qb.GetCoreObject then QBCore = qb:GetCoreObject() end
  end
end)

--------------------------
-- Aide comptes/banque  --
--------------------------
local function getAccountMoneySafe(src, accountName)
  if type(accountName) ~= 'string' or accountName == '' then return 0 end

  -- ESX
  if ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
      if accountName == 'cash' or accountName == 'money' then
        return xPlayer.getMoney and xPlayer:getMoney() or 0
      end
      local acc = xPlayer.getAccount and xPlayer:getAccount(accountName)
      if acc and acc.money then return acc.money end
    end
  end

  -- QBCore
  if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData and Player.PlayerData.money then
      if Player.PlayerData.money[accountName] then
        return Player.PlayerData.money[accountName]
      end
      if accountName == 'cash' and Player.PlayerData.money['cash'] then
        return Player.PlayerData.money['cash']
      end
      if accountName == 'bank' and Player.PlayerData.money['bank'] then
        return Player.PlayerData.money['bank']
      end
    end
  end

  return 0
end

local function removeAccountMoneySafe(src, accountName, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return false end

  -- ESX
  if ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
      if accountName == 'cash' or accountName == 'money' then
        if xPlayer.removeMoney then xPlayer:removeMoney(amount) return true end
      else
        if xPlayer.removeAccountMoney then
          xPlayer:removeAccountMoney(accountName, amount)
          return true
        end
      end
    end
  end

  -- QBCore
  if QBCore and QBCore.Functions and QBCore.Functions.GetPlayer then
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.Functions and Player.Functions.RemoveMoney then
      return Player.Functions.RemoveMoney(accountName, amount, 'nvCloth purchase') or false
    end
  end

  return false
end

---------------------------------
-- Portail de sécurité "soft"  --
---------------------------------
-- [NEVA] Toutes les vérifications/portes de sécurité ont été supprimées.
-- Aucun blocage, aucun arrêt de ressource ni gate de connexion.

-------------------------------------------------
-- Achat de vêtements / inventaire / notifications
-------------------------------------------------
RegisterNetEvent('nvCloth:buyClothes')
AddEventHandler('nvCloth:buyClothes', function(method, outfit)
  local src = source
  if method == 'card' then method = 'bank' end

  local items = (outfit and outfit.items) or {}
  if type(items) ~= 'table' or #items == 0 then
    TriggerClientEvent('nvCloth:showNotification', src, 'fa-solid fa-circle-exclamation', 'red',
      (Config and Config.Translations and Config.Translations[Config.Lang] and Config.Translations[Config.Lang]['no-cloth-selected'])
      or 'Aucun vêtement sélectionné.')
    return
  end

  -- Calcul du prix total
  local total = 0
  for _, it in pairs(items) do
    local p = (Config and Config.Prices and Config.Prices[it.category]) or 0
    total = total + (tonumber(p) or 0)
  end

  -- Récup compte
  local accountName = (Config and Config.Accounts and Config.Accounts[method]) or method or 'cash'
  local balance = getAccountMoneySafe(src, accountName)
  if balance == nil then
    local msg = ('Compte invalide (%s/%s).'):format(tostring(accountName), tostring(method))
    if Config and Config.Translations and Config.Translations[Config.Lang] then
      local t = Config.Translations[Config.Lang]['account-error']
      if t then msg = (t):format(tostring(accountName), tostring(method)) end
    end
    TriggerClientEvent('nvCloth:showNotification', src, 'fa-solid fa-circle-exclamation', 'red', msg)
    return
  end

  if balance >= total then
    -- Débiter
    removeAccountMoneySafe(src, accountName, total)

    -- Appliquer immédiatement au joueur
    TriggerClientEvent('nvCloth:getClothes', src, outfit)

    -- Ajouter en inventaire BDD si configuré
    if Config and Config.Inventory and Config.Inventory ~= 'none' then
      for _, it in pairs(items) do
        local label = it.label or (it.category .. '_' .. tostring(it.drawable))
        local map = {
          tshirt   = { d='tshirt_1',  t='tshirt_2'  },
          torso    = { d='torso_1',   t='torso_2'   },
          pants    = { d='pants_1',   t='pants_2'   },
          shoes    = { d='shoes_1',   t='shoes_2'   },
          arms     = { d='arms'                     },
          chains   = { d='chain_1',   t='chain_2'   },
          mask     = { d='mask_1',    t='mask_2'    },
          bags     = { d='bags_1',    t='bags_2'    },
          hat      = { d='helmet_1',  t='helmet_2'  },
          glasses  = { d='glasses_1', t='glasses_2' },
          earrings = { d='ears_1',    t='ears_2'    },
          watches  = { d='watches_1', t='watches_2' },
        }
        local m = map[it.category]
        if m then
          local data = {}
          data[m.d] = it.drawable
          if m.t then data[m.t] = it.texture end
          TriggerEvent('nvCloth:addClothToInventory', src, it.category, label, data)
        end
      end
    end

    TriggerClientEvent('nvCloth:showNotification', src, 'fa-solid fa-check', 'green',
      (Config and Config.Translations and Config.Translations[Config.Lang] and Config.Translations[Config.Lang]['purchase-success'])
      or 'Achat effectué !')

  else
    local notEnoughMsg
    if method == 'cash' then
      notEnoughMsg = "Vous n'avez pas assez d'argent sur vous."
    else
      notEnoughMsg = "Vous n'avez pas assez d'argent sur votre compte."
    end
    TriggerClientEvent('nvCloth:showNotification', src, 'fa-solid fa-circle-exclamation', 'red', notEnoughMsg)

    -- Laisse le client décider de fermer ou pas. Si tu veux garder l’ancien comportement :
    -- TriggerClientEvent('nvCloth:resetClothes', src)
    -- TriggerClientEvent('nvCloth:closeMenu', src)
  end
end)

-- Insert en base (ESX / MySQL-Async / oxmysql)
RegisterNetEvent('nvCloth:addClothToInventory')
AddEventHandler('nvCloth:addClothToInventory', function(src, typ, name, data)
  local xPlayer = ESX and ESX.GetPlayerFromId(src) or nil
  if not xPlayer then return end
  local identifier = xPlayer.identifier or xPlayer.getIdentifier and xPlayer:getIdentifier() or nil
  if not identifier then return end

  local encoded = json.encode(data or {})

  -- oxmysql prioritaire si présent
  if GetResourceState('oxmysql') == 'started' then
    exports.oxmysql:insert(
      'INSERT INTO sunny_clothes (identifier, type, name, data) VALUES (?, ?, ?, ?)',
      { identifier, typ, name, encoded },
      function(_) end
    )
    return
  end

  -- sinon MySQL-Async
  if MySQL and MySQL.Async and MySQL.Async.execute then
    MySQL.Async.execute(
      'INSERT INTO sunny_clothes (identifier, type, name, data) VALUES (@identifier, @type, @name, @data)',
      {
        ['@identifier'] = identifier,
        ['@type']       = typ,
        ['@name']       = name,
        ['@data']       = encoded,
      },
      function(_) end
    )
  end
end)

