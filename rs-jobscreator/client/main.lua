local ESX = exports['es_extended']:getSharedObject()


-- =========================================================
-- STATE
-- =========================================================

local points = {}

local creatorOpen = false

local spawnedVehicle = nil

local progressBusy = false

local textUiVisible = false


-- =========================================================
-- HELPERS
-- =========================================================

local function notify(message, success)
    message =
        tostring(
            message or ''
        )

    if lib
        and lib.notify then

        lib.notify({
            title = 'RS Jobs Creator',

            description =
                message,

            type =
                success == false
                and 'error'
                or 'success'
        })

        return
    end

    ESX.ShowNotification(
        message
    )
end


local function decodeSettings(settings)
    if type(settings) == 'table' then
        return settings
    end

    if type(settings) ~= 'string'
        or settings == '' then

        return {}
    end

    local ok, decoded =
        pcall(
            json.decode,
            settings
        )

    if not ok
        or type(decoded) ~= 'table' then

        return {}
    end

    return decoded
end


local function serverCallback(
    name,
    data,
    cb
)
    ESX.TriggerServerCallback(
        'rs_jobscreator:' .. name,

        function(response)
            response =
                response
                or {
                    success = false,

                    message =
                        'Geen antwoord van de server.'
                }

            if cb then
                cb(response)
            end
        end,

        data or {}
    )
end


-- =========================================================
-- NOTIFICATIONS
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:client:notify',
    function(message, success)
        notify(
            message,
            success
        )
    end
)


-- =========================================================
-- CREATOR UI
-- =========================================================

local function openCreator(state)
    creatorOpen =
        true

    SetNuiFocus(
        true,
        true
    )

    SetNuiFocusKeepInput(
        false
    )

    SendNUIMessage({
        action = 'open',

        data =
            state or {}
    })
end


local function refreshCreator(state)
    SendNUIMessage({
        action = 'refresh',

        data =
            state or {}
    })
end


local function closeCreator()
    creatorOpen =
        false

    SetNuiFocus(
        false,
        false
    )

    SetNuiFocusKeepInput(
        false
    )

    SendNUIMessage({
        action = 'close'
    })
end


local function requestCreatorState(openPanel)
    serverCallback(
        'getState',
        {},

        function(response)
            if response.success == false then
                notify(
                    response.message
                    or 'Kon Jobs Creator niet laden.',
                    false
                )

                return
            end

            if openPanel then
                openCreator(
                    response
                )
            else
                refreshCreator(
                    response
                )
            end
        end
    )
end


-- Server vraagt UI te openen
RegisterNetEvent(
    'rs_jobscreator:client:open',
    function(state)
        if type(state) == 'table'
            and (
                state.jobs
                or state.points
                or state.grades
            ) then

            openCreator(
                state
            )

            return
        end

        requestCreatorState(
            true
        )
    end
)


-- Server stuurt nieuwe state
RegisterNetEvent(
    'rs_jobscreator:client:setState',
    function(state)
        if type(state) ~= 'table' then
            return
        end

        if creatorOpen then
            refreshCreator(
                state
            )
        else
            openCreator(
                state
            )
        end
    end
)


-- Handmatig sluiten vanuit server/client
RegisterNetEvent(
    'rs_jobscreator:client:close',
    function()
        closeCreator()
    end
)


-- =========================================================
-- POINTS
-- =========================================================

local function refreshPoints()
    serverCallback(
        'getPoints',
        {},

        function(response)
            if response.success == false then
                print(
                    (
                        '[rs-jobscreator] getPoints mislukt: %s'
                    ):format(
                        tostring(
                            response.message
                        )
                    )
                )

                return
            end

            points =
                response.points
                or response.data
                or {}
        end
    )
end


RegisterNetEvent(
    'rs_jobscreator:client:refreshPoints',
    function()
        refreshPoints()
    end
)


-- =========================================================
-- PROGRESS
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:client:progress',
    function(duration, label)
        if progressBusy then
            return
        end

        progressBusy =
            true

        duration =
            tonumber(
                duration
            )
            or 5000

        label =
            label
            or 'Bezig...'

        local completed =
            true

        if lib
            and lib.progressCircle then

            completed =
                lib.progressCircle({
                    duration =
                        duration,

                    label =
                        label,

                    position =
                        'bottom',

                    useWhileDead =
                        false,

                    canCancel =
                        true,

                    disable = {
                        move = true,
                        car = true,
                        combat = true
                    }
                })
        else
            Wait(
                duration
            )
        end

        progressBusy =
            false

        if completed == false then
            notify(
                'Actie geannuleerd.',
                false
            )
        end
    end
)


