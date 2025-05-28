Config = {}

Config.UseDrawText = true -- Set to true to use drawtext, false to use qb-target
Config.InteractKey = 38 -- E key (for drawtext interaction)
Config.InteractDistance = 2.0 -- Distance for interaction
Config.Cooldown = 30 -- Cooldown in seconds between NPC interactions

Config.AttackWeapon = {
    enabled = false, -- Set to false so npc use fist only
    weapons = {
        "WEAPON_KNIFE",
        "WEAPON_BAT", 
        "WEAPON_BOTTLE",
        "WEAPON_HAMMER"
    }
}



Config.DrugItems = {
    ['cokebaggy'] = { 
        label = "Bag of Coke",     
        price = { min = 100, max = 200 },  -- Price for each single item
        quantity = { min = 1, max = 38 }   -- How many can be sold in one sale
    },
    ['crack_baggy'] = { 
        label = "Bag of Crack",    
        price = { min = 80, max = 160 },
        quantity = { min = 1, max = 4 }
    },
    ['xtcbaggy'] = { 
        label = "Bag of XTC",      
        price = { min = 90, max = 170 },
        quantity = { min = 1, max = 6 }
    },
    ['meth'] = { 
        label = "Meth",            
        price = { min = 120, max = 250 },
        quantity = { min = 1, max = 3 }
    },
    ['oxy'] = { 
        label = "Oxy",             
        price = { min = 100, max = 180 },
        quantity = { min = 1, max = 8 }
    }
}


Config.DeclineChance = 25
Config.CallPoliceChance = 25
Config.StealChance = 25
Config.AttackChance = 25 -- set to 0 if you dont want peds to attack
