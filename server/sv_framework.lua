-- nvCloth - helpers serveur (clean)
-- Compat ESX / QBCore + MySQL (oxmysql ou mysql-async)
-- Expose : getAccountMoney, removeAccountMoney, sendNotification, getPlayerIdentifier
-- Event  : nvCloth:save (sauvegarde du skin en base)

---------------------------------------
-- Récup ESX / QBCore proprement
---------------------------------------
ESX, QBCore = ESX, QBCore

CreateThread(function()
  if not ESX and GetResourceState('es_extended') == 'started' then
    local ex = exports['es_extended']
    if ex and ex.getSharedObject then
      ESX = ex:getSharedObject()
    end
  end

  if not QBCore and GetResourceState('qb-core') == 'started' then
    local qb = exports['qb-core']
    if qb and qb.GetCoreObject then
      QBCore = qb:GetCoreObject()
    end
  end
end)

---------------------------------------
-- Helpers argent (ESX + QB)
---------------------------------------
local function _qbMoneyMap(name)
  -- normalise quelques alias
  if name == 'money' then return 'cash' end
  return name
end

function getAccountMoney(src, account)
  account = tostring(account or 'money')
  if ESX and Config.Framework == 'esx' then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 0 end

    if account == 'money' or account == 'cash' then
      -- ESX v1 final : getMoney()
      if xPlayer.getMoney then return xPlayer:getMoney() or 0 end
      -- fallback compte "money"
      local acc = xPlayer.getAccount and xPlayer:getAccount('money')
      return (acc and acc.money) or 0
    else
      local acc = xPlayer.getAccount and xPlayer:getAccount(account)
      return (acc and acc.money) or 0
    end
  end

  if QBCore and Config.Framework == 'qbcore' then
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.money then return 0 end
    local key = _qbMoneyMap(account)
    return tonumber(Player.PlayerData.money[key] or 0)
  end

  return 0
end

function removeAccountMoney(src, account, amount)
  amount  = tonumber(amount) or 0
  account = tostring(account or 'money')
  if amount <= 0 then return end

  if ESX and Config.Framework == 'esx' then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if account == 'money' or account == 'cash' then
      -- retirer sur la poche
      if xPlayer.removeMoney then
        xPlayer:removeMoney(amount)
      else
        -- anciens scripts : removeAccountMoney('cash', amount)
        if xPlayer.removeAccountMoney then xPlayer:removeAccountMoney('cash', amount) end
      end
    else
      if xPlayer.removeAccountMoney then xPlayer:removeAccountMoney(account, amount) end
    end
    return
  end

  if QBCore and Config.Framework == 'qbcore' then
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.Functions or not Player.Functions.RemoveMoney then return end
    local key = _qbMoneyMap(account)
    Player.Functions.RemoveMoney(key, amount, 'nvCloth purchase')
    return
  end
end

---------------------------------------
-- Notifications (ESX / QBCore)
---------------------------------------
function sendNotification(src, msg)
  msg = tostring(msg or '')
  if msg == '' then return end

  if Config.Framework == 'esx' then
    -- côté serveur -> client ESX
    TriggerClientEvent('esx:showNotification', src, msg)
    return
  end

  if Config.Framework == 'qbcore' then
    -- côté serveur -> client QB
    TriggerClientEvent('QBCore:Notify', src, msg)
    return
  end
end

---------------------------------------
-- Identifiant joueur (DB key)
---------------------------------------
function getPlayerIdentifier(src)
  if Config.Framework == 'esx' and ESX then
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return nil end
    return xPlayer.identifier or (xPlayer.getIdentifier and xPlayer:getIdentifier()) or nil
  end

  if Config.Framework == 'qbcore' and QBCore then
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then return nil end
    return Player.PlayerData.citizenid
  end

  return nil
end

---------------------------------------
-- Sauvegarde skin (nvCloth:save)
-- ESX  : table "users",   colonne "skin",       clé "identifier"
-- QBCore: table "players", colonne "skin" (par défaut), clé "citizenid"
-- Surchargable via Config.DBOverride (facultatif)
---------------------------------------
local function dbExecUpdate(query, params, cb)
  -- oxmysql prioritaire
  if GetResourceState('oxmysql') == 'started' and exports.oxmysql and exports.oxmysql.update then
    return exports.oxmysql:update(query, params, cb)
  end

  -- mysql-async sinon
  if MySQL and MySQL.Async and MySQL.Async.execute then
    return MySQL.Async.execute(query, params, cb or function() end)
  end

  -- fallback (pas de DB)
  print('^1[nvCloth]^7 Aucune ressource DB détectée (oxmysql/mysql-async). Impossible de sauvegarder le skin.')
  if cb then cb(0) end
end

-- Valeurs par défaut (modifiable si besoin)
local DEFAULT_DB = {
  esx   = { table = 'users',   column = 'skin', key = 'identifier' },
  qbcore= { table = 'players', column = 'skin', key = 'citizenid' },
}

RegisterServerEvent('nvCloth:save')
AddEventHandler('nvCloth:save', function(skin)
  local src = source
  if type(skin) ~= 'table' then return end

  local id = getPlayerIdentifier(src)
  if not id then return end

  -- surcharge éventuelle
  local dbCfg = (Config.DBOverride and Config.DBOverride[Config.Framework]) or DEFAULT_DB[Config.Framework]
  if not dbCfg then
    print('^1[nvCloth]^7 Config.Framework invalide pour la sauvegarde DB.')
    return
  end

  local encoded = json.encode(skin)

  local query, params
  if GetResourceState('oxmysql') == 'started' then
    query  = ('UPDATE %s SET %s = ? WHERE %s = ?'):format(dbCfg.table, dbCfg.column, dbCfg.key)
    params = { encoded, id }
  else
    -- mysql-async (nommé)
    query  = ('UPDATE %s SET %s = @skin WHERE %s = @id'):format(dbCfg.table, dbCfg.column, dbCfg.key)
    params = { ['@skin'] = encoded, ['@id'] = id }
  end

  dbExecUpdate(query, params, function(affected)
    -- logging léger
    -- print(('[nvCloth] Skin sauvegardé pour %s (%s lignes)'):format(id, tostring(affected)))
  end)
end)
