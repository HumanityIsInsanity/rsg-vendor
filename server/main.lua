local RSGCore = exports['rsg-core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        Wait(100)
        exports.oxmysql:execute('UPDATE market_owner SET robbery = 0 WHERE robbery = 1', {})
        if Config.AutoAddMarket then
        TriggerEvent("rsg-vendor:server:vendorAutoAdd")
        end
    end
end)

-------------------------------------------------------------------------------------------
-- Callback
-------------------------------------------------------------------------------------------


RSGCore.Functions.CreateCallback('rsg-vendor:server:vendor', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid

    exports.oxmysql:execute('SELECT * FROM market_owner', {}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)

RSGCore.Functions.CreateCallback('rsg-vendor:server:vendorOwned', function(source, cb, currentvendor)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid

    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid = ? AND owned = 1 ', {currentvendor}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)


RSGCore.Functions.CreateCallback('rsg-vendor:server:vendorOwner', function(source, cb, currentvendor)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid

    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid = ? AND owned = 1 AND citizenid = ? ', {currentvendor, Playercid}, function(result2)
        if result2[1] then
            cb(result2)
        else
            cb(nil)
        end
    end)
end)

RSGCore.Functions.CreateCallback('rsg-vendor:server:vendorS', function(source, cb, currentvendor)
    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid = ?', {currentvendor}, function(result)
        if result[1] then
            cb(result)
        else
            cb(nil)
        end
    end)
end)


RSGCore.Functions.CreateCallback('rsg-vendor:server:vendorGetMoney', function(source, cb, currentvendor)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid

    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid = ? AND owned = 1 AND citizenid = ? ', {currentvendor, Playercid}, function(checkmoney)
        if checkmoney[1] then
            cb(checkmoney[1])
        else
            cb(nil)
        end
    end)
end)

-------------------------------------------------------------------------------------------
-- Event
-------------------------------------------------------------------------------------------

RegisterServerEvent("rsg-vendor:server:vendorGetShopItems")
AddEventHandler("rsg-vendor:server:vendorGetShopItems", function(shopName)
    local _source = source
    exports['oxmysql']:execute('SELECT * FROM market_items WHERE marketid = ?', {shopName}, function(data)
        exports['oxmysql']:execute('SELECT * FROM market_owner WHERE marketid = ?', {shopName}, function(data2)
            TriggerClientEvent("Stores:ReturnStoreItems", _source, data, data2)
        end)
	end)
end)


RegisterServerEvent("rsg-vendor:server:vendorPurchaseItem")
AddEventHandler("rsg-vendor:server:vendorPurchaseItem", function(location, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM market_items WHERE marketid = ? AND items = ?',{location, item} , function(data)
        local stock = data[1].stock - amount
        local price = data[1].price * amount   
        local currentMoney = Player.Functions.GetMoney('cash')
        if price <= currentMoney then
            MySQL.Async.execute("UPDATE market_items SET stock=@stock WHERE marketid=@location AND items=@item", {['@stock'] = stock, ['@location'] = location, ['@item'] = item}, function(count)
                if count > 0 then
                    Player.Functions.RemoveMoney("cash", price, "market")
                    Player.Functions.AddItem(item, amount)
                    TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[item], "add")
                    MySQL.Async.fetchAll("SELECT * FROM market_owner WHERE marketid=@location", { ['@location'] = location }, function(data2)
                        local moneymarket = data2[1].money + price
                        exports.oxmysql:execute('UPDATE market_owner SET money = ? WHERE marketid = ?',{moneymarket, location})
                    end)
                    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.buy_prod').." "..amount.."x "..RSGCore.Shared.Items[item].label, 'success')
                end
            end)
        else 
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.player_no_money'), 'error')
        end
    end)
end)


RegisterServerEvent("rsg-vendor:server:vendorInvReFill")
AddEventHandler("rsg-vendor:server:vendorInvReFill", function(location, item, qt, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    local itemv = item.name
    
    exports.oxmysql:execute('SELECT * FROM market_items WHERE marketid = ? AND items = ?',{location, itemv} , function(result)
        if result[1] ~= nil then
            local stockv = result[1].stock + tonumber(qt)
            --print(stockv)
            exports.oxmysql:execute('UPDATE market_items SET stock = ?, price = ? WHERE marketid = ? AND items = ?',{stockv, amount, location, itemv})
            Player.Functions.RemoveItem(itemv, qt)
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[itemv], "remove")
        else
            local price = amount
            exports.oxmysql:execute('INSERT INTO market_items (`marketid`, `items`, `stock`, `price`) VALUES (?, ?, ?, ?);',{location, itemv, qt, price})
            Player.Functions.RemoveItem(itemv, qt)
            TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items[itemv], "remove")
        end
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.refill').." " ..qt.. "x " ..item.label, 'success')
    end)
