--========================================================
-- nvCloth – Shops (Blips & Interaction Points)
--========================================================
-- CORRECTIF: Utilise nv_interact avec un système d'événements
-- au lieu de passer des fonctions directement (incompatible avec exports)

-- Événement global pour gérer l'ouverture des shops
RegisterNetEvent('nv_cloth:openShopInteraction')
AddEventHandler('nv_cloth:openShopInteraction', function(label, categories)
  if not opened then
    openClothShop(label, categories)
  end
end)

Citizen.CreateThread(function()
  --========================
  -- Création des blips carte
  --========================
  for _, shop in pairs(Config.Shops) do
    if shop.coords then
      for _, pos in pairs(shop.coords) do
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)

        local sprite = (shop.blip and shop.blip.style) or 73   -- T-shirt par défaut
        local color  = (shop.blip and shop.blip.color) or 81   -- Couleur violette par défaut
        local scale  = (shop.blip and shop.blip.size)  or 0.5  -- Taille par défaut

        SetBlipSprite(blip, sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, scale)
        SetBlipColour(blip, color)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.label or "Boutique")
        EndTextCommandSetBlipName(blip)
      end
    end
  end

  --========================
  -- Points d'interaction via nv_interact
  --========================
  local activePoints = {}

  while true do
    local sleep = 1000
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)

    for sIdx, shop in pairs(Config.Shops) do
      activePoints[sIdx] = activePoints[sIdx] or {}
      if shop.coords then
        for cIdx, pos in ipairs(shop.coords) do
          local dist = #(pCoords - pos)
          if dist < 50.0 then
            sleep = 0
          end

          local pointId = activePoints[sIdx][cIdx]

          if dist < 3.0 then
            -- À portée : créer le point si pas déjà créé
            if not pointId and not opened then
              -- CORRECTIF: On passe un événement au lieu d'une fonction
              pointId = exports.nv_interact:addInteractionPoint({
                coords  = pos,
                dist    = 2.0,
                key     = "E",
                message = shop.label,
                icon    = "fa-store",
                onPressEvent = 'nv_cloth:openShopInteraction',  -- Événement au lieu de fonction
                eventArgs = {shop.label, shop.categories}       -- Arguments pour l'événement
              })
              activePoints[sIdx][cIdx] = pointId
            end
          else
            -- Trop loin : supprimer le point s'il existe
            if pointId then
              exports.nv_interact:removeInteractionPoint(pointId)
              activePoints[sIdx][cIdx] = nil
            end
          end
        end
      end
    end

    Wait(sleep)
  end
end)
