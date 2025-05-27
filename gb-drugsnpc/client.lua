local QBCore = exports['qb-core']:GetCoreObject()
local activeThieves, interactedNPCs = {}, {}

local function LoadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function PlaySpeech(ped, category)
    local lines = {
        greet = {"GENERIC_HI", "GENERIC_HOWS_IT_GOING"},
        angry = {"GENERIC_INSULT_HIGH", "GENERIC_CURSE_SHORT"},
        happy = {"GENERIC_YES", "GENERIC_THANKS"}
    }
    local chosen = lines[category]
    if chosen then
        PlayAmbientSpeech1(ped, chosen[math.random(#chosen)], "SPEECH_PARAMS_FORCE")
    end
end

local function FaceToPlayer(ped)
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, PlayerPedId(), -1)
    Wait(600)
end

function OfferDrugs(ped)
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end
    local roll = math.random(100)
    if roll <= Config.DeclineChance then
        QBCore.Functions.Notify("They are not interested.", "error")
        PlaySpeech(ped, "angry")
        return
    elseif roll <= Config.DeclineChance + Config.CallPoliceChance then
        QBCore.Functions.Notify("They called the cops!", "error")
        PlaySpeech(ped, "angry")
        TriggerServerEvent('gb-drugsnpc:server:alertPolice', GetEntityCoords(ped))
        return
    end

    QBCore.Functions.TriggerCallback('gb-drugsnpc:server:checkDrugs', function(items)
        if not items or #items == 0 then return end
        local choice = items[math.random(#items)]
        local amount = math.random(1, math.min(5, choice.amount))
        local drug = choice.name
        local label = Config.DrugItems[drug].label

        exports['qb-menu']:openMenu({
            {
                header = "They want " .. amount .. "x " .. label,
                txt = "Do you accept the deal?",
                params = {
                    event = "gb-drugsnpc:client:confirmSale",
                    args = { ped = PedToNet(ped), drug = drug, amount = amount }
                }
            },
            {
                header = "Decline",
                txt = "Say no",
                params = {
                    event = "gb-drugsnpc:client:declineOffer",
                    args = { ped = PedToNet(ped) }
                }
            }
        })
    end)
end

RegisterNetEvent("gb-drugsnpc:client:confirmSale", function(data)
    local ped = NetToPed(data.ped)
    if not DoesEntityExist(ped) then return end

    QBCore.Functions.TriggerCallback('gb-drugsnpc:server:checkSpecificDrug', function(hasEnough)
        if not hasEnough then
            QBCore.Functions.Notify("Not enough drugs", "error")
            return
        end

        local chance = math.random(100)
        if chance <= Config.StealChance then
            PlaySpeech(ped, "angry")
            QBCore.Functions.Notify("They stole your drugs!", "error")
            TaskSmartFleePed(ped, PlayerPedId(), 100.0, -1)
            activeThieves[ped] = { item = data.drug, amount = data.amount, searchable = false }

            CreateThread(function()
                Wait(10000)
                if DoesEntityExist(ped) then
                    activeThieves[ped].searchable = true
                    while DoesEntityExist(ped) do
                        Wait(2000)
                        if IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) then
                            exports['qb-target']:AddTargetEntity(ped, {
                                options = {{
                                    icon = "fas fa-search",
                                    label = "Search Local",
                                    action = function(entity)
                                        local thief = activeThieves[entity]
                                        if thief and thief.searchable then
                                            TriggerServerEvent("gb-drugsnpc:server:recoverDrugAmount", thief.item, thief.amount)
                                            QBCore.Functions.Notify("Recovered " .. thief.amount .. "x " .. Config.DrugItems[thief.item].label, "success")
                                            exports['qb-target']:RemoveTargetEntity(entity)
                                            activeThieves[entity] = nil
                                        end
                                    end
                                }},
                                distance = 2.0
                            })
                            break
                        end
                    end
                end
            end)

        else
            local price = math.random(Config.DrugItems[data.drug].min, Config.DrugItems[data.drug].max)
            TriggerServerEvent('gb-drugsnpc:server:completeBulkSale', data.drug, data.amount, price)
            QBCore.Functions.Notify("Sold for $" .. (price * data.amount), "success")
            PlaySpeech(ped, "happy")
        end
    end, data.drug, data.amount)
end)

RegisterNetEvent("gb-drugsnpc:client:declineOffer", function(data)
    local ped = NetToPed(data.ped)
    PlaySpeech(ped, "angry")
    QBCore.Functions.Notify("You refused the deal", "error")
end)

CreateThread(function()
    while true do
        Wait(2000)
        QBCore.Functions.TriggerCallback('gb-drugsnpc:server:checkDrugs', function(items)
            if not items or #items == 0 then return end
            local coords = GetEntityCoords(PlayerPedId())

            for _, ped in pairs(GetGamePool('CPed')) do
                if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) then
                    if not interactedNPCs[ped] and #(coords - GetEntityCoords(ped)) < 2.0 then
                        SetBlockingOfNonTemporaryEvents(ped, true)

                        exports['qb-target']:AddTargetEntity(ped, {
                            options = {{
                                icon = "fas fa-comments",
                                label = "Talk to Local",
                                action = function(entity)
                                    interactedNPCs[entity] = true
                                    PlaySpeech(entity, "greet")
                                    QBCore.Functions.Notify("You greeted the local.", "primary")
                                    Wait(100)
                                    exports['qb-target']:RemoveTargetEntity(entity)

                                    exports['qb-target']:AddTargetEntity(entity, {
                                        options = {{
                                            icon = "fas fa-cannabis",
                                            label = "Offer Drugs",
                                            action = function(e)
                                                OfferDrugs(e)
                                                exports['qb-target']:RemoveTargetEntity(e)
                                            end
                                        }},
                                        distance = 2.5
                                    })
                                end
                            }},
                            distance = 2.0
                        })
                    end
                end
            end
        end)
    end
end)

RegisterNetEvent('gb-drugsnpc:client:policeAlert', function(coords)
    local alpha = 250
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 3)
    SetBlipAlpha(blip, alpha)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Suspicious Activity")
    EndTextCommandSetBlipName(blip)

    CreateThread(function()
        while alpha > 0 do
            Wait(720)
            alpha = alpha - 1
            SetBlipAlpha(blip, alpha)
        end
        RemoveBlip(blip)
    end)
end)
