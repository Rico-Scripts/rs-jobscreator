local ESX = exports['es_extended']:getSharedObject()

local RESOURCE = GetCurrentResourceName()

local jobsColumns = {}
local resourceScanCache = {}


-- =========================================================
-- LOGGING
-- =========================================================

local function debugLog(...)
    if not Config.Debug then
        return
    end

    print(('[%s] [DEBUG]'):format(RESOURCE), ...)
end


local function log(level, message)
    print(('[%s] [%s] %s'):format(
        RESOURCE,
        tostring(level),
        tostring(message)
    ))
end


local function webhook(title, description, color)
    local url =
        Config.Webhook
        or Config.WebhookUrl
        or ''

    if url == '' then
        return
    end

    PerformHttpRequest(
        url,
        function(status)
            if status < 200 or status >= 300 then
                log(
                    'WARN',
                    ('Webhook HTTP status: %s'):format(
                        tostring(status)
                    )
                )
            end
        end,
        'POST',
        json.encode({
            username =
                Config.WebhookName
                or 'RS Jobs Creator',

            embeds = {
                {
                    title = title,
                    description = description,
                    color = color or 3447003,

                    footer = {
                        text = os.date(
                            '!%Y-%m-%d %H:%M:%S UTC'
                        )
                    }
                }
            }
        }),
        {
            ['Content-Type'] = 'application/json'
        }
    )
end


-- =========================================================
-- GENERAL HELPERS
-- =========================================================

local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value
        :gsub('^%s+', '')
        :gsub('%s+$', '')
end


local function decode(value)
    if type(value) == 'table' then
        return value
    end

    if type(value) ~= 'string'
        or value == '' then

        return {}
    end

    local ok, result =
        pcall(
            json.decode,
            value
        )

    if not ok
        or type(result) ~= 'table' then

        return {}
    end

    return result
end


local function encode(value)
    local ok, result =
        pcall(
            json.encode,
            value or {}
        )

    if not ok then
        return '{}'
    end

    return result
end


local function reply(
    cb,
    success,
    message,
    extra
)
    local data =
        type(extra) == 'table'
        and extra
        or {}

    data.success =
        success == true

    data.message =
        message or ''

    cb(data)
end


-- =========================================================
-- ESX / PLAYER
-- =========================================================

local function getPlayer(source)
    if not source
        or source <= 0 then

        return nil
    end

    return ESX.GetPlayerFromId(
        source
    )
end


local function getIdentifier(source)
    if source == 0 then
        return 'console'
    end

    local xPlayer =
        getPlayer(source)

    if xPlayer
        and xPlayer.identifier then

        return xPlayer.identifier
    end

    return GetPlayerIdentifier(
        source,
        0
    )
        or ('source:%s'):format(
            source
        )
end


local function getPlayerNameSafe(source)
    if source == 0 then
        return 'Console'
    end

    local xPlayer =
        getPlayer(source)

    if xPlayer
        and xPlayer.getName then

        local name =
            xPlayer.getName()

        if name
            and name ~= '' then

            return name
        end
    end

    return GetPlayerName(source)
        or ('Player %s'):format(
            source
        )
end


local function isAdmin(source)
    if source == 0 then
        return true
    end

    if Config.AdminAce
        and Config.AdminAce ~= ''
        and IsPlayerAceAllowed(
            source,
            Config.AdminAce
        ) then

        return true
    end

    local xPlayer =
        getPlayer(source)

    if not xPlayer then
        return false
    end

    local group = 'user'

    if xPlayer.getGroup then
        group =
            xPlayer.getGroup()
            or 'user'
    end

    return Config.AdminGroups
        and Config.AdminGroups[group]
        == true
end


-- =========================================================
-- ESX JOB CACHE
-- =========================================================

local function refreshESXJobs()
    if type(ESX.RefreshJobs)
        == 'function' then

        local ok, err =
            pcall(function()
                ESX.RefreshJobs()
            end)

        if ok then
            debugLog(
                'ESX jobs vernieuwd via ESX.RefreshJobs().'
            )

            return true
        end

        log(
            'WARN',
            ('ESX.RefreshJobs() mislukt: %s'):format(
                tostring(err)
            )
        )
    end

    local ok, err =
        pcall(function()
            ExecuteCommand(
                'refreshjobs'
            )
        end)

    if not ok then
        log(
            'ERROR',
            ('refreshjobs mislukt: %s'):format(
                tostring(err)
            )
        )

        return false
    end

    debugLog(
        'ESX jobs vernieuwd via refreshjobs.'
    )

    return true
end


-- =========================================================
-- DATABASE SCHEMA
-- =========================================================

local function refreshJobsColumns()
    jobsColumns = {}

    local rows =
        MySQL.query.await(
            'SHOW COLUMNS FROM `jobs`'
        )
        or {}

    for _, row in ipairs(rows) do
        if row.Field then
            jobsColumns[
                tostring(row.Field)
            ] = true
        end
    end
end


local function validJob(name)
    if type(name) ~= 'string'
        or name == '' then

        return false
    end

    return MySQL.single.await(
        [[
            SELECT `name`
            FROM `jobs`
            WHERE `name` = ?
            LIMIT 1
        ]],
        {
            name
        }
    ) ~= nil
end


local function validateJobName(name)
    if type(name) ~= 'string' then
        return false
    end

    if #name < 2
        or #name > 50 then

        return false
    end

    return name:match(
        '^[a-z][a-z0-9_]+$'
    ) ~= nil
end


local function validateGradeName(name)
    if type(name) ~= 'string'
        or #name < 1
        or #name > 50 then

        return false
    end

    return name:match(
        '^[a-z][a-z0-9_]+$'
    ) ~= nil
end


-- =========================================================
-- TABLE SETUP
-- =========================================================

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rs_jobscreator_points`
        (
            `id`
                INT NOT NULL
                AUTO_INCREMENT,

            `job_name`
                VARCHAR(50)
                NULL,

            `type`
                VARCHAR(30)
                NOT NULL,

            `label`
                VARCHAR(100)
                NOT NULL,

            `x`
                DOUBLE NOT NULL
                DEFAULT 0,

            `y`
                DOUBLE NOT NULL
                DEFAULT 0,

            `z`
                DOUBLE NOT NULL
                DEFAULT 0,

            `w`
                DOUBLE NOT NULL
                DEFAULT 0,

            `min_grade`
                INT NOT NULL
                DEFAULT 0,

            `radius`
                FLOAT NOT NULL
                DEFAULT 1.5,

            `public`
                TINYINT(1)
                NOT NULL
                DEFAULT 0,

            `enabled`
                TINYINT(1)
                NOT NULL
                DEFAULT 1,

            `settings`
                LONGTEXT
                NULL,

            `created_at`
                TIMESTAMP
                NOT NULL
                DEFAULT CURRENT_TIMESTAMP,

            `updated_at`
                TIMESTAMP
                NOT NULL
                DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),

            KEY `idx_job`
                (`job_name`),

            KEY `idx_enabled`
                (`enabled`)
        )
        ENGINE=InnoDB
        DEFAULT CHARSET=utf8mb4
        COLLATE=utf8mb4_unicode_ci
    ]])


    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rs_jobscreator_logs`
        (
            `id`
                INT NOT NULL
                AUTO_INCREMENT,

            `identifier`
                VARCHAR(100)
                NOT NULL,

            `job_name`
                VARCHAR(50)
                NULL,

            `action`
                VARCHAR(100)
                NOT NULL,

            `details`
                LONGTEXT
                NULL,

            `created_at`
                TIMESTAMP
                NOT NULL
                DEFAULT CURRENT_TIMESTAMP,

            PRIMARY KEY (`id`),

            KEY `idx_created`
                (`created_at`)
        )
        ENGINE=InnoDB
        DEFAULT CHARSET=utf8mb4
        COLLATE=utf8mb4_unicode_ci
    ]])