-- =========================================================
-- STASH
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:client:openStash',
    function(stashId)
        if GetResourceState(
            'ox_inventory'
        ) ~= 'started' then

            return notify(
                'ox_inventory is niet gestart.',
                false
            )
        end

        exports.ox_inventory:openInventory(
            'stash',
            stashId
        )
    end
)


-- =========================================================
-- TELEPORT
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:client:teleport',
    function(destination, allowVehicle)
        if type(destination) ~= 'table'
            or destination.x == nil
            or destination.y == nil
            or destination.z == nil then

            return notify(
                'Ongeldige teleportbestemming.',
                false
            )
        end

        local ped =
            PlayerPedId()

        local x =
            tonumber(
                destination.x
            )
            or 0.0

        local y =
            tonumber(
                destination.y
            )
            or 0.0

        local z =
            tonumber(
                destination.z
            )
            or 0.0

        local heading =
            tonumber(
                destination.w
            )
            or 0.0


        if allowVehicle
            and IsPedInAnyVehicle(
                ped,
                false
            ) then

            local vehicle =
                GetVehiclePedIsIn(
                    ped,
                    false
                )

            SetEntityCoords(
                vehicle,
                x,
                y,
                z,
                false,
                false,
                false,
                false
            )

            SetEntityHeading(
                vehicle,
                heading
            )

            return
        end


        SetEntityCoords(
            ped,
            x,
            y,
            z,
            false,
            false,
            false,
            false
        )

        SetEntityHeading(
            ped,
            heading
        )
    end
)


-- =========================================================
-- DUTY CLIENT UPDATE
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:client:toggleDuty',
    function()
        if GetResourceState(
            'rs-duty'
        ) == 'started' then

            TriggerServerEvent(
                'rs-duty:server:toggle'
            )

            return
        end

        TriggerServerEvent(
            'rs_jobscreator:server:toggleDuty'
        )
    end
)


-- =========================================================
-- VEHICLE MODEL
-- =========================================================

local function loadVehicleModel(model)
    local hash =
        type(model) == 'number'
        and model
        or joaat(
            tostring(
                model
            )
        )

    if not IsModelInCdimage(
        hash
    )
        or not IsModelAVehicle(
            hash
        ) then

        return nil
    end

    RequestModel(
        hash
    )

    local timeout =
        GetGameTimer()
        + 5000

    while not HasModelLoaded(
        hash
    )
        and GetGameTimer()
        < timeout do

        Wait(
            25
        )
    end

    if not HasModelLoaded(
        hash
    ) then

        return nil
    end

    return hash
end


-- =========================================================
-- VEHICLE SPAWN
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:client:spawnVehicle',
    function(model, label)
        local hash =
            loadVehicleModel(
                model
            )

        if not hash then
            return notify(
                (
                    'Voertuigmodel %s bestaat niet.'
                ):format(
                    tostring(
                        model
                    )
                ),
                false
            )
        end

        local ped =
            PlayerPedId()

        local coords =
            GetEntityCoords(
                ped
            )

        local heading =
            GetEntityHeading(
                ped
            )


        if spawnedVehicle
            and DoesEntityExist(
                spawnedVehicle
            ) then

            DeleteEntity(
                spawnedVehicle
            )

            spawnedVehicle =
                nil
        end


        local vehicle =
            CreateVehicle(
                hash,

                coords.x,
                coords.y,
                coords.z,

                heading,

                true,
                false
            )

        if not vehicle
            or vehicle == 0 then

            SetModelAsNoLongerNeeded(
                hash
            )

            return notify(
                'Voertuig kon niet worden gespawned.',
                false
            )
        end


        SetVehicleOnGroundProperly(
            vehicle
        )

        SetVehicleNumberPlateText(
            vehicle,
            'RSJOB'
        )

        SetEntityAsMissionEntity(
            vehicle,
            true,
            true
        )

        SetPedIntoVehicle(
            ped,
            vehicle,
            -1
        )

        spawnedVehicle =
            vehicle

        SetModelAsNoLongerNeeded(
            hash
        )


        notify(
            (
                'Werkvoertuig %s uitgegeven.'
            ):format(
                tostring(
                    label
                    or model
                )
            ),
            true
        )
    end
)


