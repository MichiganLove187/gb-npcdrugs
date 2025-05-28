local QBCore = exports['qb-core']:GetCoreObject()
local activeThieves, interactedNPCs = {}, {}
local lastInteractionTime = 0
local isDrawTextActive = false
local isInteracting = false  

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

local function PlayPhoneCallAnimation(ped)
    if not DoesEntityExist(ped) then return end
    
    SetEntityAsMissionEntity(ped, true, true) 
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true) 
    
    LoadAnimDict("cellphone@")
    TaskSmartFleePed(ped, PlayerPedId(), 100.0, -1)
    
    Wait(500)
    
    if DoesEntityExist(ped) then
        TaskPlayAnim(ped, "cellphone@", "cellphone_call_listen_base", 3.0, 3.0, 8000, 49, 0, false, false, false)
        
        local model = GetHashKey('prop_npc_phone')
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        
        local coords = GetEntityCoords(ped)
        local phoneObj = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, true)
        AttachEntityToEntity(phoneObj, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        
        CreateThread(function()
            local checkCount = 0
            while checkCount < 80 do 
                if not DoesEntityExist(ped) then
                    print("DEBUG: Ped disappeared during phone call!")
                    break
                end
                Wait(100)
                checkCount = checkCount + 1
            end
        end)
        
        CreateThread(function()
            Wait(8000) 
            
            if DoesEntityExist(phoneObj) then
                DeleteObject(phoneObj)
            end
            
            if DoesEntityExist(ped) then
                ClearPedTasks(ped)
                FreezeEntityPosition(ped, false)
                SetEntityInvincible(ped, false)
                SetBlockingOfNonTemporaryEvents(ped, false)
                SetPedKeepTask(ped, false)
                SetEntityAsMissionEntity(ped, false, true) 
                TaskWanderStandard(ped, 10.0, 10)
            else
                print("DEBUG: Ped was deleted before cleanup!")
            end
        end)
    end
end


local function PlayerRagdoll()
    local ped = PlayerPedId()
    SetPedToRagdoll(ped, 1000, 1000, 0, 0, 0, 0)
    
    LoadAnimDict("missarmenian2")
    TaskPlayAnim(ped, "missarmenian2", "car_pull_person_out", 8.0, -8.0, -1, 0, 0, false, false, false)
end

function OfferDrugs(ped)
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end
    
    local currentTime = GetGameTimer()
    if (currentTime - lastInteractionTime) < (Config.Cooldown * 1000) then
        local remainingTime = math.ceil(((Config.Cooldown * 1000) - (currentTime - lastInteractionTime)) / 1000)
        QBCore.Functions.Notify("You need to wait " .. remainingTime .. " seconds before offering drugs again.", "error")
        return
    end
    
    isInteracting = true  
    lastInteractionTime = currentTime
    
    FaceToPlayer(ped)
    
    QBCore.Functions.Progressbar("offering_drugs", "Offering Drugs...", 3000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "mp_common",
        anim = "givetake1_a",
        flags = 8,
    }, {}, {}, function() 
        local roll = math.random(100)
        
        if roll <= Config.DeclineChance then
            QBCore.Functions.Notify("They are not interested.", "error")
            PlaySpeech(ped, "angry")
            Wait(1000)
            TaskWanderStandard(ped, 10.0, 10)
            isInteracting = false  
            return
        elseif roll <= Config.DeclineChance + Config.CallPoliceChance then
            QBCore.Functions.Notify("They're calling the cops!", "error")
            PlaySpeech(ped, "angry")
            
            
            PlayPhoneCallAnimation(ped)
            
            TriggerServerEvent('gb-drugsnpc:server:alertPolice', GetEntityCoords(ped))
            isInteracting = false  
            return
        elseif roll <= Config.DeclineChance + Config.CallPoliceChance + Config.AttackChance then
            QBCore.Functions.Notify("They're attacking you!", "error")
            PlaySpeech(ped, "angry")
            
            SetPedCombatAttributes(ped, 46, true) 
            SetPedCombatAttributes(ped, 5, true)  
            SetPedFleeAttributes(ped, 0, false)   
            SetPedAsEnemy(ped, true)
            SetCanAttackFriendly(ped, true, false)
            TaskCombatPed(ped, PlayerPedId(), 0, 16)
            
        if Config.AttackWeapon.enabled then
            local weaponChoice = Config.AttackWeapon.weapons[math.random(#Config.AttackWeapon.weapons)]
            GiveWeaponToPed(ped, GetHashKey(weaponChoice), 1, false, true)
        end

            
            isInteracting = false  
            return
        end
        
        QBCore.Functions.TriggerCallback('gb-drugsnpc:server:checkDrugs', function(items)
            if not items or #items == 0 then 
                isInteracting = false  
                return 
            end
            
            local choice = items[math.random(#items)]
            local drug = choice.name
            local drugConfig = Config.DrugItems[drug]
            
            if not drugConfig then 
                isInteracting = false  
                return 
            end
            
            local minAmount = drugConfig.quantity.min
            local maxAmount = math.min(drugConfig.quantity.max, choice.amount)
            
            if maxAmount < minAmount then maxAmount = minAmount end
            
            local amount = math.random(minAmount, maxAmount)
            local label = drugConfig.label
            
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
    end, function() 
        QBCore.Functions.Notify("Cancelled offering drugs", "error")
        isInteracting = false  
    end)
end

RegisterNetEvent("gb-drugsnpc:client:confirmSale", function(data)
    local ped = NetToPed(data.ped)
    if not DoesEntityExist(ped) then 
        isInteracting = false
        return 
    end
    
    QBCore.Functions.TriggerCallback('gb-drugsnpc:server:checkSpecificDrug', function(hasEnough)
        if not hasEnough then
            QBCore.Functions.Notify("Not enough drugs", "error")
            isInteracting = false
            return
        end
        
        QBCore.Functions.Progressbar("drug_transaction", "Completing Transaction...", 2000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = "mp_common",
            anim = "givetake1_a",
            flags = 8,
        }, {}, {}, function() 
            local chance = math.random(100)
            if chance <= Config.StealChance then
                PlaySpeech(ped, "angry")
                QBCore.Functions.Notify("They stole your drugs!", "error")
                
                LoadAnimDict("melee@unarmed@streamed_variations")
                TaskPlayAnim(ped, "melee@unarmed@streamed_variations", "plyr_takedown_front_slap", 8.0, -8.0, -1, 0, 0, false, false, false)
                Wait(500)
                PlayerRagdoll()
                Wait(1000)
                
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
                                            QBCore.Functions.Progressbar("searching_thief", "Searching...", 3000, false, true, {
                                                disableMovement = true,
                                                disableCarMovement = true,
                                                disableMouse = false,
                                                disableCombat = true,
                                            }, {
                                                animDict = "anim@gangops@facility@servers@bodysearch@",
                                                anim = "player_search",
                                                flags = 16,
                                            }, {}, {}, function() 
                                                local thief = activeThieves[entity]
                                                if thief and thief.searchable then
                                                    TriggerServerEvent("gb-drugsnpc:server:recoverDrugAmount", thief.item, thief.amount)
                                                    QBCore.Functions.Notify("Recovered " .. thief.amount .. "x " .. Config.DrugItems[thief.item].label, "success")
                                                    exports['qb-target']:RemoveTargetEntity(entity)
                                                    activeThieves[entity] = nil
                                                end
                                            end)
                                        end
                                    }},
                                    distance = 2.0
                                })
                                break
                            end
                        end
                    end
                    isInteracting = false  
                end)
            else
                local drugConfig = Config.DrugItems[data.drug]
                local price = math.random(drugConfig.price.min, drugConfig.price.max)
                TriggerServerEvent('gb-drugsnpc:server:completeBulkSale', data.drug, data.amount, price)
                QBCore.Functions.Notify("Sold for $" .. (price * data.amount), "success")
                PlaySpeech(ped, "happy")
                Wait(1000)
                TaskWanderStandard(ped, 10.0, 10)
                isInteracting = false  
            end
        end)
    end, data.drug, data.amount)
