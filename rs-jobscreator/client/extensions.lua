local ESX = exports['es_extended']:getSharedObject()

local function serverCallback(name, data, cb)
    ESX.TriggerServerCallback(
        'rs_jobscreator:' .. name,
        function(response)
            if cb then
                cb(response or {
                    success = false,
                    message = 'Geen antwoord van de server.'
                })
            end
        end,
        data or {}
    )
end

RegisterNUICallback('getJobImportResources', function(_, cb)
    serverCallback('getJobImportResources', {}, cb)
end)

RegisterNUICallback('scanJobDefinitions', function(data, cb)
    serverCallback('scanJobDefinitions', data, cb)
end)

RegisterNUICallback('importJobDefinition', function(data, cb)
    serverCallback('importJobDefinition', data, cb)
end)