-- =========================================================
-- POINT MENU
-- =========================================================

local function openPointMenu(point)
    if not point then
        return
    end


    if not lib
        or not lib.registerContext
        or not lib.showContext then

        return notify(
            'ox_lib context menu is niet beschikbaar.',
            false
        )
    end


    local settings =
        decodeSettings(
            point.settings
        )

    local pointType =
        tostring(
            point.type
            or ''
        )

    local options =
        {}


    -- =====================================================
    -- STASH / ARMORY
    -- =====================================================

    if pointType == 'stash'
        or pointType == 'armory' then

        options[#options + 1] = {
            title =
                point.label
                or 'Opslag',

            description =
                pointType == 'armory'
                and 'Open wapenkamer'
                or 'Open opslag',

            icon =
                settings.icon
                or 'fa-solid fa-box-open',

            onSelect =
                function()
                    TriggerServerEvent(
                        'rs_jobscreator:server:openStorage',
                        point.id,
                        pointType
                    )
                end
        }


    -- =====================================================
    -- SHOP
    -- =====================================================

    elseif pointType == 'shop'
        or pointType == 'jobshop'
        or pointType == 'market' then

        for _,
            item
        in ipairs(
            settings.items
            or {}
        ) do

            local currentItem =
                item

            options[#options + 1] = {
                title =
                    currentItem.label
                    or currentItem.name
                    or 'Product',

                description =
                    (
                        '€%s per stuk'
                    ):format(
                        tonumber(
                            currentItem.price
                        )
                        or 0
                    ),

                icon =
                    settings.icon
                    or 'fa-solid fa-cart-shopping',

                onSelect =
                    function()
                        local input =
                            lib.inputDialog(
                                'Aantal kopen',
                                {
                                    {
                                        type =
                                            'number',

                                        label =
                                            'Aantal',

                                        required =
                                            true,

                                        default =
                                            1,

                                        min =
                                            1,

                                        max =
                                            100
                                    }
                                }
                            )

                        if not input
                            or not input[1] then

                            return
                        end

                        TriggerServerEvent(
                            'rs_jobscreator:server:buyItem',

                            point.id,

                            currentItem.name,

                            tonumber(
                                input[1]
                            )
                        )
                    end
            }
        end


    -- =====================================================
    -- CRAFTING
    -- =====================================================

    elseif pointType == 'crafting' then

        for index,
            recipe
        in ipairs(
            settings.recipes
            or {}
        ) do

            local recipeIndex =
                index

            local currentRecipe =
                recipe

            local ingredients =
                {}

            for itemName,
                count
            in pairs(
                currentRecipe.ingredients
                or {}
            ) do

                ingredients[
                    #ingredients + 1
                ] =
                    (
                        '%sx %s'
                    ):format(
                        count,
                        itemName
                    )
            end


            options[#options + 1] = {
                title =
                    currentRecipe.label
                    or currentRecipe.result
                    or 'Recept',

                description =
                    #ingredients > 0
                    and table.concat(
                        ingredients,
                        ', '
                    )
                    or 'Geen ingrediënten',

                icon =
                    settings.icon
                    or 'fa-solid fa-hammer',

                onSelect =
                    function()
                        TriggerServerEvent(
                            'rs_jobscreator:server:craft',
                            point.id,
                            recipeIndex
                        )
                    end
            }
        end


    -- =====================================================
    -- HARVEST
    -- =====================================================

    elseif pointType == 'harvest' then

        options[#options + 1] = {
            title =
                point.label
                or 'Verzamelen',

            description =
                settings.item
                or 'Item verzamelen',

            icon =
                settings.icon
                or 'fa-solid fa-tree',

            onSelect =
                function()
                    TriggerServerEvent(
                        'rs_jobscreator:server:harvest',
                        point.id
                    )
                end
        }


    -- =====================================================
    -- PROCESS
    -- =====================================================

    elseif pointType == 'process' then

        local inputItem =
            settings.input
            and settings.input.item

        local outputItem =
            settings.output
            and settings.output.item

        local description =
            'Verwerk grondstoffen'

        if inputItem
            and outputItem then

            description =
                (
                    '%s → %s'
                ):format(
                    tostring(
                        inputItem
                    ),
                    tostring(
                        outputItem
                    )
                )
        end


        options[#options + 1] = {
            title =
                point.label
                or 'Verwerken',

            description =
                description,

            icon =
                settings.icon
                or 'fa-solid fa-gears',

            onSelect =
                function()
                    TriggerServerEvent(
                        'rs_jobscreator:server:process',
                        point.id
                    )
                end
        }


    -- =====================================================
    -- GARAGE
    -- =====================================================

    elseif pointType == 'garage' then

        for index,
            vehicle
        in ipairs(
            settings.vehicles
            or {}
        ) do

            local vehicleIndex =
                index

            local currentVehicle =
                vehicle

            options[#options + 1] = {
                title =
                    currentVehicle.label
                    or currentVehicle.model
                    or 'Voertuig',

                description =
                    tostring(
                        currentVehicle.model
                        or ''
                    ),

                icon =
                    settings.icon
                    or 'fa-solid fa-car',

                onSelect =
                    function()
                        TriggerServerEvent(
                            'rs_jobscreator:server:spawnVehicle',
                            point.id,
                            vehicleIndex
                        )
                    end
            }
        end


    -- =====================================================
    -- TELEPORT
    -- =====================================================

    elseif pointType == 'teleport' then

        options[#options + 1] = {
            title =
                point.label
                or 'Teleporteren',

            description =
                'Ga naar de ingestelde bestemming',

            icon =
                settings.icon
                or 'fa-solid fa-location-arrow',

            onSelect =
                function()
                    TriggerServerEvent(
                        'rs_jobscreator:server:teleport',
                        point.id
                    )
                end
        }


    -- =====================================================
    -- DUTY
    -- =====================================================

    elseif pointType == 'duty' then

        local onDuty =
            LocalPlayer.state.rsDuty
            == true

        options[#options + 1] = {
            title =
                point.label
                or 'Dienst',

            description =
                onDuty
                and 'Ga uit dienst'
                or 'Ga in dienst',

            icon =
                settings.icon
                or 'fa-solid fa-user-clock',

            onSelect =
                function()
                    TriggerServerEvent(
                        'rs_jobscreator:server:toggleDuty',
                        point.id
                    )
                end
        }


    -- =====================================================
    -- BOSS MENU
    -- =====================================================

    elseif pointType == 'bossmenu' then

        options[#options + 1] = {
            title =
                point.label
                or 'Baasmenu',

            description =
                'Open bedrijfsbeheer',

            icon =
                settings.icon
                or 'fa-solid fa-user-tie',

            onSelect =
                function()
                    TriggerServerEvent(
                        'rs_jobscreator:server:openBossMenu',
                        point.id
                    )
                end
        }
    end


    if #options == 0 then
        return notify(
            'Dit punt heeft geen geldige instellingen.',
            false
        )
    end


    local contextId =
        (
            'rs_jobscreator_point_%s'
        ):format(
            tostring(
                point.id
            )
        )


    lib.registerContext({
        id =
            contextId,

        title =
            point.label
            or 'Interactie',

        options =
            options
    })


    lib.showContext(
        contextId
    )