end)

RegisterNetEvent("gb-drugsnpc:client:declineOffer", function(data)
    local ped = NetToPed(data.ped)
    PlaySpeech(ped, "angry")
    QBCore.Functions.Notify("You refused the deal", "error")
    Wait(1000)
    TaskWanderStandard(ped, 10.0, 10)
    isInteracting = false  
end)

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function FindNearbyNPCs()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local nearbyPeds = {}
    
    for _, ped in pairs(GetGamePool('CPed')) do
        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) and not interactedNPCs[ped] then
            local pedCoords = GetEntityCoords(ped)
            local dist = #(coords - pedCoords)
            
            if dist < Config.InteractDistance then
                table.insert(nearbyPeds, {ped = ped, coords = pedCoords, distance = dist})
            end
        end
    end
    
    return nearbyPeds
end

local function StartDrawTextInteraction()
    if isDrawTextActive then return end
    isDrawTextActive = true
    
    CreateThread(function()
        while isDrawTextActive and Config.UseDrawText do
            if isInteracting then
                Wait(1000)
            else
                local nearbyPeds = FindNearbyNPCs()
                
                if #nearbyPeds > 0 then
                    Wait(0)
                    for _, pedData in ipairs(nearbyPeds) do
                        DrawText3D(pedData.coords.x, pedData.coords.y, pedData.coords.z + 1.0, "Press [~g~E~w~] to talk")
                        
                        if IsControlJustReleased(0, Config.InteractKey) and pedData.distance < Config.InteractDistance and not isInteracting then
                            isInteracting = true  
                            local ped = pedData.ped
                            interactedNPCs[ped] = true
                            SetBlockingOfNonTemporaryEvents(ped, true)
                            
                            ClearPedTasksImmediately(ped)
                            FaceToPlayer(ped)
                            
                            QBCore.Functions.Progressbar("greeting_npc", "Greeting Local...", 2000, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableMouse = false,
                                disableCombat = true,
                            }, {
                                animDict = "mp_common",
                                anim = "givetake1_a",
                                flags = 8,
                            }, {}, {}, function()
                                PlaySpeech(ped, "greet")
                                QBCore.Functions.Notify("You greeted the local.", "primary")
                                
                                local offerActive = true
                                CreateThread(function()
                                    local offerTime = GetGameTimer()
                                    
                                    while offerActive and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) and GetGameTimer() - offerTime < 10000 do
                                        local playerPos = GetEntityCoords(PlayerPedId())
                                        local pedPos = GetEntityCoords(ped)
                                        local distance = #(playerPos - pedPos)
                                        
                                        if distance < Config.InteractDistance then
                                            DrawText3D(pedPos.x, pedPos.y, pedPos.z + 1.0, "Press [~g~E~w~] to offer drugs")
                                            
                                            if IsControlJustReleased(0, Config.InteractKey) then
                                                offerActive = false
                                                OfferDrugs(ped)
                                                break
                                            end
                                        else
                                            offerActive = false
                                            isInteracting = false
                                            break
                                        end
                                        
                                        Wait(0)
                                    end
                                    
                                    if offerActive then
                                        offerActive = false
                                        isInteracting = false
                                    end
                                end)
                            end, function()
                                isInteracting = false 
                            end)
                            break
                        end
                    end
                else
                    Wait(1000)
                end
            end
        end
        isDrawTextActive = false
    end)
