local ESX = exports['es_extended']:getSharedObject()
local RESOURCE = GetCurrentResourceName()

local jobScanCache = {}

local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return value:gsub('^%s+', ''):gsub('%s+$', '')
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

    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    return Config.AdminGroups and Config.AdminGroups[group] == true
end

local function validResourceName(resource)
    return type(resource) == 'string'
        and resource ~= ''
        and resource:match('^[%w%-%_%.]+$') ~= nil
end

local function readFile(resource, path)
    if not validResourceName(resource) or type(path) ~= 'string' or path == '' then
        return nil
    end

    return LoadResourceFile(resource, path)
end

local function collectLuaFiles(resource)
    local files = {}
    local seen = {}

    local function add(path)
        if type(path) ~= 'string' or path == '' then
            return
        end

        path = path:gsub('^%./', '')

        if seen[path]
            or not path:match('%.lua$')
            or path:find('%*') then
            return
        end

        if readFile(resource, path) then
            seen[path] = true
            files[#files + 1] = path
        end
    end

    local metadataKeys = {
        'client_script',
        'server_script',
        'shared_script',
        'file'
    }

    for _, key in ipairs(metadataKeys) do
        local count = GetNumResourceMetadata(resource, key) or 0

        for index = 0, count - 1 do
            add(GetResourceMetadata(resource, key, index))
        end
    end

    for _, path in ipairs({
        'config.lua',
        'shared.lua',
        'shared/config.lua',
        'shared/main.lua',
        'client.lua',
        'client/main.lua',
        'server.lua',
        'server/main.lua',
        'main.lua'
    }) do
        add(path)
    end

    return files
end

local function normaliseJobName(name)
    name = trim(tostring(name or '')):lower()

    if #name < 2 or #name > 50 then
        return nil
    end

    if not name:match('^[a-z][a-z0-9_]+$') then
        return nil
    end

    return name
end

local function addCandidate(candidates, seen, candidate)
    local name = normaliseJobName(candidate.name)
    if not name then
        return
    end

    candidate.name = name
    candidate.label = trim(candidate.label or '')

    if candidate.label == '' then
        candidate.label = name:gsub('_', ' '):gsub('^%l', string.upper)
    end

    local key = name
    local current = seen[key]

    if current then
        if (candidate.confidence or 0) > (current.confidence or 0) then
            current.label = candidate.label
            current.source = candidate.source
            current.confidence = candidate.confidence
            current.reason = candidate.reason
        end
        return current
    end

    candidate.grades = candidate.grades or {}
    candidates[#candidates + 1] = candidate
    seen[key] = candidate
    return candidate
end

local function scanJobNames(content, file, candidates, seen)
    if type(content) ~= 'string' then
        return
    end

    for name, label in content:gmatch("RegisterSociety%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*['\"]([^'\"]+)['\"]") do
        addCandidate(candidates, seen, {
            name = name,
            label = label,
            source = file,
            confidence = 100,
            reason = 'ESX.RegisterSociety'
        })
    end

    local directPatterns = {
        "Config%.JobName%s*=%s*['\"]([^'\"]+)['\"]",
        "Config%.Job%s*=%s*['\"]([^'\"]+)['\"]",
        "Config%.Society%s*=%s*['\"]([^'\"]+)['\"]"
    }

    for _, pattern in ipairs(directPatterns) do
        for name in content:gmatch(pattern) do
            addCandidate(candidates, seen, {
                name = name,
                source = file,
                confidence = 90,
                reason = 'Config jobnaam'
            })
        end
    end

    for block in content:gmatch('{[^{}]-}') do
        local name = block:match("[Jj][Oo][Bb]%s*=%s*['\"]([^'\"]+)['\"]")
            or block:match("[Nn][Aa][Mm][Ee]%s*=%s*['\"]([^'\"]+)['\"]")

        local label = block:match("[Ll][Aa][Bb][Ee][Ll]%s*=%s*['\"]([^'\"]+)['\"]")

        if name and label and block:lower():find('job') then
            addCandidate(candidates, seen, {
                name = name,
                label = label,
                source = file,
                confidence = 65,
                reason = 'Job configblok'
            })
        end
    end
end

local function scanGrades(content, candidate)
    if type(content) ~= 'string' or not candidate then
        return
    end

    local seen = {}

    for _, grade in ipairs(candidate.grades or {}) do
        seen[tonumber(grade.grade)] = true
    end

    for number, block in content:gmatch("%[?(%d+)%]?%s*=%s*({[^{}]-})") do
        local grade = tonumber(number)
        local name = block:match("[Nn][Aa][Mm][Ee]%s*=%s*['\"]([^'\"]+)['\"]")
        local label = block:match("[Ll][Aa][Bb][Ee][Ll]%s*=%s*['\"]([^'\"]+)['\"]")
        local salary = tonumber(block:match("[Ss][Aa][Ll][Aa][Rr][Yy]%s*=%s*(%d+)")) or 0

        if grade and (name or label) and not seen[grade] then
            candidate.grades[#candidate.grades + 1] = {
                grade = grade,
                name = normaliseJobName(name or ('grade_' .. grade)) or ('grade_' .. grade),
                label = label or name or ('Rang ' .. grade),
                salary = math.max(0, math.floor(salary))
            }
            seen[grade] = true
        end
    end

    table.sort(candidate.grades, function(a, b)
        return (a.grade or 0) < (b.grade or 0)
    end)
end

local function scanResourceJobs(resource)
    if not validResourceName(resource) then
        return nil, 'Ongeldige resourcenaam.'
    end

    if GetResourceState(resource) == 'missing' then
        return nil, 'Resource bestaat niet.'
    end

    local files = collectLuaFiles(resource)
    local candidates = {}
    local seen = {}

    for _, file in ipairs(files) do
        local content = readFile(resource, file)
        if content then
            scanJobNames(content, file, candidates, seen)
        end
    end

    for _, candidate in ipairs(candidates) do
        for _, file in ipairs(files) do
            local content = readFile(resource, file)
            if content then
                local lower = content:lower()
                if lower:find(candidate.name, 1, true) then
                    scanGrades(content, candidate)
                end
            end
        end

        if #candidate.grades == 0 then
            candidate.grades = {
                {
                    grade = 0,
                    name = 'employee',
                    label = 'Medewerker',
                    salary = 0
                }
            }
        end
    end

    table.sort(candidates, function(a, b)
        if (a.confidence or 0) == (b.confidence or 0) then
            return a.name < b.name
        end

        return (a.confidence or 0) > (b.confidence or 0)
    end)

    return {
        resource = resource,
        files = files,
        jobs = candidates
    }
end

local function refreshESXJobs()
    if type(ESX.RefreshJobs) == 'function' then
        local ok = pcall(function()
            ESX.RefreshJobs()
        end)

        if ok then
            return
        end
    end

    pcall(function()
        ExecuteCommand('refreshjobs')
    end)
end

-- Fix: client/main.lua verwacht response.points of response.data.
-- De oude callback stuurde alleen de kale array terug, waardoor de client [] opsloeg.
ESX.RegisterServerCallback('rs_jobscreator:getPoints', function(_, cb)
    local rows = MySQL.query.await([[
        SELECT *
        FROM `rs_jobscreator_points`
        WHERE `enabled` = 1
        ORDER BY `id` ASC
    ]]) or {}

    for _, point in ipairs(rows) do
        if type(point.settings) == 'string' and point.settings ~= '' then
            local ok, decoded = pcall(json.decode, point.settings)
            point.settings = ok and type(decoded) == 'table' and decoded or {}
        elseif type(point.settings) ~= 'table' then
            point.settings = {}
        end
    end

    cb({
        success = true,
        points = rows
    })
end)

ESX.RegisterServerCallback('rs_jobscreator:getJobImportResources', function(source, cb)
    if not isAdmin(source) then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    local resources = {}
    local count = GetNumResources() or 0

    for index = 0, count - 1 do
        local resource = GetResourceByFindIndex(index)

        if resource
            and resource ~= RESOURCE
            and GetResourceState(resource) ~= 'missing' then
            resources[#resources + 1] = resource
        end
    end

    table.sort(resources)

    cb({
        success = true,
        resources = resources
    })
end)

ESX.RegisterServerCallback('rs_jobscreator:scanJobDefinitions', function(source, cb, data)
    if not isAdmin(source) then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    data = type(data) == 'table' and data or {}
    local resource = tostring(data.resource or '')

    if resource == '' then
        return cb({ success = false, message = 'Geen resource geselecteerd.' })
    end

    local scan, err = scanResourceJobs(resource)

    if not scan then
        return cb({ success = false, message = err or 'Jobscan mislukt.' })
    end

    jobScanCache[source] = scan

    cb({
        success = true,
        message = ('%s jobdefinitie(s) gevonden.'):format(#scan.jobs),
        scan = scan
    })
end)

ESX.RegisterServerCallback('rs_jobscreator:importJobDefinition', function(source, cb, data)
    if not isAdmin(source) then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    data = type(data) == 'table' and data or {}
    local resource = tostring(data.resource or '')
    local jobName = normaliseJobName(data.name)

    if not jobName then
        return cb({ success = false, message = 'Ongeldige jobnaam.' })
    end

    local scan = jobScanCache[source]

    if not scan or scan.resource ~= resource then
        local refreshed, err = scanResourceJobs(resource)
        if not refreshed then
            return cb({ success = false, message = err or 'Resource opnieuw scannen mislukt.' })
        end
        scan = refreshed
        jobScanCache[source] = scan
    end

    local candidate = nil
    for _, entry in ipairs(scan.jobs or {}) do
        if entry.name == jobName then
            candidate = entry
            break
        end
    end

    if not candidate then
        return cb({ success = false, message = 'Jobdefinitie niet meer gevonden.' })
    end

    local label = trim(candidate.label or '')
    if label == '' then
        label = jobName
    end

    MySQL.query.await([[
        INSERT INTO `jobs` (`name`, `label`)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE `label` = VALUES(`label`)
    ]], { jobName, label })

    local importedGrades = 0

    for _, grade in ipairs(candidate.grades or {}) do
        local gradeNumber = math.max(0, math.floor(tonumber(grade.grade) or 0))
        local gradeName = normaliseJobName(grade.name) or ('grade_' .. gradeNumber)
        local gradeLabel = trim(grade.label or '')
        local salary = math.max(0, math.floor(tonumber(grade.salary) or 0))

        if gradeLabel == '' then
            gradeLabel = gradeName
        end

        local existing = MySQL.single.await([[
            SELECT `id`
            FROM `job_grades`
            WHERE `job_name` = ? AND `grade` = ?
            LIMIT 1
        ]], { jobName, gradeNumber })

        if existing then
            MySQL.update.await([[
                UPDATE `job_grades`
                SET `name` = ?, `label` = ?, `salary` = ?
                WHERE `id` = ?
            ]], {
                gradeName,
                gradeLabel,
                salary,
                existing.id
            })
        else
            MySQL.insert.await([[
                INSERT INTO `job_grades`
                    (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`)
                VALUES (?, ?, ?, ?, ?, '{}', '{}')
            ]], {
                jobName,
                gradeNumber,
                gradeName,
                gradeLabel,
                salary
            })
        end

        importedGrades = importedGrades + 1
    end

    refreshESXJobs()

    cb({
        success = true,
        message = ('Job %s geïmporteerd met %s rang(en).'):format(jobName, importedGrades),
        job = jobName,
        grades = importedGrades
    })
end)