end


-- =========================================================
-- POINT VISIBILITY
-- =========================================================

local function canSeePoint(point)
    if not point then
        return false
    end


    if tonumber(
        point.public
    ) == 1 then

        return true
    end


    if not point.job_name
        or point.job_name == '' then

        return true
    end


    local data =
        ESX.GetPlayerData()

    if not data
        or not data.job then

        return false
    end


    if data.job.name
        ~= point.job_name then

        return false
    end


    return (
        tonumber(
            data.job.grade
        )
        or 0
    ) >= (
        tonumber(
            point.min_grade
        )
        or 0
    )
end


-- =========================================================
-- PLAYER LOADED
-- =========================================================

CreateThread(
    function()
        while not ESX.IsPlayerLoaded() do
            Wait(
                500
            )
        end

        Wait(
            1000
        )

        refreshPoints()
    end
)


RegisterNetEvent(
    'esx:playerLoaded',
    function()
        Wait(
            1000
        )

        refreshPoints()
    end
)


RegisterNetEvent(
    'esx:setJob',
    function()
        Wait(
            250
        )

        refreshPoints()
    end
)


-- =========================================================
-- MARKER LOOP
-- =========================================================

CreateThread(
    function()
        while true do
            local wait =
                1000

            local ped =
                PlayerPedId()

            local coords =
                GetEntityCoords(
                    ped
                )

            local shouldShowText =
                false


            for _,
                point
            in ipairs(
                points
            ) do

                if tonumber(
                    point.enabled
                ) == 1
                    and canSeePoint(
                        point
                    ) then

                    local pcoords =
                        vector3(
                            tonumber(
                                point.x
                            )
                            or 0.0,

                            tonumber(
                                point.y
                            )
                            or 0.0,

                            tonumber(
                                point.z
                            )
                            or 0.0
                        )

                    local distance =
                        #(
                            coords
                            - pcoords
                        )


                    if distance <= (
                        tonumber(
                            Config.PointDrawDistance
                        )
                        or 25.0
                    ) then

                        wait =
                            0


                        local marker =
                            Config.Marker
                            or {}


                        local markerType =
                            tonumber(
                                marker.type
                            )
                            or 1


                        local scale =
                            marker.scale
                            or {
                                x = 0.35,
                                y = 0.35,
                                z = 0.35
                            }


                        local colour =
                            marker.colour
                            or {
                                r = 0,
                                g = 150,
                                b = 255,
                                a = 180
                            }


                        DrawMarker(
                            markerType,

                            pcoords.x,
                            pcoords.y,
                            pcoords.z + 0.12,

                            0.0,
                            0.0,
                            0.0,

                            0.0,
                            180.0,
                            0.0,

                            tonumber(
                                scale.x
                            )
                            or 0.35,

                            tonumber(
                                scale.y
                            )
                            or 0.35,

                            tonumber(
                                scale.z
                            )
                            or 0.35,

                            tonumber(
                                colour.r
                            )
                            or 0,

                            tonumber(
                                colour.g
                            )
                            or 150,

                            tonumber(
                                colour.b
                            )
                            or 255,

                            tonumber(
                                colour.a
                            )
                            or 180,

                            false,
                            true,
                            2,
                            false,
                            nil,
                            nil,
                            false
                        )


                        local interactDistance =
                            math.max(
                                1.0,

                                tonumber(
                                    point.radius
                                )
                                or tonumber(
                                    Config.InteractDistance
                                )
                                or 1.5
                            )


                        if distance
                            <= interactDistance then

                            shouldShowText =
                                true


                            if lib
                                and lib.showTextUI
                                and not textUiVisible then

                                local settings =
                                    decodeSettings(
                                        point.settings
                                    )

                                lib.showTextUI(
                                    (
                                        '[E] %s'
                                    ):format(
                                        point.label
                                        or 'Interactie'
                                    ),
                                    {
                                        icon =
                                            settings.icon
                                            or 'fa-solid fa-briefcase'
                                    }
                                )

                                textUiVisible =
                                    true
                            end


                            if IsControlJustReleased(
                                0,
                                38
                            ) then

                                openPointMenu(
                                    point
                                )
                            end
                        end
                    end
                end
            end


            if not shouldShowText
                and textUiVisible then

                if lib
                    and lib.hideTextUI then

                    lib.hideTextUI()
                end

                textUiVisible =
                    false
            end


            Wait(
                wait
            )
        end
    end
)