end


-- =========================================================
-- ACTION LOGGING
-- =========================================================

local function logAction(
    source,
    action,
    jobName,
    details
)
    local identifier =
        getIdentifier(source)

    local playerName =
        getPlayerNameSafe(source)

    local payload =
        type(details) == 'table'
        and details
        or {}

    payload.staff =
        playerName

    payload.source =
        source

    MySQL.insert(
        [[
            INSERT INTO `rs_jobscreator_logs`
            (
                `identifier`,
                `job_name`,
                `action`,
                `details`
            )
            VALUES (?, ?, ?, ?)
        ]],
        {
            identifier,
            jobName,
            action,
            encode(payload)
        }
    )

    webhook(
        'RS Jobs Creator',
        (
            '**Actie:** %s\n' ..
            '**Job:** %s\n' ..
            '**Staff:** %s\n' ..
            '**Identifier:** `%s`'
        ):format(
            tostring(action),
            jobName or 'N.v.t.',
            playerName,
            identifier
        ),
        3447003
    )
end


-- =========================================================
-- SETTINGS
-- =========================================================

local function normalizeSettings(settings)
    if type(settings) ~= 'table' then
        settings = {}
    end

    if settings.requireDuty == nil then
        settings.requireDuty = true
    end

    return settings
end


-- =========================================================
-- STATE
-- =========================================================

local function getState()
    refreshJobsColumns()

    local extra = ''

    if jobsColumns.whitelisted then
        extra =
            extra ..
            ', j.whitelisted'
    else
        extra =
            extra ..
            ', 0 AS whitelisted'
    end

    if jobsColumns.enabled then
        extra =
            extra ..
            ', j.enabled'
    else
        extra =
            extra ..
            ', 1 AS enabled'
    end


    local jobs =
        MySQL.query.await(([[

            SELECT
                j.name,
                j.label
                %s,

                (
                    SELECT COUNT(*)
                    FROM job_grades g
                    WHERE g.job_name = j.name
                ) AS grades,

                (
                    SELECT COUNT(*)
                    FROM users u
                    WHERE u.job = j.name
                ) AS employees,

                0 AS balance

            FROM jobs j

            ORDER BY j.name ASC

        ]]):format(extra))
        or {}


    local grades =
        MySQL.query.await([[
            SELECT
                id,
                job_name,
                grade,
                name,
                label,
                salary,
                skin_male,
                skin_female

            FROM job_grades

            ORDER BY
                job_name ASC,
                grade ASC
        ]])
        or {}


    local points =
        MySQL.query.await([[
            SELECT *
            FROM rs_jobscreator_points

            ORDER BY
                job_name ASC,
                id ASC
        ]])
        or {}


    for _, point in ipairs(points) do
        point.settings =
            decode(
                point.settings
            )
    end


    local maxLogs =
        math.max(
            1,
            tonumber(
                Config.MaxLogs
            ) or 100
        )


    local logs =
        MySQL.query.await(([[

            SELECT
                created_at,
                job_name,
                action,
                identifier,
                details

            FROM rs_jobscreator_logs

            ORDER BY id DESC

            LIMIT %d

        ]]):format(maxLogs))
        or {}


    for _, entry in ipairs(logs) do
        entry.details =
            decode(
                entry.details
            )
    end


    return {
        jobs = jobs,
        grades = grades,
        points = points,
        logs = logs,

        pointTypes =
            Config.PointTypes
            or {},

        examples =
            Config.Examples
            or {}
    }
end


-- =========================================================
-- POSITION
-- =========================================================

local function getServerCoords(source)
    local ped =
        GetPlayerPed(source)

    if not ped
        or ped <= 0 then

        return nil
    end

    local coords =
        GetEntityCoords(ped)

    return
        coords.x,
        coords.y,
        coords.z,
        GetEntityHeading(ped)
end


-- =========================================================
-- POINT PERMISSIONS
-- =========================================================

local function playerAllowed(
    source,
    point
)
    if tonumber(point.public) == 1 then
        return true
    end

    if not point.job_name
        or point.job_name == '' then

        return true
    end

    local xPlayer =
        getPlayer(source)

    if not xPlayer
        or not xPlayer.job then

        return false
    end

    if xPlayer.job.name
        ~= point.job_name then

        return false
    end

    return (
        tonumber(
            xPlayer.job.grade
        ) or 0
    ) >= (
        tonumber(
            point.min_grade
        ) or 0
    )
end


local function requireDuty(source, point)
    local settings = decode(point.settings)

    if settings.requireDuty == false then
        return true
    end

    local xPlayer = getPlayer(source)

    if not xPlayer or not xPlayer.job then
        return false
    end

    if GetResourceState('rs-duty') == 'started' then
        local ok, onDuty = pcall(function()
            return exports['rs-duty']:IsOnDuty(source)
        end)

        if ok then
            return onDuty == true
        end
    end

    if xPlayer.job.onduty ~= nil then
        return xPlayer.job.onduty == true
    end

    return true
end

local function distanceOk(
    source,
    point
)
    local x, y, z =
        getServerCoords(source)

    if not x then
        return false
    end

    local px =
        tonumber(point.x)
        or 0.0

    local py =
        tonumber(point.y)
        or 0.0

    local pz =
        tonumber(point.z)
        or 0.0

    local dx = x - px
    local dy = y - py
    local dz = z - pz

    local distance =
        math.sqrt(
            dx * dx
            + dy * dy
            + dz * dz
        )

    local buffer =
        tonumber(
            Config.ServerDistanceBuffer
        )
        or 3.0

    local allowedDistance =
        math.max(
            8.0,
            (
                tonumber(
                    point.radius
                )
                or 1.5
            ) + buffer
        )

    return distance <= allowedDistance
end


