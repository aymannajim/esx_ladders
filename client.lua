ESX              = nil
local PlayerData = {}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  PlayerData = xPlayer   
end)

-- Synced table across all clients and the server
local Ladders = {}
-- Locally created ladders
local LocalLadders = {}

local Climbing = false
local Carrying = false
local ClimbingLadder = false
local Preview = false
local PreviewToggle = true
local Clipset = false

local ClimbingVectors = {
    up = {
        {vector3(0.0, -0.45, -1.5), 'laddersbase', 'get_on_bottom_front_stand_high'},
        {vector3(0.0, -0.3, -1.1), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, -0.7), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, -0.3), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, 0.1), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, 0.5), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, 0.9), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, 1.3), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, 1.7), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.3, 2.1), 'laddersbase', 'climb_up'},
        {vector3(0.0, -0.4, 2.5), 'laddersbase', 'get_off_top_back_stand_left_hand'}
    },

    down = {
        {vector3(0.0, -0.4, 2.5), 'laddersbase', 'get_on_top_front'},
        {vector3(0.0, -0.3, 2.1), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, 1.7), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, 1.3), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, 0.9), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, 0.5), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, 0.1), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, -0.3), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, -0.7), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.3, -1.1), 'laddersbase', 'climb_down'},
        {vector3(0.0, -0.45, -1.5), 'laddersbase', 'get_off_bottom_front_stand'}
    }
}

-- Create ladders client side
RegisterNetEvent('Ladders:Client:Local:Add')
AddEventHandler('Ladders:Client:Local:Add', function(SourceId)
    local SourcePlayer = GetPlayerFromServerId(SourceId)
    local SourcePed = GetPlayerPed(SourcePlayer)

    if (SourcePed ~= -1 and not LocalLadders[SourcePed]) then
        local LadderCoords = GetOffsetFromEntityInWorldCoords(SourcePed, 0.0, 1.2, 1.32)
        local Ladder = CreateObjectNoOffset(GetHashKey('prop_byard_ladder01'), LadderCoords, false, false, false)

        SetEntityAsMissionEntity(Ladder)
        SetEntityCollision(Ladder, false, true)
        LocalLadders[SourcePed] = Ladder

        if GetPlayerServerId(PlayerId()) == SourceId then Carrying = Ladder end
    end
end)

-- Remove local ladder
RegisterNetEvent('Ladders:Client:Local:Remove')
AddEventHandler('Ladders:Client:Local:Remove', function(SourceId)
    local SourcePlayer = GetPlayerFromServerId(SourceId)
    local SourcePed = GetPlayerPed(SourcePlayer)

    if (SourcePed ~= -1 and LocalLadders[SourcePed]) then
        DeleteObject(LocalLadders[SourcePed])
        SetEntityAsNoLongerNeeded(LocalLadders[SourcePed])
        ClearPedTasksImmediately(PlayerPed)
        LocalLadders[SourcePed] = nil

        if GetPlayerServerId(PlayerId()) == SourceId then Carrying = nil end
    end
end)

-- Syncs table across all clients and server
RegisterNetEvent('Ladders:Bounce:ServerValues')
AddEventHandler('Ladders:Bounce:ServerValues', function(NewLadders) Ladders = NewLadders end)

RegisterNetEvent('Ladders:Client:DropLadder')
AddEventHandler('Ladders:Client:DropLadder', function()
    if Carrying then
        local PlayerPed = PlayerPedId()
        local Ladder = CreateObjectNoOffset(GetHashKey('prop_byard_ladder01'), GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 0.0, -500.0), true, false, false)
        local LadderNetID = ObjToNet(Ladder)

        SetEntityAsMissionEntity(LadderNetID)
        ClearPedTasksImmediately(PlayerPed)
        SetEntityRotation(Ladder, 0.0, 90.0, 90.0)
        SetEntityCoords(Ladder, GetOffsetFromEntityInWorldCoords(PlayerPed, 0.5, 0.0, 0.0))
        ApplyForceToEntity(Ladder, 4, 0.001, 0.001, 0.001, 0.0, 0.0, 0.0, 0, false, true, true, false, true)

        TriggerServerEvent('Ladders:Server:Ladders:Local', 'remove')
        TriggerServerEvent('Ladders:Server:Ladders', 'store', LadderNetID)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingCarried', true)

        -- Allow time to drop to the ground
        Citizen.Wait(1000)

        local LadderCoords = GetEntityCoords(Ladder)

        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingCarried', false)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingClimbed', false)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Dropped', true)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Placed', false)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'x', LadderCoords.x)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'y', LadderCoords.y)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'z', LadderCoords.z)
    end
