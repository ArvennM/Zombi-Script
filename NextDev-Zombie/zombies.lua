-- Next Level Development 
--    CEO ArvenM. 

local Shooting = false
local Running = false
local InVehicle = false
local HornPressed = false

local SafeZones = {
    {x = 450.5966, y = -998.9636, z = 28.4284, radius = 80.0},-- Mission Row
    {x = 1853.6666, y = 3688.0222, z = 33.2777, radius = 40.0},-- Sandy Shores
    {x = -104.1444, y = 6469.3888, z = 30.6333, radius = 60.0}-- Paleto Bay
}

DecorRegister('RegisterZombie', 2)

AddRelationshipGroup('ZOMBIE')
SetRelationshipBetweenGroups(0, GetHashKey('ZOMBIE'), GetHashKey('PLAYER'))
SetRelationshipBetweenGroups(3, GetHashKey('PLAYER'), GetHashKey('ZOMBIE'))

function IsPlayerShooting()
    return Shooting
end

function IsPlayerRunning()
    return Running
end

function IsPlayerInVehicle()
    return InVehicle
end

function IsHornPressed()
    return HornPressed
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        -- Peds
        SetPedDensityMultiplierThisFrame(9.0)  -- Zombi yoğunluğunu daha da artırdık
        SetScenarioPedDensityMultiplierThisFrame(9.0, 9.0)  -- Zombi yoğunluğunu daha da artırdık

        -- Vehicles
        SetRandomVehicleDensityMultiplierThisFrame(0.0)
        SetParkedVehicleDensityMultiplierThisFrame(0.0)
        SetVehicleDensityMultiplierThisFrame(0.0)

        -- Disable ambient sounds
        SetAudioFlag("DisableFlightMusic", true)
        SetAudioFlag("PoliceScannerDisabled", true)
        StartAudioScene("SILENCE_SCENE")
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local playerPed = PlayerPedId()

        if IsPedShooting(playerPed) then
            Shooting = true
            Citizen.Wait(5000)
            Shooting = false
        end

        if IsPedSprinting(playerPed) or IsPedRunning(playerPed) then
            Running = true
        else
            Running = false
        end

        InVehicle = IsPedInAnyVehicle(playerPed, false)
        
        if InVehicle then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            HornPressed = IsHornActive(vehicle)
        else
            HornPressed = false
        end
    end
end)

