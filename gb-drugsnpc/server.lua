local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('gb-drugsnpc:server:checkDrugs', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        print("Player not found for source: " .. tostring(source))
        cb({})
        return
    end
    
    local items = {}
    
    for item, data in pairs(Config.DrugItems) do
        local hasItem = Player.Functions.GetItemByName(item)
        if hasItem and hasItem.amount > 0 then
            table.insert(items, { name = item, amount = hasItem.amount })
        end
    end
    
    cb(items)
end)

QBCore.Functions.CreateCallback('gb-drugsnpc:server:checkSpecificDrug', function(source, cb, drug, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        print("Player not found for source: " .. tostring(source))
        cb(false)
        return
    end
    
    local hasItem = Player.Functions.GetItemByName(drug)
    
    if hasItem and hasItem.amount >= amount then
        Player.Functions.RemoveItem(drug, amount)
        cb(true)
    else
        cb(false)
    end
end)

RegisterServerEvent('gb-drugsnpc:server:completeBulkSale', function(drug, amount, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print("Player not found for source: " .. tostring(src))
        return
    end
    
    local total = price * amount
    Player.Functions.AddMoney('cash', total)
end)

RegisterServerEvent('gb-drugsnpc:server:recoverDrugAmount', function(drug, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print("Player not found for source: " .. tostring(src))
        return
    end
    
    Player.Functions.AddItem(drug, amount)
end)

RegisterServerEvent('gb-drugsnpc:server:alertPolice', function(coords)
    local src = source
    local Players = QBCore.Functions.GetPlayers()
    
    for i = 1, #Players do
        local Player = QBCore.Functions.GetPlayer(Players[i])
        if Player and Player.PlayerData.job.name == "police" then
            TriggerClientEvent("gb-drugsnpc:client:policeAlert", Players[i], coords)
        end
    end
end)