end)

RegisterNetEvent('Ladders:Client:Pickup')
AddEventHandler('Ladders:Client:Pickup', function(LadderNetID)
    if not Carrying and NetworkDoesNetworkIdExist(LadderNetID) then
        NetworkRequestControlOfNetworkId(LadderNetID)
        while not NetworkHasControlOfNetworkId(LadderNetID) do Citizen.Wait(0) end

        local Ladder = NetToObj(LadderNetID)

        DeleteObject(Ladder)
        SetEntityAsNoLongerNeeded(Ladder)

        TriggerServerEvent('Ladders:Server:Ladders:Local', 'add')
        TriggerServerEvent('Ladders:Server:Ladders', 'delete', LadderNetID)

        ClearPedTasksImmediately(PlayerPedId())
    end
end)

RegisterNetEvent('Ladders:Client:PlaceLadder')
AddEventHandler('Ladders:Client:PlaceLadder', function()
    if Carrying then
        local PlayerPed = PlayerPedId()
        local PlayerRot = GetEntityRotation(PlayerPed)
        local Ladder = CreateObjectNoOffset(GetHashKey('prop_byard_ladder01'), GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 1.0, 0.0), true, false, false)
        local LadderNetID = ObjToNet(Ladder)
        local LadderCoords = GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 1.2, 1.32)

        SetEntityAsMissionEntity(LadderNetID)

        TriggerServerEvent('Ladders:Server:Ladders:Local', 'remove')
        TriggerServerEvent('Ladders:Server:Ladders', 'store', LadderNetID)

        SetEntityCoords(Ladder, LadderCoords)
        SetEntityRotation(Ladder, vector3(PlayerRot.x - 20.0, PlayerRot.y, PlayerRot.z))
        FreezeEntityPosition(Ladder, true)

        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingCarried', false)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingClimbed', false)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Dropped', false)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Placed', true)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'x', LadderCoords.x)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'y', LadderCoords.y)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'z', LadderCoords.z)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Topz', LadderCoords.z + 5.0)
        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Bottomz', LadderCoords.z - 5.0)
    end
end)

RegisterNetEvent('Ladders:Client:Climb')
AddEventHandler('Ladders:Client:Climb', function(LadderNetID, Direction)
    if not Carrying then
        local PlayerPed = PlayerPedId()
        local Ladder = NetToObj(LadderNetID)

        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingClimbed', true)

        Climbing = true
        ClimbingLadder = GetEntityRotation(Ladder)

        if not HasAnimDictLoaded('laddersbase') then
            RequestAnimDict('laddersbase')
            while not HasAnimDictLoaded('laddersbase') do Citizen.Wait(0) end
        end

        ClearPedTasksImmediately(PlayerPed)
        FreezeEntityPosition(PlayerPed, true)
        SetEntityCollision(Ladder, false, true)

        Climbing = 'rot'

        for Dir, Pack in pairs(ClimbingVectors) do
            if Direction == Dir then
                for _, Element in pairs(Pack) do
                    SetEntityCoordsNoOffset(PlayerPed, GetOffsetFromEntityInWorldCoords(Ladder, Element[1]), false, false, false)
                    TaskPlayAnim(PlayerPed, Element[2], Element[3], 2.0, 0.0, -1, 15, 0, false, false, false)

                    Citizen.Wait(850)
                end
            end
        end

        if Direction == 'up' then
            SetEntityCoordsNoOffset(PlayerPed, GetOffsetFromEntityInWorldCoords(Ladder, 0.0, 0.5, 4.0), false, false, false)
        elseif Direction == 'down' then
            SetEntityCoordsNoOffset(PlayerPed, GetOffsetFromEntityInWorldCoords(Ladder, 0.0, -0.9, -1.4), false, false, false)
        end

        ClearPedTasksImmediately(PlayerPed)
        FreezeEntityPosition(PlayerPed, false)
        SetEntityCollision(Ladder, true, true)

        Climbing = false

        TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingClimbed', false)
    end
end)

function DrawText3D(x,y,z, text)

    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 500
    DrawRect(_x,_y+0.0125, 0.018+ factor, 0.03, 0, 0, 0, 70)
end

-- Gets distance between player and provided coords
function GetDistanceBetween(Coords)
	return Vdist(GetEntityCoords(PlayerPedId(), false), Coords.x, Coords.y, Coords.z) + 0.01
end

