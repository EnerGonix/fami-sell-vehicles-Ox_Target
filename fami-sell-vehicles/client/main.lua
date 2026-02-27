lib.locale()  -- garante que o locale esteja carregado

-- =========================
-- Variáveis Globais
-- =========================
local SellPointBlip = nil
local showingVehicles = {}      -- [vehicleId] = { vehicle, owner, price, slot }
local sellingCarTextPositions = {} 
local loadingVehicles = {}      -- [vehicleId] = true/false
local slots = {}                -- [slotIndex] = {coords = vector3, vehicleId = nil}

-- =========================
-- Blip do Ponto de Venda
-- =========================
Citizen.CreateThread(function()
    SellPointBlip = AddBlipForCoord(Config.SellPoint.blipPos.x, Config.SellPoint.blipPos.y, Config.SellPoint.blipPos.z)
    SetBlipSprite(SellPointBlip, Config.SellPoint.blipSprite)
    SetBlipDisplay(SellPointBlip, 4)
    SetBlipScale(SellPointBlip, Config.SellPoint.blipScale)
    SetBlipColour(SellPointBlip, Config.SellPoint.blipColor)
    SetBlipAsShortRange(SellPointBlip, Config.SellPoint.blipShortRange)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(locale('blip_name'))
    EndTextCommandSetBlipName(SellPointBlip)

    local sellPoint = lib.points.new({
        coords = Config.SellPoint.markerPos,
        distance = Config.SellPoint.markerShowRadius,
    })

    local sellMarker = lib.marker.new({
        type = Config.SellPoint.markerType,
        color = Config.SellPoint.markerColor,
        coords = Config.SellPoint.markerPos,
        width = Config.SellPoint.markerWidth,
        height = Config.SellPoint.markerHeight,
    })

    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if sellMarker then
                sellMarker:draw()
            end
        end
    end)

    function sellPoint:nearby()
        if self.currentDistance <= 1.5 then
            if not lib.isTextUIOpen() then
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                    lib.showTextUI(locale('sell_vehicle_prompt'), { position = "top-center" })
                end
            end

            if IsControlJustPressed(0, 51) then
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                local vehicleProps = lib.getVehicleProperties(vehicle)
                if vehicle == 0 then return ESX.ShowNotification(locale('sell_vehicle_prompt_notinvehicle'), "error") end
                if GetPedInVehicleSeat(vehicle, -1) ~= ped then return ESX.ShowNotification(locale('sell_vehicle_prompt_notinvehicle'), "error") end

                lib.hideTextUI()
                local ownsVehicle = lib.callback.await('fami-sell-vehicles:checkCar', false, vehicle, vehicleProps.plate)
                if not ownsVehicle then return ESX.ShowNotification(locale('sell_vehicle_not_owned'), "error") end

                local money = lib.inputDialog(locale('sell_vehicle_price_prompt_title'), {
                    {type = "number", label = locale('sell_vehicle_price_prompt_text'), icon = "dollar"}
                })
                if not money or money[1] <= 0 then return ESX.ShowNotification(locale('sell_vehicle_price_invalid'), "error") end

                local success = lib.callback.await('fami-sell-vehicles:putOnSale', false, money[1], vehicleProps)
                if success then
                    ESX.ShowNotification(locale('sell_vehicle_success', money[1]))
                    ESX.Game.DeleteVehicle(vehicle) 
	                SpawnAllVehicles()
                else
                    ESX.ShowNotification(locale('sell_vehicle_error'), "error")
                end
            end
        else
            if lib.isTextUIOpen() then
                lib.hideTextUI()
            end
        end
    end
end)

-- =========================
-- Inicializa slots (main + extras)
-- =========================
slots[1] = {coords = Config.ViewVehicles.main.position, vehicleId = nil}
for i, c in ipairs(Config.ViewVehicles.extras) do
    slots[i+1] = {coords = c, vehicleId = nil}
end