local function getPoint(
    source,
    id,
    allowedTypes
)
    id =
        tonumber(id)

    if not id then
        return nil,
            'Ongeldig interactiepunt.'
    end

    local point =
        MySQL.single.await(
            [[
                SELECT *
                FROM rs_jobscreator_points
                WHERE id = ?
                  AND enabled = 1
                LIMIT 1
            ]],
            {
                id
            }
        )

    if not point then
        return nil,
            'Punt bestaat niet meer.'
    end

    local allowed = false

    for _, pointType in ipairs(
        allowedTypes or {}
    ) do
        if point.type
            == pointType then

            allowed = true
            break
        end
    end

    if not allowed then
        return nil,
            'Ongeldig punt-type.'
    end

    if not distanceOk(
        source,
        point
    ) then
        return nil,
            'Je staat te ver van dit punt.'
    end

    if not playerAllowed(
        source,
        point
    ) then
        return nil,
            'Je hebt geen toegang tot dit punt.'
    end

    if not requireDuty(
        source,
        point
    ) then
        return nil,
            'Je moet in dienst zijn.'
    end

    point.settings =
        decode(
            point.settings
        )

    return point
end


local function notify(
    source,
    message,
    success
)
    TriggerClientEvent(
        'rs_jobscreator:client:notify',
        source,
        message,
        success ~= false
    )
end


-- =========================================================
-- INITIALIZATION
-- =========================================================

CreateThread(function()
    Wait(1000)

    local ok, err =
        pcall(
            createTables
        )

    if not ok then
        log(
            'ERROR',
            ('Database setup mislukt: %s'):format(
                tostring(err)
            )
        )

        return
    end

    refreshJobsColumns()

    log(
        'OK',
        'RS Jobs Creator server gestart.'
    )
end)


-- =========================================================
-- GET STATE
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:getState',
    function(source, cb)
        if not isAdmin(source) then
            return reply(
                cb,
                false,
                'Geen toestemming.'
            )
        end

        local ok, result =
            pcall(
                getState
            )

        if not ok then
            log(
                'ERROR',
                tostring(result)
            )

            return reply(
                cb,
                false,
                'Kon Jobs Creator gegevens niet laden.'
            )
        end

        reply(
            cb,
            true,
            'Vernieuwd.',
            result
        )
    end
)


-- =========================================================
-- REQUEST STATE
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:requestState',
    function()
        local src = source

        if not isAdmin(src) then
            return notify(
                src,
                'Geen toegang tot Jobs Creator.',
                false
            )
        end

        local ok, state =
            pcall(
                getState
            )

        if not ok then
            log(
                'ERROR',
                tostring(state)
            )

            return notify(
                src,
                'Jobs Creator kon niet worden geladen.',
                false
            )
        end

        TriggerClientEvent(
            'rs_jobscreator:client:setState',
            src,
            state
        )
    end
)


-- =========================================================
-- SAVE JOB
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:saveJob',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(
                cb,
                false,
                'Geen toestemming.'
            )
        end

        data =
            type(data) == 'table'
            and data
            or {}

        refreshJobsColumns()

        local name =
            trim(
                tostring(
                    data.name
                    or ''
                )
            ):lower()

        local label =
            trim(
                tostring(
                    data.label
                    or ''
                )
            )

        local original = nil

        if data.original
            and data.original ~= '' then

            original =
                trim(
                    tostring(
                        data.original
                    )
                ):lower()
        end


        if not validateJobName(name) then
            return reply(
                cb,
                false,
                'Ongeldige jobnaam. Gebruik alleen a-z, cijfers en _.'
            )
        end


        if #label < 1
            or #label > 80 then

            return reply(
                cb,
                false,
                'Ongeldige weergavenaam.'
            )
        end


        local exists =
            MySQL.single.await(
                [[
                    SELECT name
                    FROM jobs
                    WHERE name = ?
                    LIMIT 1
                ]],
                {
                    name
                }
            )


        -- =================================================
        -- RENAME
        -- =================================================

        if original
            and original ~= name then

            if not validJob(original) then
                return reply(
                    cb,
                    false,
                    'Oorspronkelijke job bestaat niet.'
                )
            end

            if exists then
                return reply(
                    cb,
                    false,
                    'De nieuwe jobnaam bestaat al.'
                )
            end


            MySQL.update.await(
                [[
                    UPDATE users
                    SET job = ?
                    WHERE job = ?
                ]],
                {
                    name,
                    original
                }
            )


            MySQL.update.await(
                [[
                    UPDATE job_grades
                    SET job_name = ?
                    WHERE job_name = ?
                ]],
                {
                    name,
                    original
                }
            )


            MySQL.update.await(
                [[
                    UPDATE rs_jobscreator_points
                    SET job_name = ?
                    WHERE job_name = ?
                ]],
                {
                    name,
                    original
                }
            )


            local sql =
                'UPDATE jobs SET name = ?, label = ?'

            local params = {
                name,
                label
            }


            if jobsColumns.whitelisted then
                sql =
                    sql ..
                    ', whitelisted = ?'

                params[
                    #params + 1
                ] =
                    data.whitelisted
                    and 1
                    or 0
            end


            if jobsColumns.enabled then
                sql =
                    sql ..
                    ', enabled = ?'

                params[
                    #params + 1
                ] =
                    data.enabled == false
                    and 0
                    or 1
            end


            sql =
                sql ..
                ' WHERE name = ?'

            params[
                #params + 1
            ] = original


            MySQL.update.await(
                sql,
                params
            )


            refreshESXJobs()


            logAction(
                source,
                'rename_job',
                name,
                {
                    original =
                        original
                }
            )


            TriggerClientEvent(
                'rs_jobscreator:client:refreshPoints',
                -1
            )


            return reply(
                cb,
                true,
                'Job hernoemd en opgeslagen.'
            )
        end


        -- =================================================
        -- UPDATE
        -- =================================================

        if exists then
            local sql =
                'UPDATE jobs SET label = ?'

            local params = {
                label
            }


            if jobsColumns.whitelisted then
                sql =
                    sql ..
                    ', whitelisted = ?'

                params[
                    #params + 1
                ] =
                    data.whitelisted
                    and 1
                    or 0
            end


            if jobsColumns.enabled then
                sql =
                    sql ..
                    ', enabled = ?'

                params[
                    #params + 1
                ] =
                    data.enabled == false
                    and 0
                    or 1
            end


            sql =
                sql ..
                ' WHERE name = ?'

            params[
                #params + 1
            ] = name


            MySQL.update.await(
                sql,
                params
            )


            refreshESXJobs()


            logAction(
                source,
                'update_job',
                name,
                {
                    label = label
                }
            )


            return reply(
                cb,
                true,
                'Job opgeslagen.'
            )
        end


        -- =================================================
        -- CREATE
        -- =================================================

        local columns = {
            '`name`',
            '`label`'
        }

        local placeholders = {
            '?',
            '?'
        }

        local params = {
            name,
            label
        }


        if jobsColumns.whitelisted then
            columns[
                #columns + 1
            ] = '`whitelisted`'

            placeholders[
                #placeholders + 1
            ] = '?'

            params[
                #params + 1
            ] =
                data.whitelisted
                and 1
                or 0
        end


        if jobsColumns.enabled then
            columns[
                #columns + 1
            ] = '`enabled`'

            placeholders[
                #placeholders + 1
            ] = '?'

            params[
                #params + 1
            ] =
                data.enabled == false
                and 0
                or 1
        end


        MySQL.insert.await(
            (
                'INSERT INTO jobs (%s) VALUES (%s)'
            ):format(
                table.concat(
                    columns,
                    ', '
                ),
                table.concat(
                    placeholders,
                    ', '
                )
            ),
            params
        )


        local gradeExists =
            MySQL.single.await(
                [[
                    SELECT id
                    FROM job_grades
                    WHERE job_name = ?
                      AND grade = 0
                    LIMIT 1
                ]],
                {
                    name
                }
            )


        if not gradeExists then
            MySQL.insert.await(
                [[
                    INSERT INTO job_grades
                    (
                        job_name,
                        grade,
                        name,
                        label,
                        salary,
                        skin_male,
                        skin_female
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ]],
                {
                    name,
                    0,
                    'employee',
                    'Employee',
                    0,
                    '{}',
                    '{}'
                }
            )
        end


        refreshESXJobs()


        logAction(
            source,
            'create_job',
            name,
            {
                label = label
            }
        )


        TriggerClientEvent(
            'rs_jobscreator:client:refreshPoints',
            -1
        )


        reply(
            cb,
            true,
            'Job aangemaakt.'
        )
    end
)