-- Resource Master Loop
Citizen.CreateThread(function()
	while true do
        Citizen.Wait(0)

        local PlayerPed = PlayerPedId()

        if not Carrying then
            if Clipset then
                Clipset = false
                ResetPedMovementClipset(PlayerPed, 0)
            end

            for _, Ladder in pairs(Ladders) do
                -- Return seems to oscillate between `number` and `table`, unclear why
                if type(Ladder) == 'table' then
                    if not Ladder.BeingCarried and Ladder.x and Ladder.y and Ladder.z then
                        if Ladder.Dropped then
                            if GetDistanceBetween(Ladder) <= 2.5 then
								DrawText3D(Ladder.x,Ladder.y,Ladder.z+0.5, Strings[Lang]['textdraw_pickup'])

                                if IsControlJustPressed(0, 38) then TriggerServerEvent('Ladders:Server:Ladders', 'pickup', Ladder.ID) end

                                break
                            end
                        elseif not Ladder.Dropped and Ladder.Placed and not Climbing then
                            if GetDistanceBetween(Ladder) <= 2 then
                                DisableControlAction(0, 23, true) -- Enter vehicle

                                local TopDistance = GetDistanceBetween(vector3(Ladder.x, Ladder.y, Ladder.Topz))
                                local BottomDistance = GetDistanceBetween(vector3(Ladder.x, Ladder.y, Ladder.Bottomz))

								DrawText3D(Ladder.x,Ladder.y,Ladder.z+0.15, '~g~[E]~s~ Grimper l\'échelle ~r~[F]~s~ Ramasser l\'échelle')
								-- DrawText3D(Ladder.x,Ladder.y,Ladder.z, '')
								

                                -- If player is closer to the bottom than the top
                                if IsControlJustPressed(0, 38) then
                                    if TopDistance > BottomDistance then
                                        TriggerServerEvent('Ladders:Server:Ladders', 'climb', Ladder.ID, 'up')
                                    else
                                        TriggerServerEvent('Ladders:Server:Ladders', 'climb', Ladder.ID, 'down')
                                    end
                                elseif IsDisabledControlJustPressed(0, 23) then
                                    TriggerServerEvent('Ladders:Server:Ladders', 'pickup', Ladder.ID)
                                end

                                break
                            end
                        end
                    end
                end
            end

            if Preview then
                ResetEntityAlpha(Preview)
                DeleteObject(Preview)
                SetEntityAsNoLongerNeeded(Preview)
                Preview = false
            end
        else
            if IsPedRunning(PlayerPed) or IsPedSprinting(PlayerPed) then
                if not Clipset then
                    Clipset = true

                    if not HasAnimSetLoaded('MOVE_M@BAIL_BOND_TAZERED') then
                        RequestAnimSet('MOVE_M@BAIL_BOND_TAZERED')
                        while not HasAnimSetLoaded('MOVE_M@BAIL_BOND_TAZERED') do
                            Wait(0)
                        end
                    end

                    SetPedMovementClipset(PlayerPed, 'MOVE_M@BAIL_BOND_TAZERED', 1.0)
                end
            elseif Clipset then
                Clipset = false
                ResetPedMovementClipset(PlayerPed, 1.0)
            end

			exports['mythic_notify']:PersistentAlert('start', 'ladder_E_INFO', 'inform', Strings[Lang]['place_ladder'], { ['background-color'] = '#3D9F30', ['color'] = '#fff' })
			exports['mythic_notify']:PersistentAlert('start', 'ladder_F_INFO', 'inform', Strings[Lang]['drop_ladder'], { ['background-color'] = '#B72020', ['color'] = '#fff' })
			exports['mythic_notify']:PersistentAlert('start', 'ladder_Y_INFO', 'inform', Strings[Lang]['toggle_preview'], { ['background-color'] = '#B0AE19', ['color'] = '#fff' })
			exports['mythic_notify']:PersistentAlert('start', 'ladder_G_INFO', 'inform', Strings[Lang]['fold_ladder'], { ['background-color'] = '#444', ['color'] = '#fff' })
            if IsControlJustPressed(0, 38) then
                TriggerEvent('Ladders:Client:PlaceLadder')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_E_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_F_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_Y_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_G_INFO')
            elseif IsDisabledControlJustPressed(0, 23) then
                TriggerEvent('Ladders:Client:DropLadder')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_E_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_F_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_Y_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_G_INFO')
            elseif IsControlJustPressed(0, 246) then
                if PreviewToggle then
                    PreviewToggle = false
                    PlaySoundFrontend(-1, 'NO', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
                else
                    PreviewToggle = true
                    PlaySoundFrontend(-1, 'YES', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
                end
			else if IsControlJustPressed(0, 47) then
				exports['mythic_notify']:PersistentAlert('end', 'ladder_E_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_F_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_Y_INFO')
				exports['mythic_notify']:PersistentAlert('end', 'ladder_G_INFO')
				TriggerServerEvent('Ladders:Server:Ladders:Local', 'remove')
				TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingCarried', false)
				TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'BeingClimbed', false)
				TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Dropped', false)
				TriggerServerEvent('Ladders:Server:Ladders', 'update', LadderNetID, 'Placed', false)
				TriggerServerEvent('Ladders:Server:GiveItem') -- Gives back Item in Inventory
			end
            end

            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 23, true) -- Enter vehicle
            DisableControlAction(0, 24, true) -- Attack (LMB)
            DisableControlAction(0, 44, true) -- Take Cover
            DisableControlAction(0, 140, true) -- Attack (R)
            DisableControlAction(0, 141, true) -- Attack (Q)
            DisableControlAction(0, 142, true) -- Attack (LMB)
            DisableControlAction(0, 257, true) -- Attack (LMB)
            DisableControlAction(0, 263, true) -- Attack (R)
            DisableControlAction(0, 264, true) -- Attack (Q)

            if not Preview and PreviewToggle then
                local LadderCoords = GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 1.2, 1.32)

                Preview = CreateObjectNoOffset(GetHashKey('prop_byard_ladder01'), LadderCoords, false, false, false)
                SetEntityCollision(Preview, false, false)
                SetEntityAlpha(Preview, 100)
            end

            if Preview and PreviewToggle then
                local LadderCoords = GetOffsetFromEntityInWorldCoords(PlayerPed, 0.0, 1.2, 1.32)
                local LadderRot = GetEntityRotation(PlayerPed)

                SetEntityCoords(Preview, LadderCoords, 1, 0, 0, 1)
                SetEntityRotation(Preview, vector3(LadderRot.x - 20.0, LadderRot.y, LadderRot.z), 2, true)
            end

            if Preview and not PreviewToggle then
                ResetEntityAlpha(Preview)
                DeleteObject(Preview)
                SetEntityAsNoLongerNeeded(Preview)
                Preview = false
            end

        end

        for SourcePed, Ladder in pairs(LocalLadders) do
            if (SourcePed ~= -1) then
                local Bone1 = GetEntityBoneIndexByName(SourcePed, 'BONETAG_NECK')
                local Bone2 = GetEntityBoneIndexByName(SourcePed, 'BONETAG_R_HAND')
                local LadderRot = GetWorldRotationOfEntityBone(SourcePed, Bone1);

                AttachEntityToEntity(Ladder, SourcePed, Bone2, 0.0, 0.0, 0.0, LadderRot.x + 20.0, LadderRot.y + 180.0, LadderRot.z + 90.0, false, false, flase, true, 0, false)
            end
        end

        if Climbing then
            if Climbing == 'rot' and ClimbingLadder then SetEntityRotation(PlayerPed, vector3(ClimbingLadder.x, ClimbingLadder.y, ClimbingLadder.z), 2, true) end

            DisableControlAction(0, 21, true) -- Sprint
            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 23, true) -- Enter vehicle
            DisableControlAction(0, 24, true) -- Attack (LMB)
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 30, true) -- Move Right
            DisableControlAction(0, 31, true) -- Move Back
            DisableControlAction(0, 32, true) -- Move Forward
            DisableControlAction(0, 33, true) -- Move Back
            DisableControlAction(0, 34, true) -- Move Left
            DisableControlAction(0, 35, true) -- Move Right
            DisableControlAction(0, 44, true) -- Take Cover
            DisableControlAction(0, 140, true) -- Attack (R)
            DisableControlAction(0, 141, true) -- Attack (Q)
            DisableControlAction(0, 142, true) -- Attack (LMB)
            DisableControlAction(0, 257, true) -- Attack (LMB)
            DisableControlAction(0, 263, true) -- Attack (R)
            DisableControlAction(0, 264, true) -- Attack (Q)
            DisableControlAction(0, 266, true) -- Move Left
            DisableControlAction(0, 267, true) -- Move Right
            DisableControlAction(0, 268, true) -- Move Up
            DisableControlAction(0, 269, true) -- Move Down
        end

    end
end)

AddEventHandler('onClientMapStart', function()
    TriggerServerEvent('Ladders:Server:PersonalRequest')
end)