-- =========================
-- Função de Spawn de Veículo (FUNCIONA)
-- =========================
local function SpawnVehicle(vehicleData, slotIndex)
    local id = vehicleData.id
    local slot = slots[slotIndex]
    loadingVehicles[id] = true

    ESX.Game.SpawnLocalVehicle(json.decode(vehicleData.vehicleProps).model, slot.coords, slot.coords.w or 0.0, function(veh)
        -- Configuração do veículo
        lib.setVehicleProperties(veh, json.decode(vehicleData.vehicleProps))
        SetVehicleEngineOn(veh, false, true, true)
        SetVehicleLights(veh, 0)
        SetVehicleLightsMode(veh, 0)
        SetVehicleOnGroundProperly(veh)
        SetEntityCanBeDamaged(veh, false)
        FreezeEntityPosition(veh, true)

        -- Registos internos
        showingVehicles[id] = {
            vehicle = veh,
            owner = vehicleData.seller,
            price = vehicleData.price,
            slot = slotIndex
        }
        slot.vehicleId = id
        loadingVehicles[id] = false

        -- 3D text (opcional)
        local min, max = GetModelDimensions(GetEntityModel(veh))
        local loc = GetEntityCoords(veh)
        sellingCarTextPositions[id] = vector3(
            loc.x,
            loc.y,
            loc.z + (max.z - min.z) + 0.5
        )

        -- =========================
        -- OX_TARGET (CORRETO)
        -- =========================
        exports.ox_target:addLocalEntity(veh, {
            {
                name = 'view_vehicle_' .. id,
                label = locale('view_vehicle_prompt'),
                icon = 'fa-solid fa-money-bill',
                distance = 3.5,
                onSelect = function()
                    lib.registerContext({
                        id = 'fami-sell-vehicles:vehicleOptions_' .. id,
                        title = locale('vehicle_options_title'),
                        canClose = true,
                        options = {
                            {
                                title = locale('vehicle_options_buy', formatMoney(showingVehicles[id].price)),
                                icon = 'dollar',
                                serverEvent = 'fami-sell-vehicles:buyVehicle',
                                args = id
                            },
                            {
                                title = locale('vehicle_options_return'),
                                icon = 'car',
                                serverEvent = 'fami-sell-vehicles:returnVehicle',
                                args = id,
                                disabled = showingVehicles[id].owner ~= ESX.PlayerData.identifier
                            },
                            {
                                title = locale('vehicle_options_change_vehicle'),
                                icon = 'car-side',
                                onSelect = function()
                                    openAllVehiclesMenu(slotIndex, id)
                                end
                            }
                        }
                    })

                    lib.showContext('fami-sell-vehicles:vehicleOptions_' .. id)
                end
            }
        })
    end)
end
-- =========================
-- Spawn todos os veículos disponíveis
-- =========================
function SpawnAllVehicles()
    local vehicles = lib.callback.await('fami-sell-vehicles:getVehiclesForSale', false)
    if #vehicles == 0 then return end

    local availableVehicles = {}
    for _, v in ipairs(vehicles) do
        local inUse = false
        for _, slot in ipairs(slots) do
            if slot.vehicleId == v.id then
                inUse = true
                break
            end
        end
        if not inUse then
            table.insert(availableVehicles, v)
        end
    end

    local usedVehicleIds = {}

    for slotIndex, slot in ipairs(slots) do
        if slot.vehicleId and showingVehicles[slot.vehicleId] then
            usedVehicleIds[slot.vehicleId] = true
        else
            local nextVehicle = nil
            for _, v in ipairs(availableVehicles) do
                if not usedVehicleIds[v.id] then
                    nextVehicle = v
                    break
                end
            end
            if nextVehicle then
                SpawnVehicle(nextVehicle, slotIndex)
                usedVehicleIds[nextVehicle.id] = true
            end
        end
    end
end