-- =========================================================
-- DELETE JOB
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:deleteJob',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(
                cb,
                false,
                'Geen toestemming.'
            )
        end

        local name =
            trim(
                tostring(
                    (data or {}).name
                    or ''
                )
            ):lower()


        if name == ''
            or name == 'unemployed' then

            return reply(
                cb,
                false,
                'Deze job mag niet verwijderd worden.'
            )
        end


        if not validJob(name) then
            return reply(
                cb,
                false,
                'Job bestaat niet.'
            )
        end


        MySQL.update.await(
            [[
                UPDATE users
                SET
                    job = 'unemployed',
                    job_grade = 0
                WHERE job = ?
            ]],
            {
                name
            }
        )


        MySQL.update.await(
            [[
                DELETE FROM job_grades
                WHERE job_name = ?
            ]],
            {
                name
            }
        )


        MySQL.update.await(
            [[
                DELETE FROM rs_jobscreator_points
                WHERE job_name = ?
            ]],
            {
                name
            }
        )


        MySQL.update.await(
            [[
                DELETE FROM jobs
                WHERE name = ?
            ]],
            {
                name
            }
        )


        refreshESXJobs()


        logAction(
            source,
            'delete_job',
            name
        )


        TriggerClientEvent(
            'rs_jobscreator:client:refreshPoints',
            -1
        )


        reply(
            cb,
            true,
            'Job verwijderd.'
        )
    end
)


-- =========================================================
-- SAVE GRADE
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:saveGrade',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(
                cb,
                false,
                'Geen toestemming.'
            )
        end

        data =
            type(data) == 'table'
            and data
            or {}


        local job =
            trim(
                tostring(
                    data.jobName
                    or ''
                )
            ):lower()


        local grade =
            tonumber(
                data.grade
            )


        local name =
            trim(
                tostring(
                    data.name
                    or ''
                )
            ):lower()


        local label =
            trim(
                tostring(
                    data.label
                    or ''
                )
            )


        local salary =
            math.floor(
                tonumber(
                    data.salary
                )
                or 0
            )


        if data.boss == true then
            name = 'boss'
        end


        if not validJob(job) then
            return reply(
                cb,
                false,
                'Job bestaat niet.'
            )
        end


        if not grade
            or grade < 0
            or grade > 99
            or grade % 1 ~= 0 then

            return reply(
                cb,
                false,
                'Ongeldig rangnummer.'
            )
        end


        if not validateGradeName(name) then
            return reply(
                cb,
                false,
                'Ongeldige interne rangnaam.'
            )
        end


        if #label < 1
            or #label > 80 then

            return reply(
                cb,
                false,
                'Ongeldige rangnaam.'
            )
        end


        if salary < 0 then
            return reply(
                cb,
                false,
                'Salaris mag niet negatief zijn.'
            )
        end


        local row =
            MySQL.single.await(
                [[
                    SELECT id
                    FROM job_grades
                    WHERE job_name = ?
                      AND grade = ?
                    LIMIT 1
                ]],
                {
                    job,
                    grade
                }
            )


        if row then
            MySQL.update.await(
                [[
                    UPDATE job_grades
                    SET
                        name = ?,
                        label = ?,
                        salary = ?
                    WHERE id = ?
                ]],
                {
                    name,
                    label,
                    salary,
                    row.id
                }
            )

            logAction(
                source,
                'update_grade',
                job,
                {
                    grade = grade,
                    name = name,
                    label = label,
                    salary = salary
                }
            )
        else
            MySQL.insert.await(
                [[
                    INSERT INTO job_grades
                    (
                        job_name,
                        grade,
                        name,
                        label,
                        salary,
                        skin_male,
                        skin_female
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ]],
                {
                    job,
                    grade,
                    name,
                    label,
                    salary,
                    '{}',
                    '{}'
                }
            )

            logAction(
                source,
                'create_grade',
                job,
                {
                    grade = grade,
                    name = name,
                    label = label,
                    salary = salary
                }
            )
        end


        refreshESXJobs()


        reply(
            cb,
            true,
            'Rang opgeslagen en ESX jobs vernieuwd.'
        )
    end
)


-- =========================================================
-- DELETE GRADE
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:deleteGrade',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(
                cb,
                false,
                'Geen toestemming.'
            )
        end

        data =
            type(data) == 'table'
            and data
            or {}


        local job =
            trim(
                tostring(
                    data.jobName
                    or ''
                )
            ):lower()


        local grade =
            tonumber(
                data.grade
            )


        if not validJob(job) then
            return reply(
                cb,
                false,
                'Job bestaat niet.'
            )
        end


        if grade == nil then
            return reply(
                cb,
                false,
                'Ongeldig rangnummer.'
            )
        end


        if grade == 0 then
            return reply(
                cb,
                false,
                'Rang 0 kan niet verwijderd worden.'
            )
        end


        MySQL.update.await(
            [[
                UPDATE users
                SET job_grade = 0
                WHERE job = ?
                  AND job_grade = ?
            ]],
            {
                job,
                grade
            }
        )


        MySQL.update.await(
            [[
                DELETE FROM job_grades
                WHERE job_name = ?
                  AND grade = ?
            ]],
            {
                job,
                grade
            }
        )


        refreshESXJobs()


        logAction(
            source,
            'delete_grade',
            job,
            {
                grade = grade
            }
        )


        reply(
            cb,
            true,
            'Rang verwijderd.'
        )
    end
)