end)


RegisterServerEvent("rsg-vendor:server:vendorWithdraw")
AddEventHandler("rsg-vendor:server:vendorWithdraw", function(location, omoney)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid= ? AND citizenid= ?',{location, Playercid} , function(result)
        if result[1] ~= nil then
            if result[1].money >= tonumber(omoney) then
            local nmoney = result[1].money - omoney
            exports.oxmysql:execute('UPDATE market_owner SET money = ? WHERE marketid = ? AND citizenid = ?',{nmoney, location, Playercid})
            Player.Functions.AddMoney('cash', omoney)
            else
                --Notif
            end
        end
    end)
end)


RegisterServerEvent("rsg-vendor:server:vendorBuyEtal")
AddEventHandler("rsg-vendor:server:vendorBuyEtal", function(location, price)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid = ? AND owned = 0',{location} , function(result)
        if result[1] ~= nil then
            if Player.Functions.RemoveMoney("cash", price, "etal-bought") then
                exports.oxmysql:execute('UPDATE market_owner SET owned = ?, citizenid = ? WHERE marketid = ?',{1, Playercid, location})
                TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.buy_t'), 'success')
                TriggerEvent('rsg-log:server:CreateLog', 'shops', 'Market Stall', 'green', "**"..GetPlayerName(Player.PlayerData.source) .. " (citizenid: "..Player.PlayerData.citizenid.." | id: "..Player.PlayerData.source..")** bought a stall $"..price..".")
            else
                TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.player_no_money'), 'error')
                return
            end
        end
    end)
end)


RegisterServerEvent("rsg-vendor:server:vendorGiveBusiness")
AddEventHandler("rsg-vendor:server:vendorGiveBusiness", function(location, tocid)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM players WHERE citizenid = ?',{tocid} , function(result)
        if result[1] ~= nil then
            MySQL.Async.fetchAll("SELECT * FROM market_owner WHERE citizenid=@citizenid AND owned=1 AND marketid=@marketid", { ['@marketid'] = location, ['@citizenid'] = Playercid }, function(result2)
                if result2[1] ~= nil then
                    exports.oxmysql:execute('UPDATE market_owner SET citizenid = ? WHERE marketid = ?',{tocid, location})
                    TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.transfert_t'), 'success')
                else
                    TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.error'), 'error')
                    return
                end
            end)
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.error_cid'), 'error')
            return
        end
    end)
end)

RegisterServerEvent("rsg-vendor:server:vendorGetName")
AddEventHandler("rsg-vendor:server:vendorGetName", function(shopName)
    local _source = source
    exports['oxmysql']:execute('SELECT * FROM market_items WHERE marketid = ?', {shopName}, function(data)
        TriggerClientEvent("Stores:ReturnStoreItems", _source, data)
	end)
end)

RegisterServerEvent("rsg-vendor:server:vendorName")
AddEventHandler("rsg-vendor:server:vendorName", function(location, name)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid = ? AND citizenid = ?',{location, Playercid} , function(result)
        if result[1] ~= nil then
            exports.oxmysql:execute('UPDATE market_owner SET displayname = ? WHERE marketid = ?',{name, location})
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.newname'), 'success')
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.error'), 'error')
            return
        end
    end)
end)

-------------------------------------------
-- ROBBERY

-------------------------------------------

RegisterServerEvent("rsg-vendor:server:vendorRob")
AddEventHandler("rsg-vendor:server:vendorRob", function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
	local Playercid = Player.PlayerData.citizenid
    
    exports.oxmysql:execute('SELECT * FROM market_owner WHERE marketid = ?',{location} , function(result)
        --print(result[1])
        if result[1].money >= 1 then
            --print(result[1].money)
            local rmoney = result[1].money - result[1].money / Config.Percent
            local rpmoney = result[1].money / Config.Percent
            exports.oxmysql:execute('UPDATE market_owner SET money = ?, robbery = ? WHERE marketid = ?',{rmoney, 1, location})
            Player.Functions.AddMoney("cash", rpmoney, "robbery")
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('success.robreward')..rpmoney, 'success')
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.market_no_money'), 'error')
            return
        end
    end)
end)

---------------------------------------

RegisterServerEvent("rsg-vendor:server:vendorAutoAdd")
AddEventHandler("rsg-vendor:server:vendorAutoAdd", function()
    for k, v in pairs(Config.Market) do
        Wait(100)
        local result = MySQL.Sync.fetchSingle('SELECT * FROM market_owner WHERE marketid = ?', { k })
        if not result then
            exports.oxmysql:execute('INSERT INTO market_owner (`marketid`, `displayname`) VALUES (?, ?);',{k, k})
            print('New stall : '..k..' has been added to database')
        end
    end        
end)