-- =========================================================
-- ADMIN COMMAND
-- =========================================================

local openCommand =
    Config.OpenCommand
    or 'jobscreator'


RegisterCommand(
    openCommand,

    function()
        TriggerServerEvent(
            'rs_jobscreator:server:requestState'
        )
    end,

    false
)


if Config.OpenKey
    and Config.OpenKey ~= '' then

    RegisterKeyMapping(
        openCommand,

        'Open RS Jobs Creator',

        'keyboard',

        Config.OpenKey
    )
end


-- =========================================================
-- EMERGENCY CLOSE COMMAND
-- =========================================================

RegisterCommand(
    'closejobscreator',

    function()
        closeCreator()

        notify(
            'Jobs Creator gesloten.',
            true
        )
    end,

    false
)


-- =========================================================
-- NUI - READY
-- =========================================================

RegisterNUICallback(
    'ready',

    function(_, cb)
        cb({
            success = true
        })
    end
)


-- =========================================================
-- NUI - CLOSE
-- =========================================================

RegisterNUICallback(
    'close',

    function(_, cb)
        closeCreator()

        cb({
            success = true
        })
    end
)


-- =========================================================
-- NUI - REFRESH
-- =========================================================

RegisterNUICallback(
    'refresh',

    function(_, cb)
        serverCallback(
            'getState',
            {},

            function(response)
                if response.success then
                    refreshCreator(
                        response
                    )
                end

                cb(
                    response
                )
            end
        )
    end
)