-- =========================================================
-- SAVE POINT
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:savePoint',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(
                cb,
                false,
                'Geen toestemming.'
            )
        end

        data =
            type(data) == 'table'
            and data
            or {}


        local id =
            tonumber(
                data.id
            )


        local job = nil

        if data.jobName
            and data.jobName ~= '' then

            job =
                trim(
                    tostring(
                        data.jobName
                    )
                ):lower()
        end


        local pointType =
            trim(
                tostring(
                    data.type
                    or ''
                )
            )


        local label =
            trim(
                tostring(
                    data.label
                    or ''
                )
            )


        local minGrade =
            math.max(
                0,
                math.floor(
                    tonumber(
                        data.minGrade
                    )
                    or 0
                )
            )


        local radius =
            math.min(
                10.0,
                math.max(
                    0.5,
                    tonumber(
                        data.radius
                    )
                    or 1.5
                )
            )


        if not Config.PointTypes
            or not Config.PointTypes[
                pointType
            ] then

            return reply(
                cb,
                false,
                'Onbekend punt-type.'
            )
        end


        if job
            and not validJob(job) then

            return reply(
                cb,
                false,
                'Geselecteerde job bestaat niet.'
            )
        end


        if #label < 1
            or #label > 100 then

            return reply(
                cb,
                false,
                'Ongeldig label.'
            )
        end


        local x, y, z, w


        if data.useCurrent then
            x, y, z, w =
                getServerCoords(
                    source
                )
        else
            x =
                tonumber(
                    data.x
                )

            y =
                tonumber(
                    data.y
                )

            z =
                tonumber(
                    data.z
                )

            w =
                tonumber(
                    data.w
                )
                or 0.0
        end


        if not x
            or not y
            or not z then

            return reply(
                cb,
                false,
                'Geen geldige positie ontvangen.'
            )
        end


        local settings =
            normalizeSettings(
                data.settings
            )


        if id then
            local exists =
                MySQL.single.await(
                    [[
                        SELECT id
                        FROM rs_jobscreator_points
                        WHERE id = ?
                        LIMIT 1
                    ]],
                    {
                        id
                    }
                )


            if not exists then
                return reply(
                    cb,
                    false,
                    'Interactiepunt bestaat niet meer.'
                )
            end


            MySQL.update.await(
                [[
                    UPDATE rs_jobscreator_points
                    SET
                        job_name = ?,
                        type = ?,
                        label = ?,
                        x = ?,
                        y = ?,
                        z = ?,
                        w = ?,
                        min_grade = ?,
                        radius = ?,
                        public = ?,
                        enabled = ?,
                        settings = ?
                    WHERE id = ?
                ]],
                {
                    job,
                    pointType,
                    label,
                    x,
                    y,
                    z,
                    w,
                    minGrade,
                    radius,

                    data.public
                    and 1
                    or 0,

                    data.enabled == false
                    and 0
                    or 1,

                    encode(settings),

                    id
                }
            )


            logAction(
                source,
                'update_point',
                job,
                {
                    id = id,
                    type = pointType,
                    label = label
                }
            )
        else
            id =
                MySQL.insert.await(
                    [[
                        INSERT INTO rs_jobscreator_points
                        (
                            job_name,
                            type,
                            label,
                            x,
                            y,
                            z,
                            w,
                            min_grade,
                            radius,
                            public,
                            enabled,
                            settings
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ]],
                    {
                        job,
                        pointType,
                        label,
                        x,
                        y,
                        z,
                        w,
                        minGrade,
                        radius,

                        data.public
                        and 1
                        or 0,

                        data.enabled == false
                        and 0
                        or 1,

                        encode(settings)
                    }
                )


            logAction(
                source,
                'create_point',
                job,
                {
                    id = id,
                    type = pointType,
                    label = label
                }
            )
        end


        TriggerClientEvent(
            'rs_jobscreator:client:refreshPoints',
            -1
        )


        reply(
            cb,
            true,
            'Interactiepunt opgeslagen.',
            {
                id = id
            }
        )
    end
)


-- =========================================================
-- DELETE POINT
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:deletePoint',
    function(source, cb, data)
        if not isAdmin(source) then
            return reply(
                cb,
                false,
                'Geen toestemming.'
            )
        end

        local id =
            tonumber(
                (data or {}).id
            )

        if not id then
            return reply(
                cb,
                false,
                'Ongeldig punt.'
            )
        end


        local row =
            MySQL.single.await(
                [[
                    SELECT
                        job_name,
                        type
                    FROM rs_jobscreator_points
                    WHERE id = ?
                    LIMIT 1
                ]],
                {
                    id
                }
            )


        if not row then
            return reply(
                cb,
                false,
                'Interactiepunt bestaat niet.'
            )
        end


        MySQL.update.await(
            [[
                DELETE FROM rs_jobscreator_points
                WHERE id = ?
            ]],
            {
                id
            }
        )


        logAction(
            source,
            'delete_point',
            row.job_name,
            {
                id = id,
                type = row.type
            }
        )


        TriggerClientEvent(
            'rs_jobscreator:client:refreshPoints',
            -1
        )


        reply(
            cb,
            true,
            'Interactiepunt verwijderd.'
        )
    end
)


-- =========================================================
-- GET ACTIVE POINTS
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:getPoints',
    function(source, cb)
        local rows =
            MySQL.query.await([[
                SELECT *
                FROM rs_jobscreator_points
                WHERE enabled = 1
                ORDER BY id ASC
            ]])
            or {}

        for _, point in ipairs(rows) do
            point.settings =
                decode(
                    point.settings
                )
        end

        cb(rows)
    end
)


-- =========================================================
-- RESOURCE IMPORTER
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:getImportResources',
    function(source, cb)
        if not isAdmin(source) then
            return cb({
                success = false,
                message = 'Geen toestemming.'
            })
        end

        if not RSJobScanner then
            return cb({
                success = false,
                message = 'Resource scanner is niet geladen.'
            })
        end

        cb({
            success = true,

            resources =
                RSJobScanner.GetResources(
                    'rs-'
                )
        })
    end
)


ESX.RegisterServerCallback(
    'rs_jobscreator:scanResource',
    function(source, cb, data)
        if not isAdmin(source) then
            return cb({
                success = false,
                message = 'Geen toestemming.'
            })
        end

        data =
            type(data) == 'table'
            and data
            or {}

        local resource =
            tostring(
                data.resource
                or ''
            )

        if resource == '' then
            return cb({
                success = false,
                message = 'Geen resource geselecteerd.'
            })
        end

        if resource == RESOURCE then
            return cb({
                success = false,
                message = 'Jobs Creator kan zichzelf niet scannen.'
            })
        end

        local scan, err =
            RSJobScanner.Scan(
                resource
            )

        if not scan then
            return cb({
                success = false,

                message =
                    err
                    or 'Resource scan mislukt.'
            })
        end


        resourceScanCache[source] = {
            resource = resource,
            scan = scan,
            scannedAt = os.time()
        }


        logAction(
            source,
            'scan_resource',
            nil,
            {
                resource = resource,
                summary = scan.summary
            }
        )


        cb({
            success = true,

            message = (
                '%s gescand: %s suggestie(s) gevonden.'
            ):format(
                resource,
                #(scan.suggestions or {})
            ),

            scan = scan
        })
    end
)


