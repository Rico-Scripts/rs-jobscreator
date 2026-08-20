local RESOURCE = GetCurrentResourceName()
local rawPrint = print

-- Houd scanner-debug stil wanneer Config.Debug uit staat zonder scanner.lua
-- te hoeven dupliceren of hardcoded debugregels te laten spammen.
if not Config.Debug then
    print = function(...)
        local first = select(1, ...)

        if type(first) == 'string'
            and first:find('^%[rs%-jobscreator:scanner%]') then

            return
        end

        rawPrint(...)
    end
end

local ESX = exports['es_extended']:getSharedObject()

local function safeIdentifier(source)
    if not source or source <= 0 then
        return 'console'
    end

    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer and xPlayer.identifier then
        return xPlayer.identifier
    end

    return GetPlayerIdentifier(source, 0)
        or ('source:%s'):format(source)
end

local function safePlayerName(source)
    if not source or source <= 0 then
        return 'Console'
    end

    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer and xPlayer.getName then
        local ok, name = pcall(xPlayer.getName)

        if ok and name and name ~= '' then
            return name
        end
    end

    return GetPlayerName(source)
        or ('Player %s'):format(source)
end

local function reportCallbackFailure(name, source, err)
    err = tostring(err or 'Onbekende fout')

    rawPrint((
        '[%s] [CALLBACK ERROR] %s | source=%s | %s'
    ):format(
        RESOURCE,
        tostring(name),
        tostring(source),
        err
    ))

    pcall(function()
        MySQL.insert.await([[
            INSERT INTO `rs_jobscreator_logs`
                (`identifier`, `job_name`, `action`, `details`)
            VALUES (?, NULL, ?, ?)
        ]], {
            safeIdentifier(source),
            ('failed_%s'):format(tostring(name):gsub('[^%w_%-]', '_')),
            json.encode({
                callback = name,
                error = err,
                staff = safePlayerName(source),
                source = source
            })
        })
    end)

    local webhookUrl =
        Config.WebhookUrl
        or Config.Webhook
        or ''

    if webhookUrl == '' then
        return
    end

    local description = (
        '**Callback:** `%s`\n' ..
        '**Staff:** %s\n' ..
        '**Identifier:** `%s`\n' ..
        '**Fout:** ```%s```'
    ):format(
        tostring(name),
        safePlayerName(source),
        safeIdentifier(source),
        err:sub(1, 1400)
    )

    PerformHttpRequest(
        webhookUrl,
        function() end,
        'POST',
        json.encode({
            username = Config.WebhookName or 'RS Jobs Creator',
            embeds = {
                {
                    title = 'RS Jobs Creator - fout',
                    description = description,
                    color = 15158332,
                    footer = {
                        text = os.date('!%Y-%m-%d %H:%M:%S UTC')
                    }
                }
            }
        }),
        {
            ['Content-Type'] = 'application/json'
        }
    )
end

-- Alle callbacks die main.lua hierna registreert krijgen dezelfde guard.
-- Hierdoor kan een oxmysql/Lua-error de NUI niet meer zonder antwoord laten.
if type(ESX.RegisterServerCallback) == 'function'
    and not _G.__RSJC_CALLBACK_GUARD then

    _G.__RSJC_CALLBACK_GUARD = true

    local registerServerCallback = ESX.RegisterServerCallback

    ESX.RegisterServerCallback = function(name, handler)
        return registerServerCallback(
            name,
            function(source, cb, ...)
                local replied = false

                local function safeCb(...)
                    if replied then
                        return
                    end

                    replied = true
                    cb(...)
                end

                local args = table.pack(...)

                local ok, err = xpcall(
                    function()
                        handler(
                            source,
                            safeCb,
                            table.unpack(args, 1, args.n)
                        )
                    end,
                    debug.traceback
                )

                if not ok then
                    reportCallbackFailure(
                        name,
                        source,
                        err
                    )

                    if not replied then
                        safeCb({
                            success = false,
                            message = 'Er ging iets mis op de server. Controleer de serverconsole.'
                        })
                    end

                    return
                end

                -- Sommige ESX-callbacks antwoorden bewust later via een async
                -- callback. Geef die ruimte, maar laat ze nooit onbeperkt hangen.
                if not replied then
                    SetTimeout(12000, function()
                        if replied then
                            return
                        end

                        reportCallbackFailure(
                            name,
                            source,
                            'Callback gaf binnen 12 seconden geen antwoord.'
                        )

                        safeCb({
                            success = false,
                            message = 'De serveractie gaf niet op tijd antwoord.'
                        })
                    end)
                end
            end
        )
    end
end
