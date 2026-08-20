local ESX = exports['es_extended']:getSharedObject()
local RESOURCE = GetCurrentResourceName()

local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function reply(cb, success, message, extra)
    local payload = type(extra) == 'table' and extra or {}
    payload.success = success == true
    payload.message = message or ''
    cb(payload)
end

local function isAdmin(source)
    if source == 0 then
        return true
    end

    if Config.AdminAce
        and Config.AdminAce ~= ''
        and IsPlayerAceAllowed(source, Config.AdminAce) then

        return true
    end

    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then
        return false
    end

    local group = 'user'

    if xPlayer.getGroup then
        group = xPlayer.getGroup() or 'user'
    end

    return Config.AdminGroups
        and Config.AdminGroups[group] == true
end

local function getIdentifier(source)
    if source == 0 then
        return 'console'
    end

    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer and xPlayer.identifier then
        return xPlayer.identifier
    end

    return GetPlayerIdentifier(source, 0)
        or ('source:%s'):format(source)
end

local function getPlayerNameSafe(source)
    if source == 0 then
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

local function sendWebhook(action, source, jobName, details, success)
    local url = Config.WebhookUrl or Config.Webhook or ''

    if url == '' then
        return
    end

    local extra = ''

    if details and next(details) then
        local ok, encoded = pcall(json.encode, details)

        if ok and encoded then
            extra = ('\n**Details:** `%s`'):format(encoded:sub(1, 900))
        end
    end

    local description = (
        '**Actie:** %s\n' ..
        '**Job:** %s\n' ..
        '**Staff:** %s\n' ..
        '**Identifier:** `%s`%s'
    ):format(
        tostring(action),
        jobName or 'N.v.t.',
        getPlayerNameSafe(source),
        getIdentifier(source),
        extra
    )

    PerformHttpRequest(
        url,
        function(status)
            if Config.Debug and (status < 200 or status >= 300) then
                print(('[%s] webhook status: %s'):format(RESOURCE, status))
            end
        end,
        'POST',
        json.encode({
            username = Config.WebhookName or 'RS Jobs Creator',
            embeds = {
                {
                    title = success == false
                        and 'RS Jobs Creator - mislukt'
                        or 'RS Jobs Creator',
                    description = description,
                    color = success == false and 15158332 or 3447003,
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

local function logAction(source, action, jobName, details)
    local payload = type(details) == 'table' and details or {}
    payload.staff = getPlayerNameSafe(source)
    payload.source = source

    pcall(function()
        MySQL.insert.await([[
            INSERT INTO `rs_jobscreator_logs`
                (`identifier`, `job_name`, `action`, `details`)
            VALUES (?, ?, ?, ?)
        ]], {
            getIdentifier(source),
            jobName,
            action,
            json.encode(payload)
        })
    end)

    sendWebhook(action, source, jobName, details, true)
end

local function refreshESXJobs()
    if type(ESX.RefreshJobs) == 'function' then
        local ok = pcall(function()
            ESX.RefreshJobs()
        end)

        if ok then
            return true
        end
    end

    return pcall(function()
        ExecuteCommand('refreshjobs')
    end)
end

local function validJob(name)
    if type(name) ~= 'string' or name == '' then
        return false
    end

    return MySQL.single.await([[
        SELECT `name`
        FROM `jobs`
        WHERE `name` = ?
        LIMIT 1
    ]], { name }) ~= nil
end

local function validateJobName(name)
    return type(name) == 'string'
        and #name >= 2
        and #name <= 50
        and name:match('^[a-z][a-z0-9_]+$') ~= nil
end

local function getJobsColumns()
    local result = {}

    for _, row in ipairs(
        MySQL.query.await('SHOW COLUMNS FROM `jobs`') or {}
    ) do
        if row.Field then
            result[tostring(row.Field)] = true
        end
    end

    return result
end

local function buildJobUpdate(columns, label, whitelisted, enabled, whereName)
    local sql = 'UPDATE `jobs` SET `label` = ?'
    local params = { label }

    if columns.whitelisted then
        sql = sql .. ', `whitelisted` = ?'
        params[#params + 1] = whitelisted and 1 or 0
    end

    if columns.enabled then
        sql = sql .. ', `enabled` = ?'
        params[#params + 1] = enabled == false and 0 or 1
    end

    sql = sql .. ' WHERE `name` = ?'
    params[#params + 1] = whereName

    return sql, params
end

local function buildJobInsert(columns, name, label, whitelisted, enabled)
    local names = { '`name`', '`label`' }
    local placeholders = { '?', '?' }
    local params = { name, label }

    if columns.whitelisted then
        names[#names + 1] = '`whitelisted`'
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = whitelisted and 1 or 0
    end

    if columns.enabled then
        names[#names + 1] = '`enabled`'
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = enabled == false and 0 or 1
    end

    return (
        'INSERT INTO `jobs` (%s) VALUES (%s)'
    ):format(
        table.concat(names, ', '),
        table.concat(placeholders, ', ')
    ), params
end

local function getOnlinePlayersForJob(jobName, exactGrade)
    local players = {}

    if type(ESX.GetPlayers) ~= 'function' then
        return players
    end

    for _, playerId in ipairs(ESX.GetPlayers() or {}) do
        local xPlayer = ESX.GetPlayerFromId(playerId)

        if xPlayer
            and xPlayer.job
            and xPlayer.job.name == jobName
            and (
                exactGrade == nil
                or tonumber(xPlayer.job.grade) == tonumber(exactGrade)
            ) then

            players[#players + 1] = {
                player = xPlayer,
                grade = tonumber(xPlayer.job.grade) or 0
            }
        end
    end

    return players
end

local function syncPlayers(players, jobName, gradeOverride)
    for _, entry in ipairs(players) do
        local xPlayer = entry.player
        local grade = gradeOverride

        if grade == nil then
            grade = entry.grade or 0
        end

        if xPlayer and xPlayer.setJob then
            local ok, err = pcall(function()
                xPlayer.setJob(jobName, grade)
            end)

            if not ok then
                print((
                    '[%s] kon online player job niet synchroniseren: %s'
                ):format(RESOURCE, tostring(err)))
            end
        end
    end
end

local function transaction(queries)
    local ok = MySQL.transaction.await(queries)

    if ok ~= true then
        error('Database-transactie is teruggedraaid.')
    end

    return true
end

-- =========================================================
-- SAVE JOB - transactionele rename/create + live ESX sync
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:saveJob',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(cb, false, 'Geen toestemming.')
        end

        data = type(data) == 'table' and data or {}

        local name = trim(tostring(data.name or '')):lower()
        local label = trim(tostring(data.label or ''))
        local original = nil

        if data.original and data.original ~= '' then
            original = trim(tostring(data.original)):lower()
        end

        if not validateJobName(name) then
            return reply(
                cb,
                false,
                'Ongeldige jobnaam. Gebruik alleen a-z, cijfers en _.'
            )
        end

        if #label < 1 or #label > 80 then
            return reply(cb, false, 'Ongeldige weergavenaam.')
        end

        local columns = getJobsColumns()
        local exists = MySQL.single.await([[
            SELECT `name`
            FROM `jobs`
            WHERE `name` = ?
            LIMIT 1
        ]], { name })

        -- Rename
        if original and original ~= name then
            if not validJob(original) then
                return reply(cb, false, 'Oorspronkelijke job bestaat niet.')
            end

            if exists then
                return reply(cb, false, 'De nieuwe jobnaam bestaat al.')
            end

            local onlinePlayers = getOnlinePlayersForJob(original)
            local updateSql, updateParams = buildJobUpdate(
                columns,
                label,
                data.whitelisted,
                data.enabled,
                original
            )

            -- Wijzig ook de primary jobnaam zelf in dezelfde transactie.
            updateSql = updateSql:gsub(
                'SET `label` = %?',
                'SET `name` = ?, `label` = ?',
                1
            )
            table.insert(updateParams, 1, name)

            transaction({
                {
                    query = 'UPDATE `users` SET `job` = ? WHERE `job` = ?',
                    values = { name, original }
                },
                {
                    query = 'UPDATE `job_grades` SET `job_name` = ? WHERE `job_name` = ?',
                    values = { name, original }
                },
                {
                    query = 'UPDATE `rs_jobscreator_points` SET `job_name` = ? WHERE `job_name` = ?',
                    values = { name, original }
                },
                {
                    query = updateSql,
                    values = updateParams
                }
            })

            refreshESXJobs()
            syncPlayers(onlinePlayers, name)

            logAction(source, 'rename_job', name, {
                original = original,
                label = label
            })

            TriggerClientEvent(
                'rs_jobscreator:client:refreshPoints',
                -1
            )

            return reply(cb, true, 'Job hernoemd en opgeslagen.')
        end

        -- Update
        if exists then
            local onlinePlayers = getOnlinePlayersForJob(name)
            local updateSql, updateParams = buildJobUpdate(
                columns,
                label,
                data.whitelisted,
                data.enabled,
                name
            )

            MySQL.update.await(updateSql, updateParams)

            refreshESXJobs()
            syncPlayers(onlinePlayers, name)

            logAction(source, 'update_job', name, {
                label = label
            })

            return reply(cb, true, 'Job opgeslagen.')
        end

        -- Create
        local insertSql, insertParams = buildJobInsert(
            columns,
            name,
            label,
            data.whitelisted,
            data.enabled
        )

        transaction({
            {
                query = insertSql,
                values = insertParams
            },
            {
                query = [[
                    INSERT INTO `job_grades`
                        (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`)
                    SELECT ?, 0, 'employee', 'Employee', 0, '{}', '{}'
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM `job_grades`
                        WHERE `job_name` = ? AND `grade` = 0
                    )
                ]],
                values = { name, name }
            }
        })

        refreshESXJobs()

        logAction(source, 'create_job', name, {
            label = label
        })

        TriggerClientEvent(
            'rs_jobscreator:client:refreshPoints',
            -1
        )

        reply(cb, true, 'Job aangemaakt.')
    end
)

-- =========================================================
-- DELETE JOB - atomair + online spelers direct werkloos
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:deleteJob',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(cb, false, 'Geen toestemming.')
        end

        local name = trim(
            tostring((type(data) == 'table' and data.name) or '')
        ):lower()

        if name == '' or name == 'unemployed' then
            return reply(
                cb,
                false,
                'Deze job mag niet verwijderd worden.'
            )
        end

        if not validJob(name) then
            return reply(cb, false, 'Job bestaat niet.')
        end

        local onlinePlayers = getOnlinePlayersForJob(name)

        transaction({
            {
                query = [[
                    UPDATE `users`
                    SET `job` = 'unemployed', `job_grade` = 0
                    WHERE `job` = ?
                ]],
                values = { name }
            },
            {
                query = 'DELETE FROM `job_grades` WHERE `job_name` = ?',
                values = { name }
            },
            {
                query = 'DELETE FROM `rs_jobscreator_points` WHERE `job_name` = ?',
                values = { name }
            },
            {
                query = 'DELETE FROM `jobs` WHERE `name` = ?',
                values = { name }
            }
        })

        refreshESXJobs()
        syncPlayers(onlinePlayers, 'unemployed', 0)

        logAction(source, 'delete_job', name, {
            onlinePlayers = #onlinePlayers
        })

        TriggerClientEvent(
            'rs_jobscreator:client:refreshPoints',
            -1
        )

        reply(cb, true, 'Job verwijderd.')
    end
)

-- =========================================================
-- DELETE GRADE - atomair + online spelers naar grade 0
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:deleteGrade',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(cb, false, 'Geen toestemming.')
        end

        data = type(data) == 'table' and data or {}

        local job = trim(tostring(data.jobName or '')):lower()
        local grade = tonumber(data.grade)

        if not validJob(job) then
            return reply(cb, false, 'Job bestaat niet.')
        end

        if grade == nil then
            return reply(cb, false, 'Ongeldig rangnummer.')
        end

        grade = math.floor(grade)

        if grade == 0 then
            return reply(cb, false, 'Rang 0 kan niet verwijderd worden.')
        end

        local exists = MySQL.single.await([[
            SELECT `id`
            FROM `job_grades`
            WHERE `job_name` = ? AND `grade` = ?
            LIMIT 1
        ]], { job, grade })

        if not exists then
            return reply(cb, false, 'Rang bestaat niet.')
        end

        local onlinePlayers = getOnlinePlayersForJob(job, grade)

        transaction({
            {
                query = [[
                    UPDATE `users`
                    SET `job_grade` = 0
                    WHERE `job` = ? AND `job_grade` = ?
                ]],
                values = { job, grade }
            },
            {
                query = [[
                    DELETE FROM `job_grades`
                    WHERE `job_name` = ? AND `grade` = ?
                ]],
                values = { job, grade }
            }
        })

        refreshESXJobs()
        syncPlayers(onlinePlayers, job, 0)

        logAction(source, 'delete_grade', job, {
            grade = grade,
            onlinePlayers = #onlinePlayers
        })

        reply(cb, true, 'Rang verwijderd.')
    end
)