ESX.RegisterServerCallback(
    'rs_jobscreator:getLastResourceScan',
    function(source, cb)
        if not isAdmin(source) then
            return cb({
                success = false,
                message = 'Geen toestemming.'
            })
        end

        local cached =
            resourceScanCache[source]

        if not cached then
            return cb({
                success = true,
                scan = nil
            })
        end

        cb({
            success = true,

            resource =
                cached.resource,

            scannedAt =
                cached.scannedAt,

            scan =
                cached.scan
        })
    end
)


-- =========================================================
-- OX INVENTORY ITEM LIST
-- =========================================================

ESX.RegisterServerCallback(
    'rs_jobscreator:getInventoryItems',
    function(source, cb)
        if not isAdmin(source) then
            return cb({
                success = false,
                message = 'Geen toestemming.'
            })
        end


        if GetResourceState(
            'ox_inventory'
        ) ~= 'started' then

            return cb({
                success = false,
                message = 'ox_inventory is niet gestart.'
            })
        end


        local ok, items =
            pcall(function()
                return exports.ox_inventory:Items()
            end)


        if not ok
            or type(items) ~= 'table' then

            return cb({
                success = false,
                message = 'Kon ox_inventory items niet ophalen.'
            })
        end


        local result = {}


        for name, item in pairs(items) do
            result[
                #result + 1
            ] = {
                name =
                    name,

                label =
                    item.label
                    or name,

                weight =
                    tonumber(
                        item.weight
                    )
                    or 0,

                stack =
                    item.stack
                    ~= false
            }
        end


        table.sort(
            result,
            function(a, b)
                return (
                    a.label
                    or a.name
                ):lower()
                    <
                (
                    b.label
                    or b.name
                ):lower()
            end
        )


        cb({
            success = true,
            items = result
        })
    end
)


-- =========================================================
-- SHOP
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:buyItem',
    function(id, itemName, count)
        local src = source

        count =
            math.floor(
                tonumber(count)
                or 1
            )

        if count < 1
            or count > 100 then

            return
        end


        itemName =
            trim(
                tostring(
                    itemName
                    or ''
                )
            )


        local point, err =
            getPoint(
                src,
                id,
                {
                    'shop',
                    'jobshop',
                    'market'
                }
            )


        if not point then
            return notify(
                src,
                err,
                false
            )
        end


        local chosen = nil

        for _, item in ipairs(
            point.settings.items
            or {}
        ) do
            if item.name
                == itemName then

                chosen = item
                break
            end
        end


        if not chosen then
            return notify(
                src,
                'Product bestaat niet.',
                false
            )
        end


        local total =
            math.max(
                0,
                tonumber(
                    chosen.price
                )
                or 0
            ) * count


        local xPlayer =
            getPlayer(src)

        if not xPlayer then
            return
        end


        local account =
            point.settings.account
            == 'money'
            and 'money'
            or 'bank'


        if account == 'money' then
            if xPlayer.getMoney()
                < total then

                return notify(
                    src,
                    'Onvoldoende contant geld.',
                    false
                )
            end

            xPlayer.removeMoney(
                total
            )
        else
            local bank =
                xPlayer.getAccount(
                    'bank'
                )

            if not bank
                or bank.money < total then

                return notify(
                    src,
                    'Onvoldoende bankgeld.',
                    false
                )
            end

            xPlayer.removeAccountMoney(
                'bank',
                total
            )
        end


        local success =
            exports.ox_inventory:AddItem(
                src,
                itemName,
                count
            )


        if not success then
            if account == 'money' then
                xPlayer.addMoney(
                    total
                )
            else
                xPlayer.addAccountMoney(
                    'bank',
                    total
                )
            end

            return notify(
                src,
                'Geen ruimte voor het item.',
                false
            )
        end


        notify(
            src,
            ('Gekocht: %sx %s voor €%s.'):format(
                count,
                chosen.label
                    or itemName,
                total
            ),
            true
        )
    end
)


-- =========================================================
-- CRAFTING
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:craft',
    function(id, recipeIndex)
        local src = source

        local point, err =
            getPoint(
                src,
                id,
                {
                    'crafting'
                }
            )

        if not point then
            return notify(
                src,
                err,
                false
            )
        end


        local recipes =
            point.settings.recipes
            or {}

        local recipe =
            recipes[
                tonumber(
                    recipeIndex
                )
                or 0
            ]


        if not recipe
            or not recipe.result then

            return notify(
                src,
                'Recept bestaat niet.',
                false
            )
        end


        for item, amount in pairs(
            recipe.ingredients
            or {}
        ) do
            local count =
                exports.ox_inventory:Search(
                    src,
                    'count',
                    item
                )
                or 0

            if count
                < tonumber(amount) then

                return notify(
                    src,
                    'Niet genoeg benodigdheden.',
                    false
                )
            end
        end


        local removedItems = {}


        for item, amount in pairs(
            recipe.ingredients
            or {}
        ) do
            amount =
                tonumber(amount)
                or 0

            local removed =
                exports.ox_inventory:RemoveItem(
                    src,
                    item,
                    amount
                )

            if not removed then
                for rollbackItem, rollbackAmount
                    in pairs(removedItems) do

                    exports.ox_inventory:AddItem(
                        src,
                        rollbackItem,
                        rollbackAmount
                    )
                end

                return notify(
                    src,
                    'Kon materialen niet verwijderen.',
                    false
                )
            end

            removedItems[item] =
                amount
        end


        local duration =
            math.max(
                500,
                tonumber(
                    recipe.duration
                )
                or 5000
            )


        TriggerClientEvent(
            'rs_jobscreator:client:progress',
            src,
            duration,
            recipe.label
                or 'Craften'
        )


        SetTimeout(
            duration,
            function()
                if GetPlayerPed(src) <= 0 then
                    return
                end

                local success =
                    exports.ox_inventory:AddItem(
                        src,
                        recipe.result,
                        tonumber(
                            recipe.count
                        )
                        or 1
                    )

                if not success then
                    for item, amount in pairs(
                        removedItems
                    ) do
                        exports.ox_inventory:AddItem(
                            src,
                            item,
                            amount
                        )
                    end

                    return notify(
                        src,
                        'Geen ruimte; materialen teruggegeven.',
                        false
                    )
                end

                notify(
                    src,
                    'Product gemaakt.',
                    true
                )
            end
        )
    end
)