Citizen.CreateThread(function()
    for _, zone in pairs(SafeZones) do
        local Blip = AddBlipForRadius(zone.x, zone.y, zone.z, zone.radius)
        SetBlipHighDetail(Blip, true)
        SetBlipColour(Blip, 2)
        SetBlipAlpha(Blip, 128)
    end

    while true do
        Citizen.Wait(0)

        for _, zone in pairs(SafeZones) do
            local Zombie = -1
            local Success = false
            local Handler, Zombie = FindFirstPed()

            repeat
                if IsPedHuman(Zombie) and not IsPedAPlayer(Zombie) and not IsPedDeadOrDying(Zombie, true) then
                    local pedcoords = GetEntityCoords(Zombie)
                    local zonecoords = vector3(zone.x, zone.y, zone.z)
                    local distance = #(zonecoords - pedcoords)

                    if distance <= zone.radius then
                        DeleteEntity(Zombie)
                    end
                end

                Success, Zombie = FindNextPed(Handler)
            until not (Success)

            EndFindPed(Handler)
        end
        
        local Zombie = -1
        local Success = false
        local Handler, Zombie = FindFirstPed()

        repeat
            Citizen.Wait(10)

            if IsPedHuman(Zombie) and not IsPedAPlayer(Zombie) and not IsPedDeadOrDying(Zombie, true) then
                if not DecorExistOn(Zombie, 'RegisterZombie') then
                    ClearPedTasks(Zombie)
                    ClearPedSecondaryTask(Zombie)
                    ClearPedTasksImmediately(Zombie)
                    TaskWanderStandard(Zombie, 10.0, 10)
                    SetPedRelationshipGroupHash(Zombie, 'ZOMBIE')
                    ApplyPedDamagePack(Zombie, 'BigHitByVehicle', 0.0, 1.0)
                    SetEntityHealth(Zombie, 200)

                    RequestAnimSet('move_m@drunk@verydrunk')
                    while not HasAnimSetLoaded('move_m@drunk@verydrunk') do
                        Citizen.Wait(0)
                    end
                    SetPedMovementClipset(Zombie, 'move_m@drunk@verydrunk', 1.0)

                    SetPedConfigFlag(Zombie, 100, false)
                    DecorSetBool(Zombie, 'RegisterZombie', true)
                end

                SetPedRagdollBlockingFlags(Zombie, 1)
                SetPedCanRagdollFromPlayerImpact(Zombie, false)
                SetPedSuffersCriticalHits(Zombie, true)
                SetPedEnableWeaponBlocking(Zombie, true)
                DisablePedPainAudio(Zombie, true)
                StopPedSpeaking(Zombie, true)
                SetPedDiesWhenInjured(Zombie, false)
                StopPedRingtone(Zombie)
                SetPedMute(Zombie)
                SetPedIsDrunk(Zombie, true)
                SetPedConfigFlag(Zombie, 166, false)
                SetPedConfigFlag(Zombie, 170, false)
                SetBlockingOfNonTemporaryEvents(Zombie, true)
                SetPedCanEvasiveDive(Zombie, false)
                RemoveAllPedWeapons(Zombie, true)

                local PlayerCoords = GetEntityCoords(PlayerPedId())
                local PedCoords = GetEntityCoords(Zombie)
                local Distance = #(PedCoords - PlayerCoords)
                local DistanceTarget = 1.9

                local playerHeading = GetEntityHeading(PlayerPedId())
                local zombieHeading = GetEntityHeading(Zombie)
                local angleDiff = math.abs(playerHeading - zombieHeading)
                
                local shouldChase = false

                if Distance <= DistanceTarget and not IsPlayerInVehicle() then
                    if angleDiff <= 190 or angleDiff >= 270 then
                        shouldChase = true
                    end
                end

                if IsPlayerShooting() or IsPlayerRunning() or IsPlayerInVehicle() or IsHornPressed() then
                    local soundDistance = IsPlayerShooting() and 120.0 or (IsPlayerRunning() and 50.0 or 100.0)
                    if IsPlayerInVehicle() then
                        soundDistance = IsHornPressed() and 150.0 or 100.0
                    end
                    if Distance <= soundDistance then
                        shouldChase = true
                    end
                end

                if shouldChase then
                    TaskGoToEntity(Zombie, PlayerPedId(), -1, 0.0, 2.0, 1073741824, 0)
                end

                if Distance <= 1.3 and not IsPlayerInVehicle() then
                    if not IsPedRagdoll(Zombie) and not IsPedGettingUp(Zombie) then
                        local health = GetEntityHealth(PlayerPedId())
                        if health == 0 then
                            ClearPedTasks(Zombie)
                            TaskWanderStandard(Zombie, 10.0, 10)
                        else
                            RequestAnimSet('melee@unarmed@streamed_core_fps')
                            while not HasAnimSetLoaded('melee@unarmed@streamed_core_fps') do
                                Citizen.Wait(10)
                            end

                            TaskPlayAnim(Zombie, 'melee@unarmed@streamed_core_fps', 'ground_attack_0_psycho', 8.0, 1.0, -1, 48, 0.001, false, false, false)

                            ApplyDamageToPed(PlayerPedId(), 5, false)
                        end
                    end
                end
                
                -- Zombilerin araçların camlarını kırması
                local nearbyVehicle = GetClosestVehicle(PedCoords.x, PedCoords.y, PedCoords.z, 3.0, 0, 70)
                if DoesEntityExist(nearbyVehicle) then
                    SmashVehicleWindow(nearbyVehicle, 0)
                    SmashVehicleWindow(nearbyVehicle, 1)
                    SmashVehicleWindow(nearbyVehicle, 2)
                    SmashVehicleWindow(nearbyVehicle, 3)
                end
                
                if not NetworkGetEntityIsNetworked(Zombie) then
                    DeleteEntity(Zombie)
                end
            end
            
            Success, Zombie = FindNextPed(Handler)
        until not (Success)

        EndFindPed(Handler)
    end
end)

-- Zombilerin oyuncudan uzakta spawn olması için 
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000) -- 2  saniyede bir kontrol et
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- Oyuncunun önünde 5-6 araba ilerisinde bir nokta belirle
        local spawnDistance = math.random(130, 150) --  araba mesafesi yaklaşık 100-150 birim
        local playerHeading = GetEntityHeading(playerPed)
        local spawnX = playerCoords.x + spawnDistance * math.sin(math.rad(-playerHeading))
        local spawnY = playerCoords.y + spawnDistance * math.cos(math.rad(-playerHeading))
        local _, spawnZ = GetGroundZFor_3dCoord(spawnX, spawnY, playerCoords.z + 100.0, 0)
        
        -- Zombi oluştur
        local zombieHash = GetHashKey("a_m_m_beach_01") -- Örnek bir ped modeli
        RequestModel(zombieHash)
        while not HasModelLoaded(zombieHash) do
            Citizen.Wait(1)
        end
        
        local zombie = CreatePed(4, zombieHash, spawnX, spawnY, spawnZ, 0.0, true, false)
        SetModelAsNoLongerNeeded(zombieHash)
    end
end)