-- =========================================================
-- NUI - JOBS
-- =========================================================

RegisterNUICallback(
    'saveJob',

    function(data, cb)
        serverCallback(
            'saveJob',
            data,

            function(response)
                if response.success then
                    requestCreatorState(
                        false
                    )
                end

                cb(
                    response
                )
            end
        )
    end
)


RegisterNUICallback(
    'deleteJob',

    function(data, cb)
        serverCallback(
            'deleteJob',
            data,

            function(response)
                if response.success then
                    requestCreatorState(
                        false
                    )
                end

                cb(
                    response
                )
            end
        )
    end
)


-- =========================================================
-- NUI - GRADES
-- =========================================================

RegisterNUICallback(
    'saveGrade',

    function(data, cb)
        serverCallback(
            'saveGrade',
            data,

            function(response)
                if response.success then
                    requestCreatorState(
                        false
                    )
                end

                cb(
                    response
                )
            end
        )
    end
)


RegisterNUICallback(
    'deleteGrade',

    function(data, cb)
        serverCallback(
            'deleteGrade',
            data,

            function(response)
                if response.success then
                    requestCreatorState(
                        false
                    )
                end

                cb(
                    response
                )
            end
        )
    end
)


-- =========================================================
-- NUI - POINTS
-- =========================================================

RegisterNUICallback(
    'savePoint',

    function(data, cb)
        serverCallback(
            'savePoint',
            data,

            function(response)
                if response.success then
                    refreshPoints()

                    requestCreatorState(
                        false
                    )
                end

                cb(
                    response
                )
            end
        )
    end
)


RegisterNUICallback(
    'deletePoint',

    function(data, cb)
        serverCallback(
            'deletePoint',
            data,

            function(response)
                if response.success then
                    refreshPoints()

                    requestCreatorState(
                        false
                    )
                end

                cb(
                    response
                )
            end
        )
    end
)


-- =========================================================
-- NUI - IMPORTER
-- =========================================================

RegisterNUICallback(
    'getImportResources',

    function(_, cb)
        serverCallback(
            'getImportResources',
            {},
            cb
        )
    end
)


RegisterNUICallback(
    'scanResource',

    function(data, cb)
        serverCallback(
            'scanResource',
            data,
            cb
        )
    end
)


RegisterNUICallback(
    'getLastResourceScan',

    function(_, cb)
        serverCallback(
            'getLastResourceScan',
            {},
            cb
        )
    end
)


-- =========================================================
-- NUI - INVENTORY ITEMS
-- =========================================================

RegisterNUICallback(
    'getInventoryItems',

    function(_, cb)
        serverCallback(
            'getInventoryItems',
            {},
            cb
        )
    end
)


-- =========================================================
-- RESOURCE STOP CLEANUP
-- =========================================================

AddEventHandler(
    'onResourceStop',

    function(resource)
        if resource
            ~= GetCurrentResourceName() then

            return
        end


        creatorOpen =
            false


        SetNuiFocus(
            false,
            false
        )


        SetNuiFocusKeepInput(
            false
        )


        if lib
            and lib.hideTextUI then

            pcall(
                lib.hideTextUI
            )
        end


        textUiVisible =
            false


        if spawnedVehicle
            and DoesEntityExist(
                spawnedVehicle
            ) then

            DeleteEntity(
                spawnedVehicle
            )
        end


        spawnedVehicle =
            nil
    end
)