-- =========================================================
-- HARVEST
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:harvest',
    function(id)
        local src = source

        local point, err =
            getPoint(
                src,
                id,
                {
                    'harvest'
                }
            )

        if not point then
            return notify(
                src,
                err,
                false
            )
        end


        local settings =
            point.settings


        if not settings.item
            or settings.item == '' then

            return notify(
                src,
                'Dit verzamelpunt is niet goed ingesteld.',
                false
            )
        end


        if settings.tool
            and settings.tool ~= '' then

            local toolCount =
                exports.ox_inventory:Search(
                    src,
                    'count',
                    settings.tool
                )
                or 0

            if toolCount < 1 then
                return notify(
                    src,
                    'Je mist het benodigde gereedschap.',
                    false
                )
            end
        end


        local duration =
            math.max(
                500,
                tonumber(
                    settings.duration
                )
                or 3500
            )


        TriggerClientEvent(
            'rs_jobscreator:client:progress',
            src,
            duration,
            'Verzamelen'
        )


        SetTimeout(
            duration,
            function()
                if GetPlayerPed(src) <= 0 then
                    return
                end

                local success =
                    exports.ox_inventory:AddItem(
                        src,
                        settings.item,
                        tonumber(
                            settings.count
                        )
                        or 1
                    )

                if not success then
                    notify(
                        src,
                        'Geen ruimte in je inventaris.',
                        false
                    )
                end
            end
        )
    end
)


-- =========================================================
-- PROCESS
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:process',
    function(id)
        local src = source

        local point, err =
            getPoint(
                src,
                id,
                {
                    'process'
                }
            )

        if not point then
            return notify(
                src,
                err,
                false
            )
        end


        local settings =
            point.settings


        if not settings.input
            or not settings.output
            or not settings.input.item
            or not settings.output.item then

            return notify(
                src,
                'Verwerkingspunt is niet goed ingesteld.',
                false
            )
        end


        local inputCount =
            math.max(
                1,
                tonumber(
                    settings.input.count
                )
                or 1
            )


        local available =
            exports.ox_inventory:Search(
                src,
                'count',
                settings.input.item
            )
            or 0


        if available < inputCount then
            return notify(
                src,
                'Niet genoeg grondstoffen.',
                false
            )
        end


        local removed =
            exports.ox_inventory:RemoveItem(
                src,
                settings.input.item,
                inputCount
            )


        if not removed then
            return notify(
                src,
                'Kon grondstoffen niet verwijderen.',
                false
            )
        end


        local duration =
            math.max(
                500,
                tonumber(
                    settings.duration
                )
                or 5000
            )


        TriggerClientEvent(
            'rs_jobscreator:client:progress',
            src,
            duration,
            'Verwerken'
        )


        SetTimeout(
            duration,
            function()
                if GetPlayerPed(src) <= 0 then
                    return
                end

                local outputCount =
                    math.max(
                        1,
                        tonumber(
                            settings.output.count
                        )
                        or 1
                    )

                local success =
                    exports.ox_inventory:AddItem(
                        src,
                        settings.output.item,
                        outputCount
                    )

                if not success then
                    exports.ox_inventory:AddItem(
                        src,
                        settings.input.item,
                        inputCount
                    )

                    return notify(
                        src,
                        'Geen ruimte; grondstoffen teruggegeven.',
                        false
                    )
                end

                notify(
                    src,
                    'Verwerking voltooid.',
                    true
                )
            end
        )
    end
)


-- =========================================================
-- STORAGE
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:openStorage',
    function(id, requestedType)
        local src = source

        local pointType =
            requestedType == 'armory'
            and 'armory'
            or 'stash'


        local point, err =
            getPoint(
                src,
                id,
                {
                    pointType
                }
            )

        if not point then
            return notify(
                src,
                err,
                false
            )
        end


        local stashId =
            ('rs_jobcreator_%s_%s'):format(
                point.id,
                pointType
            )


        local ok, registerErr =
            pcall(function()
                exports.ox_inventory:RegisterStash(
                    stashId,
                    point.label,
                    tonumber(
                        point.settings.slots
                    )
                    or 80,

                    tonumber(
                        point.settings.weight
                    )
                    or 250000,

                    false
                )
            end)


        if not ok then
            debugLog(
                ('RegisterStash: %s'):format(
                    tostring(
                        registerErr
                    )
                )
            )
        end


        TriggerClientEvent(
            'rs_jobscreator:client:openStash',
            src,
            stashId
        )
    end
)


-- =========================================================
-- TELEPORT
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:teleport',
    function(id)
        local src = source

        local point, err =
            getPoint(
                src,
                id,
                {
                    'teleport'
                }
            )

        if not point then
            return notify(
                src,
                err,
                false
            )
        end


        local destination =
            point.settings.destination


        if not destination
            or destination.x == nil
            or destination.y == nil
            or destination.z == nil then

            return notify(
                src,
                'Teleportbestemming is niet ingesteld.',
                false
            )
        end


        TriggerClientEvent(
            'rs_jobscreator:client:teleport',
            src,
            destination,
            point.settings.allowVehicle
                == true
        )
    end
)


-- =========================================================
-- DUTY
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:toggleDuty',
    function(id)
        local src = source

        -- BELANGRIJK:
        -- Duty-punt moet bereikbaar zijn terwijl speler nog UIT dienst is.
        -- Daarom valideren we hier NIET via getPoint(), want getPoint()
        -- roept requireDuty() aan.
        local point = MySQL.single.await(
            [[
                SELECT *
                FROM rs_jobscreator_points
                WHERE id = ?
                  AND enabled = 1
                  AND type = 'duty'
                LIMIT = 1
            ]],
            { tonumber(id) }
        )

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

        notify(src, message or (success and 'Dienststatus aangepast.' or 'Duty mislukt.'), success)

        TriggerClientEvent(
            'rs_jobscreator:client:toggleDuty',
            src
        )
    end
)

-- =========================================================
-- BOSS MENU
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:openBossMenu',
    function(id)
        local src = source

        local point = MySQL.single.await(
            [[
                SELECT *
                FROM rs_jobscreator_points
                WHERE id = ?
                  AND enabled = 1
                  AND type = 'bossmenu'
                LIMIT 1
            ]],
            { tonumber(id) }
        )

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

        if tostring(xPlayer.job.grade_name or ''):lower() ~= 'boss' then
            return notify(src, 'Alleen de baas kan dit menu openen.', false)
        end

        if GetResourceState('rs-bossmenu') ~= 'started' then
            return notify(src, 'rs-bossmenu is niet gestart.', false)
        end

        TriggerClientEvent(
            'rs-bossmenu:client:open',
            src,
            point.job_name
        )
    end
)

-- =========================================================
-- GARAGE
-- =========================================================