-- =========================
-- Thread de texto 3D
-- =========================
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local pedCoords = GetEntityCoords(PlayerPedId())
        for id, data in pairs(showingVehicles) do
            if data.vehicle and DoesEntityExist(data.vehicle) then
                local dist = #(pedCoords - GetEntityCoords(data.vehicle))
                if dist < 30.0 then
                    sleep = 0
                    if loadingVehicles[id] then
                        ESX.Game.Utils.DrawText3D(GetEntityCoords(data.vehicle), locale('loading_vehicle'), 1.0)
                    else
                        ESX.Game.Utils.DrawText3D(sellingCarTextPositions[id], locale('vehicle_for_sale', formatMoney(data.price)), 1.0)
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- =========================
-- Menu Geral
-- =========================
function openAllVehiclesMenu(slotIndex, currentVehicleId)
    local vehicles = lib.callback.await('fami-sell-vehicles:getVehiclesForSale', false)
    if #vehicles == 0 then
        ESX.ShowNotification(locale('no_vehicle_for_sale'), "error")
        return
    end

    local elements = {}
    local vehiclesInSlots = {}
    for _, slot in ipairs(slots) do
        if slot.vehicleId then
            vehiclesInSlots[slot.vehicleId] = true
        end
    end

    for _, v in ipairs(vehicles) do
        local model = json.decode(v.vehicleProps).model
        local disabled = vehiclesInSlots[v.id] ~= nil
        table.insert(elements, {
            title = locale('choose_vehicle_item_title', GetVehicleLabel(model)),
            description = locale('choose_vehicle_item_description', formatMoney(v.price)),
            icon = "car",
            onSelect = function()
                if currentVehicleId and showingVehicles[currentVehicleId] then
                    if showingVehicles[currentVehicleId].vehicle and DoesEntityExist(showingVehicles[currentVehicleId].vehicle) then
                        DeleteEntity(showingVehicles[currentVehicleId].vehicle)
                    end
                    showingVehicles[currentVehicleId] = nil
                    sellingCarTextPositions[currentVehicleId] = nil
                    loadingVehicles[currentVehicleId] = nil
                    slots[slotIndex].vehicleId = nil
                end
                SpawnVehicle(v, slotIndex)
            end,
            disabled = disabled
        })
    end

    lib.registerContext({
        id = "fami-sell-vehicles:allVehicles",
        title = locale('choose_vehicle_title'),
        menu = nil,
        canClose = true,
        options = elements
    })
    lib.showContext("fami-sell-vehicles:allVehicles")
end

-- =========================
-- Helpers
-- =========================
function GetVehicleLabel(model)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if label == 'NULL' then label = GetDisplayNameFromVehicleModel(model) end
    return label
end

function formatMoney(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- =========================
-- Função para eleminar veiculos que ja nao estao á venda
-- =========================
function DeleteCars()
    -- Deleta todos os veículos spawnados
    for id, data in pairs(showingVehicles) do
        if data.vehicle and DoesEntityExist(data.vehicle) then
            DeleteEntity(data.vehicle)
        end
        showingVehicles[id] = nil
        sellingCarTextPositions[id] = nil
        loadingVehicles[id] = nil

        local slotIndex = data.slot
        if slots[slotIndex] and slots[slotIndex].vehicleId == id then
            slots[slotIndex].vehicleId = nil
        end
    end

    -- Limpa tabelas de controle
    showingVehicles = {}
    sellingCarTextPositions = {}
    loadingVehicles = {}

    -- Opcional: resetar pontos e menus
    for _, slot in pairs(slots) do
        slot.vehicleId = nil
    end

    print("[ResetScript] Script reiniciado com sucesso.")
end
RegisterNetEvent('fami-sell-vehicles:resetCars')
AddEventHandler('fami-sell-vehicles:resetCars', function()
    DeleteCars() 
	SpawnAllVehicles()
end)

local function IsPlayerNearSellPoint(radius)
    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local sellCoords = vector3(Config.SellPoint.blipPos.x, Config.SellPoint.blipPos.y, Config.SellPoint.blipPos.z)
    return #(playerCoords - sellCoords) <= radius
end
--------------------------------------
-- Controla spawn e delete de veículos
--------------------------------------
Citizen.CreateThread(function()
    local vehiclesSpawned = false

    while true do
        Citizen.Wait(1000) -- Checa a cada segundo

        if IsPlayerNearSellPoint(50.0) then -- Raio de proximidade para spawn
            if not vehiclesSpawned then
                SpawnAllVehicles()
                vehiclesSpawned = true
            end
        else
            if vehiclesSpawned then
                DeleteCars()
                vehiclesSpawned = false
            end
        end
    end
end)

-- =========================
-- Cleanup on resource stop
-- =========================
RegisterNetEvent('onResourceStop')
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        RemoveBlip(SellPointBlip)
        for _, data in pairs(showingVehicles) do
            if data.vehicle and DoesEntityExist(data.vehicle) then
                DeleteEntity(data.vehicle)
            end
        end
    end
end)