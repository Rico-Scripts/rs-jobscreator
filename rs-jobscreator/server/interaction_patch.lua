local ESX = exports['es_extended']:getSharedObject()

local rawRegisterNetEvent = RegisterNetEvent
local patched = {
    ['rs_jobscreator:server:openBossMenu'] = true,
    ['rs_jobscreator:server:toggleDuty'] = true
}

local function notify(src, message, success)
    TriggerClientEvent(
        'rs_jobscreator:client:notify',
        src,
        tostring(message or ''),
        success ~= false
    )
end

local function getPlayer(src)
    return ESX.GetPlayerFromId(src)
end

local function getCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

local function distanceOk(src, point)
    local coords = getCoords(src)
    if not coords then
        return false
    end

    local px = tonumber(point.x) or 0.0
    local py = tonumber(point.y) or 0.0
    local pz = tonumber(point.z) or 0.0
    local dx = coords.x - px
    local dy = coords.y - py
    local dz = coords.z - pz
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

    local buffer = tonumber(Config.ServerDistanceBuffer) or 3.0
    local allowed = math.max(
        8.0,
        (tonumber(point.radius) or 1.5) + buffer
    )

    return distance <= allowed
end

local function playerAllowed(src, point)
    if tonumber(point.public) == 1 then
        return true
    end

    if not point.job_name or point.job_name == '' then
        return true
    end

    local xPlayer = getPlayer(src)
    if not xPlayer or not xPlayer.job then
        return false
    end

    if xPlayer.job.name ~= point.job_name then
        return false
    end

    return (tonumber(xPlayer.job.grade) or 0)
        >= (tonumber(point.min_grade) or 0)
end

local function bossMenuHandler(...)
    local src = source
    local id = select(1, ...)

    local point = MySQL.single.await([[
        SELECT *
        FROM rs_jobscreator_points
        WHERE id = ?
          AND enabled = 1
          AND type = 'bossmenu'
        LIMIT 1
    ]], { tonumber(id) })

    if not point then
        return notify(src, 'Baasmenu-punt bestaat niet.', false)
    end

    if not distanceOk(src, point) then
        return notify(src, 'Je staat te ver van dit punt.', false)
    end

    if not playerAllowed(src, point) then
        return notify(src, 'Je hebt geen toegang tot dit baasmenu.', false)
    end

    local xPlayer = getPlayer(src)
    if not xPlayer or not xPlayer.job or xPlayer.job.name ~= point.job_name then
        return notify(src, 'Je hebt geen toegang tot dit baasmenu.', false)
    end

    if GetResourceState('rs-bossmenu') ~= 'started' then
        return notify(src, 'rs-bossmenu is niet gestart.', false)
    end

    -- rs-bossmenu valideert zelf of dit grade_name boss of de hoogste grade is.
    TriggerClientEvent(
        'rs-bossmenu:client:open',
        src,
        point.job_name
    )
end

local function dutyHandler(...)
    local src = source
    local id = select(1, ...)

    local point = MySQL.single.await([[
        SELECT *
        FROM rs_jobscreator_points
        WHERE id = ?
          AND enabled = 1
          AND type = 'duty'
        LIMIT 1
    ]], { tonumber(id) })

    if not point then
        return notify(src, 'Dienstpunt bestaat niet.', false)
    end

    if not distanceOk(src, point) then
        return notify(src, 'Je staat te ver van dit punt.', false)
    end

    if not playerAllowed(src, point) then
        return notify(src, 'Je hebt geen toegang tot dit dienstpunt.', false)
    end

    if GetResourceState('rs-duty') ~= 'started' then
        return notify(src, 'rs-duty is niet gestart.', false)
    end

    local ok, success, message = pcall(function()
        return exports['rs-duty']:ToggleDuty(src)
    end)

    if not ok then
        return notify(src, 'Duty systeem gaf een fout.', false)
    end

    local xPlayer = getPlayer(src)
    local onDuty = false

    local stateOk, stateValue = pcall(function()
        return exports['rs-duty']:IsOnDuty(src)
    end)

    if stateOk then
        onDuty = stateValue == true
    end

    -- Houd ESX job-data compatibel met resources die job.onDuty uitlezen.
    if xPlayer then
        if type(xPlayer.job) == 'table' then
            xPlayer.job.onDuty = onDuty
        end

        if xPlayer.getJob then
            local job = xPlayer.getJob()
            if type(job) == 'table' then
                job.onDuty = onDuty
            end
        end
    end

    -- Belangrijk: niet nogmaals via de client toggelen. De export hierboven
    -- heeft de status al exact één keer aangepast.
    notify(
        src,
        message or (success and 'Dienststatus aangepast.' or 'Duty mislukt.'),
        success
    )
end

RegisterNetEvent = function(name, cb)
    if patched[name] and type(cb) == 'function' then
        patched[name] = nil

        if name == 'rs_jobscreator:server:openBossMenu' then
            return rawRegisterNetEvent(name, bossMenuHandler)
        end

        if name == 'rs_jobscreator:server:toggleDuty' then
            return rawRegisterNetEvent(name, dutyHandler)
        end
    end

    return rawRegisterNetEvent(name, cb)
end