RegisterNetEvent(
    'rs_jobscreator:server:spawnVehicle',
    function(id, vehicleIndex)
        local src = source

        local point, err =
            getPoint(
                src,
                id,
                {
                    'garage'
                }
            )

        if not point then
            return notify(
                src,
                err,
                false
            )
        end


        local vehicles =
            point.settings.vehicles
            or {}


        local index =
            tonumber(
                vehicleIndex
            )


        if not index then
            return notify(
                src,
                'Ongeldig voertuig.',
                false
            )
        end


        local vehicle =
            vehicles[index]


        if not vehicle
            or not vehicle.model then

            return notify(
                src,
                'Voertuig bestaat niet.',
                false
            )
        end


        TriggerClientEvent(
            'rs_jobscreator:client:spawnVehicle',
            src,
            vehicle.model,
            vehicle.label
                or vehicle.model
        )
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
    function(source)
        if source == 0 then
            return log(
                'INFO',
                'Dit commando moet in-game gebruikt worden.'
            )
        end

        if not isAdmin(source) then
            return notify(
                source,
                'Geen toegang tot Jobs Creator.',
                false
            )
        end

        TriggerClientEvent(
            'rs_jobscreator:client:open',
            source
        )
    end,
    false
)


-- =========================================================
-- /scanjobresource
-- =========================================================

local function commandMessage(
    source,
    message
)
    if source == 0 then
        print(
            ('[rs-jobscreator] %s'):format(
                tostring(message)
            )
        )

        return
    end


    TriggerClientEvent(
        'chat:addMessage',
        source,
        {
            color = {
                99,
                139,
                255
            },

            args = {
                'RS Jobs Creator',
                tostring(message)
            }
        }
    )
end


local function getAllResources()
    local resources = {}

    local count =
        GetNumResources()

    for index = 0, count - 1 do
        local name =
            GetResourceByFindIndex(
                index
            )

        if name
            and name ~= '' then

            resources[
                #resources + 1
            ] = name
        end
    end


    table.sort(
        resources,
        function(a, b)
            return a:lower()
                < b:lower()
        end
    )


    return resources
end


local function wildcardToPattern(value)
    value =
        value:gsub(
            '([%%%^%$%(%)%.%[%]%+%-%?])',
            '%%%1'
        )

    value =
        value:gsub(
            '%*',
            '.*'
        )

    return '^'
        .. value
        .. '$'
end


local function findResources(query)
    if type(query) ~= 'string'
        or query == '' then

        return {}
    end


    local all =
        getAllResources()


    if not query:find(
        '*',
        1,
        true
    ) then
        for _, resource in ipairs(all) do
            if resource:lower()
                == query:lower() then

                return {
                    resource
                }
            end
        end

        return {}
    end


    local pattern =
        wildcardToPattern(
            query:lower()
        )


    local results = {}


    for _, resource in ipairs(all) do
        if resource:lower():match(
            pattern
        ) then
            results[
                #results + 1
            ] = resource
        end
    end


    return results
end


local function scanResourceCommand(
    commandSource,
    resource
)
    commandMessage(
        commandSource,
        ('Scanner: %s [%s]'):format(
            resource,
            GetResourceState(
                resource
            )
        )
    )


    local scan, err =
        RSJobScanner.Scan(
            resource
        )


    if not scan then
        commandMessage(
            commandSource,
            ('Scan mislukt voor %s: %s'):format(
                resource,
                err
                    or 'Onbekende fout'
            )
        )

        return false
    end


    -- Commandscan ook bewaren voor Importeren-tab.
    if commandSource > 0 then
        resourceScanCache[
            commandSource
        ] = {
            resource = resource,
            scan = scan,
            scannedAt = os.time()
        }
    end


    local summary =
        scan.summary
        or {}


    commandMessage(
        commandSource,
        (
            '%s → bestanden:%s | items:%s | recepten:%s | process:%s | harvest:%s | stashes:%s | voertuigen:%s | locaties:%s | blips:%s | suggesties:%s'
        ):format(
            resource,

            summary.files
                or #(scan.files or {}),

            summary.items
                or #(scan.items or {}),

            summary.recipes
                or #(scan.recipes or {}),

            summary.processes
                or #(scan.processes or {}),

            summary.harvest
                or #(scan.harvest or {}),

            summary.stashes
                or #(scan.stashes or {}),

            summary.vehicles
                or #(scan.vehicles or {}),

            summary.locations
                or #(scan.locations or {}),

            summary.blips
                or #(scan.blips or {}),

            summary.suggestions
                or #(scan.suggestions or {})
        )
    )


    print(
        ('[rs-jobscreator] Scan resultaat %s: %s'):format(
            resource,
            json.encode(
                summary
            )
        )
    )


    if commandSource > 0 then
        logAction(
            commandSource,
            'command_scan_resource',
            nil,
            {
                resource = resource,
                summary = summary
            }
        )
    end


    return true
end


RegisterCommand(
    'scanjobresource',
    function(source, args)
        if source ~= 0
            and not isAdmin(source) then

            return commandMessage(
                source,
                'Je hebt geen toestemming om resources te scannen.'
            )
        end


        local query =
            tostring(
                args[1]
                or ''
            )


        if query == '' then
            commandMessage(
                source,
                'Gebruik: /scanjobresource [resource]'
            )

            commandMessage(
                source,
                'Voorbeeld: /scanjobresource rs-bikemechanic'
            )

            commandMessage(
                source,
                'Wildcard: /scanjobresource rs-*'
            )

            commandMessage(
                source,
                'Zoeken: /scanjobresource *mechanic*'
            )

            return
        end


        local resources =
            findResources(
                query
            )


        if #resources == 0 then
            return commandMessage(
                source,
                ('Geen resource gevonden voor "%s".'):format(
                    query
                )
            )
        end


        local maximum = 50

        if #resources > maximum then
            return commandMessage(
                source,
                ('Je selectie bevat %s resources. Maximum is %s.'):format(
                    #resources,
                    maximum
                )
            )
        end


        commandMessage(
            source,
            ('%s resource(s) gevonden. Scan gestart.'):format(
                #resources
            )
        )


        CreateThread(function()
            local successCount = 0
            local failedCount = 0


            for _, resource in ipairs(resources) do
                local success =
                    scanResourceCommand(
                        source,
                        resource
                    )

                if success then
                    successCount =
                        successCount + 1
                else
                    failedCount =
                        failedCount + 1
                end

                Wait(50)
            end


            commandMessage(
                source,
                ('Scan klaar: %s geslaagd, %s mislukt.'):format(
                    successCount,
                    failedCount
                )
            )
        end)
    end,
    false
)


-- =========================================================
-- PLAYER CLEANUP
-- =========================================================

AddEventHandler(
    'playerDropped',
    function()
        resourceScanCache[
            source
        ] = nil
    end
)


-- =========================================================
-- EXPORTS
-- =========================================================

exports(
    'GetState',
    getState
)


exports(
    'IsAdmin',
    isAdmin
)


exports(
    'ValidJob',
    validJob
)