end

CreateThread(function()
    while true do
        Wait(1000)
        QBCore.Functions.TriggerCallback('gb-drugsnpc:server:checkDrugs', function(items)
            if not items or #items == 0 then 
                Wait(5000) 
                return 
            end
            
            if Config.UseDrawText then
                StartDrawTextInteraction()
            else
                if not isInteracting then  
                    local playerPed = PlayerPedId()
                    local coords = GetEntityCoords(playerPed)
                    
                    for _, ped in pairs(GetGamePool('CPed')) do
                        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) then
                            if not interactedNPCs[ped] and #(coords - GetEntityCoords(ped)) < Config.InteractDistance then
                                SetBlockingOfNonTemporaryEvents(ped, true)
                                exports['qb-target']:AddTargetEntity(ped, {
                                    options = {{
                                        icon = "fas fa-comments",
                                        label = "Talk to Local",
                                        action = function(entity)
                                            if isInteracting then return end  
                                            isInteracting = true
                                            interactedNPCs[entity] = true
                                            
                                            
                                            ClearPedTasksImmediately(entity)
                                            FaceToPlayer(entity)
                                            
                                            QBCore.Functions.Progressbar("greeting_npc", "Greeting Local...", 2000, false, true, {
                                                disableMovement = true,
                                                disableCarMovement = true,
                                                disableMouse = false,
                                                disableCombat = true,
                                            }, {
                                                animDict = "mp_common",
                                                anim = "givetake1_a",
                                                flags = 8,
                                            }, {}, {}, function() 
                                                PlaySpeech(entity, "greet")
                                                QBCore.Functions.Notify("You greeted the local.", "primary")
                                                
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
                                                    distance = Config.InteractDistance
                                                })
                                            end, function() 
                                                isInteracting = false
                                            end)
                                        end
                                    }},
                                    distance = Config.InteractDistance
                                })
                            end
                        end
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
