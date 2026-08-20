local RESOURCE = GetCurrentResourceName()

RSJobScanner = {}

-- =========================================================
-- CONFIG
-- =========================================================

local SCANNER_DEBUG = true

local COMMON_FILES = {
    'config.lua',
    'shared.lua',

    'shared/config.lua',
    'shared/main.lua',

    'client.lua',
    'client/main.lua',
    'client/config.lua',

    'server.lua',
    'server/main.lua',
    'server/config.lua',

    'main.lua'
}


-- =========================================================
-- DEBUG
-- =========================================================

local function scannerDebug(message)
    if not SCANNER_DEBUG then
        return
    end

    print(('[rs-jobscreator:scanner] %s'):format(
        tostring(message)
    ))
end


-- =========================================================
-- GENERAL HELPERS
-- =========================================================

local function readFile(resource, path)
    if type(resource) ~= 'string'
        or type(path) ~= 'string'
        or resource == ''
        or path == '' then

        return nil
    end

    local content = LoadResourceFile(
        resource,
        path
    )

    if not content or content == '' then
        return nil
    end

    return content
end


local function validResourceName(resource)
    return type(resource) == 'string'
        and resource ~= ''
        and resource:match(
            '^[%w%-%_%.]+$'
        ) ~= nil
end


local function safeNumber(value, default)
    local number = tonumber(value)

    if number == nil then
        return default
    end

    return number
end


local function uniqueInsert(list, seen, value)
    if value == nil then
        return false
    end

    value = tostring(value)

    if value == '' or seen[value] then
        return false
    end

    seen[value] = true

    list[#list + 1] = value

    return true
end


local function cleanPath(path)
    if type(path) ~= 'string' then
        return nil
    end

    path = path:gsub('^%./', '')

    return path
end


local function normalizeBoolean(value)
    if value == true
        or value == 1
        or value == '1'
        or value == 'true' then

        return true
    end

    return false
end


-- =========================================================
-- RESOURCE FILE DISCOVERY
-- =========================================================

local function collectFiles(resource)
    local files = {}
    local seen = {}

    local function add(path)
        path = cleanPath(path)

        if not path or path == '' then
            return
        end

        if seen[path] then
            return
        end

        if not path:match('%.lua$') then
            return
        end

        if path:find('%*') then
            scannerDebug(
                ('Wildcard kan niet direct gelezen worden: %s'):format(
                    path
                )
            )

            return
        end

        local content = readFile(
            resource,
            path
        )

        if not content then
            return
        end

        seen[path] = true

        files[#files + 1] = path

        scannerDebug(
            ('Bestand gevonden: %s/%s'):format(
                resource,
                path
            )
        )
    end


    -- =====================================================
    -- MANIFEST
    -- =====================================================

    local manifest =
        readFile(
            resource,
            'fxmanifest.lua'
        )
        or readFile(
            resource,
            '__resource.lua'
        )


    if manifest then
        scannerDebug(
            ('Manifest gevonden voor %s'):format(
                resource
            )
        )

        -- Expliciet genoemde Lua-bestanden.
        for path in manifest:gmatch(
            "['\"]([^'\"]+%.lua)['\"]"
        ) do
            add(path)
        end
    else
        scannerDebug(
            ('Geen manifest gevonden voor %s'):format(
                resource
            )
        )
    end


    -- =====================================================
    -- RESOURCE METADATA
    -- =====================================================

    local metadataKeys = {
        'client_script',
        'server_script',
        'shared_script',
        'file'
    }

    for _, key in ipairs(metadataKeys) do
        local count =
            GetNumResourceMetadata(
                resource,
                key
            ) or 0

        scannerDebug(
            ('Metadata %s: %s'):format(
                key,
                count
            )
        )

        for index = 0, count - 1 do
            local value =
                GetResourceMetadata(
                    resource,
                    key,
                    index
                )

            add(value)
        end
    end


    -- =====================================================
    -- COMMON FILES FALLBACK
    -- =====================================================

    for _, path in ipairs(COMMON_FILES) do
        add(path)
    end


    scannerDebug(
        ('%s: %s leesbare Lua-bestanden'):format(
            resource,
            #files
        )
    )

    return files
end


-- =========================================================
-- ITEM HELPERS
-- =========================================================

local function addItem(result, item)
    if type(item) ~= 'table' then
        return
    end

    local name = item.name

    if type(name) ~= 'string'
        or name == '' then

        return
    end

    result._itemSeen =
        result._itemSeen or {}

    local key = (
        '%s:%s:%s'
    ):format(
        name,
        tostring(item.price or 0),
        tostring(item.source or '')
    )

    if result._itemSeen[key] then
        return
    end

    result._itemSeen[key] = true

    result.items[#result.items + 1] = {
        name = name,

        label =
            item.label
            or name,

        price =
            math.max(
                0,
                safeNumber(
                    item.price,
                    0
                )
            ),

        source =
            item.source
    }
end


local function addRemovedItem(list, item, count, source)
    if not item or item == '' then
        return
    end

    list[#list + 1] = {
        name = item,

        count =
            math.max(
                1,
                math.floor(
                    safeNumber(
                        count,
                        1
                    )
                )
            ),

        source = source
    }
end


-- =========================================================
-- GENERIC TABLE BLOCKS
-- =========================================================

local function scanSimpleBlocks(content, callback)
    if type(content) ~= 'string' then
        return
    end

    for block in content:gmatch(
        '{[^{}]-}'
    ) do
        callback(block)
    end
end


-- =========================================================
-- ITEMS / SHOPS
-- =========================================================

local function scanItems(content, file, result)
    -- =====================================================
    -- { name = 'repairkit', label = 'Repair Kit', price = 100 }
    -- { item = 'repairkit', label = 'Repair Kit', price = 100 }
    -- =====================================================

    scanSimpleBlocks(
        content,
        function(block)
            local name =
                block:match(
                    "[Nn][Aa][Mm][Ee]%s*=%s*['\"]([^'\"]+)['\"]"
                )
                or block:match(
                    "[Ii][Tt][Ee][Mm]%s*=%s*['\"]([^'\"]+)['\"]"
                )

            local label =
                block:match(
                    "[Ll][Aa][Bb][Ee][Ll]%s*=%s*['\"]([^'\"]+)['\"]"
                )

            local price =
                block:match(
                    "[Pp][Rr][Ii][Cc][Ee]%s*=%s*([%d%.]+)"
                )
                or block:match(
                    "[Cc][Oo][Ss][Tt]%s*=%s*([%d%.]+)"
                )

            if name and (label or price) then
                addItem(
                    result,
                    {
                        name = name,
                        label = label,
                        price = price,
                        source = file
                    }
                )
            end
        end
    )


    -- =====================================================
    -- ox_inventory:AddItem(source, 'item', count)
    -- exports.ox_inventory:AddItem(...)
    -- =====================================================

    for item in content:gmatch(
        "AddItem%s*%([^,]+,%s*['\"]([^'\"]+)['\"]"
    ) do
        addItem(
            result,
            {
                name = item,
                source = file
            }
        )
    end


    -- =====================================================
    -- ESX
    -- xPlayer.addInventoryItem('item', count)
    -- =====================================================

    for item in content:gmatch(
        "addInventoryItem%s*%(%s*['\"]([^'\"]+)['\"]"
    ) do
        addItem(
            result,
            {
                name = item,
                source = file
            }
        )
    end
end


-- =========================================================
-- ADD / REMOVE ITEM COLLECTION
-- =========================================================

local function collectRemovedItems(content, file)
    local items = {}


    -- ox_inventory

    for item, count in content:gmatch(
        "RemoveItem%s*%([^,]+,%s*['\"]([^'\"]+)['\"]%s*,%s*([%d]+)"
    ) do
        addRemovedItem(
            items,
            item,
            count,
            file
        )
    end


    -- ESX

    for item, count in content:gmatch(
        "removeInventoryItem%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*([%d]+)"
    ) do
        addRemovedItem(
            items,
            item,
            count,
            file
        )
    end


    return items
end


local function collectAddedItems(content, file)
    local items = {}


    -- ox_inventory

    for item, count in content:gmatch(
        "AddItem%s*%([^,]+,%s*['\"]([^'\"]+)['\"]%s*,%s*([%d]+)"
    ) do
        addRemovedItem(
            items,
            item,
            count,
            file
        )
    end


    -- ESX

    for item, count in content:gmatch(
        "addInventoryItem%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*([%d]+)"
    ) do
        addRemovedItem(
            items,
            item,
            count,
            file
        )
    end


    return items
end


-- =========================================================
-- HARVEST
-- =========================================================

local function addHarvest(result, harvest)
    result._harvestSeen =
        result._harvestSeen or {}

    local key = (
        '%s:%s:%s'
    ):format(
        tostring(harvest.item),
        tostring(harvest.count),
        tostring(harvest.source)
    )

    if result._harvestSeen[key] then
        return
    end

    result._harvestSeen[key] = true

    result.harvest[#result.harvest + 1] =
        harvest
end


local function scanHarvest(content, file, result)
    local added =
        collectAddedItems(
            content,
            file
        )

    local removed =
        collectRemovedItems(
            content,
            file
        )


    -- Alleen automatisch als het bestand items toevoegt
    -- maar niet verwijdert.
    if #added == 0
        or #removed > 0 then

        return
    end


    for _, item in ipairs(added) do
        addHarvest(
            result,
            {
                label =
                    ('Verzamel %s'):format(
                        item.name
                    ),

                item =
                    item.name,

                count =
                    item.count,

                duration =
                    3500,

                source =
                    file,

                confidence =
                    'medium'
            }
        )
    end
end


-- =========================================================
-- PROCESS
-- =========================================================

local function addProcess(result, process)
    result._processSeen =
        result._processSeen or {}

    local key = (
        '%s:%s:%s:%s'
    ):format(
        tostring(process.input.item),
        tostring(process.output.item),
        tostring(process.input.count),
        tostring(process.output.count)
    )

    if result._processSeen[key] then
        return
    end

    result._processSeen[key] = true

    result.processes[
        #result.processes + 1
    ] = process
end


local function scanProcesses(content, file, result)
    local removed =
        collectRemovedItems(
            content,
            file
        )

    local added =
        collectAddedItems(
            content,
            file
        )


    if #removed == 0
        or #added == 0 then

        return
    end


    -- Dit blijft een heuristische suggestie.
    -- We koppelen niet blind meerdere items aan elkaar.
    addProcess(
        result,
        {
            label =
                'Verwerken',

            input = {
                item =
                    removed[1].name,

                count =
                    removed[1].count
            },

            output = {
                item =
                    added[1].name,

                count =
                    added[1].count
            },

            duration =
                5000,

            source =
                file,

            confidence =
                'medium'
        }
    )
end


-- =========================================================
-- CRAFTING
-- =========================================================

local function addRecipe(result, recipe)
    if not recipe.result
        or recipe.result == '' then

        return
    end

    result._recipeSeen =
        result._recipeSeen or {}

    local key = (
        '%s:%s:%s'
    ):format(
        recipe.result,
        tostring(recipe.count or 1),
        tostring(recipe.source or '')
    )

    if result._recipeSeen[key] then
        return
    end

    result._recipeSeen[key] = true

    result.recipes[
        #result.recipes + 1
    ] = recipe
end


local function scanRecipes(content, file, result)
    -- =====================================================
    -- Simple recipe:
    --
    -- {
    --   result = 'repairkit',
    --   count = 1,
    --   label = 'Repair Kit',
    --   duration = 5000
    -- }
    -- =====================================================

    scanSimpleBlocks(
        content,
        function(block)
            local resultItem =
                block:match(
                    "[Rr][Ee][Ss][Uu][Ll][Tt]%s*=%s*['\"]([^'\"]+)['\"]"
                )
                or block:match(
                    "[Oo][Uu][Tt][Pp][Uu][Tt]%s*=%s*['\"]([^'\"]+)['\"]"
                )

            if not resultItem then
                return
            end


            local label =
                block:match(
                    "[Ll][Aa][Bb][Ee][Ll]%s*=%s*['\"]([^'\"]+)['\"]"
                )


            local count =
                safeNumber(
                    block:match(
                        "[Cc][Oo][Uu][Nn][Tt]%s*=%s*([%d]+)"
                    ),
                    1
                )


            local duration =
                safeNumber(
                    block:match(
                        "[Dd][Uu][Rr][Aa][Tt][Ii][Oo][Nn]%s*=%s*([%d]+)"
                    ),
                    5000
                )


            addRecipe(
                result,
                {
                    label =
                        label
                        or resultItem,

                    result =
                        resultItem,

                    count =
                        math.max(
                            1,
                            math.floor(count)
                        ),

                    duration =
                        math.max(
                            500,
                            math.floor(duration)
                        ),

                    ingredients =
                        {},

                    source =
                        file,

                    confidence =
                        'medium'
                }
            )
        end
    )
end


-- =========================================================
-- STASHES / ARMORIES
-- =========================================================

local function addStash(result, stash)
    result._stashSeen =
        result._stashSeen or {}

    local key = (
        '%s:%s'
    ):format(
        tostring(stash.id or stash.label),
        tostring(stash.type)
    )

    if result._stashSeen[key] then
        return
    end

    result._stashSeen[key] = true

    result.stashes[
        #result.stashes + 1
    ] = stash
end


local function scanStashes(content, file, result)
    -- =====================================================
    -- ox_inventory RegisterStash
    --
    -- RegisterStash('mechanic_stash', 'Mechanic', 100, 500000)
    -- =====================================================

    for id, label, slots, weight in content:gmatch(
        "RegisterStash%s*%(%s*['\"]([^'\"]+)['\"]%s*,%s*['\"]([^'\"]+)['\"]%s*,%s*([%d]+)%s*,%s*([%d]+)"
    ) do
        local lower =
            id:lower()


        local pointType =
            'stash'


        if lower:find(
            'armory',
            1,
            true
        )
            or lower:find(
                'weapon',
                1,
                true
            )
            or lower:find(
                'wapen',
                1,
                true
            ) then

            pointType =
                'armory'
        end


        addStash(
            result,
            {
                id =
                    id,

                type =
                    pointType,

                label =
                    label,

                settings = {
                    slots =
                        safeNumber(
                            slots,
                            80
                        ),

                    weight =
                        safeNumber(
                            weight,
                            250000
                        )
                },

                source =
                    file,

                confidence =
                    'high'
            }
        )
    end


    -- =====================================================
    -- Config style stash
    -- { stash = 'mechanic_storage', slots = 100, weight = 500000 }
    -- =====================================================

    scanSimpleBlocks(
        content,
        function(block)
            local stashId =
                block:match(
                    "[Ss][Tt][Aa][Ss][Hh]%s*=%s*['\"]([^'\"]+)['\"]"
                )

            if not stashId then
                return
            end


            local slots =
                safeNumber(
                    block:match(
                        "[Ss][Ll][Oo][Tt][Ss]%s*=%s*([%d]+)"
                    ),
                    80
                )


            local weight =
                safeNumber(
                    block:match(
                        "[Ww][Ee][Ii][Gg][Hh][Tt]%s*=%s*([%d]+)"
                    ),
                    250000
                )


            local lower =
                stashId:lower()


            local pointType =
                lower:find(
                    'armory',
                    1,
                    true
                )
                and 'armory'
                or 'stash'


            addStash(
                result,
                {
                    id =
                        stashId,

                    type =
                        pointType,

                    label =
                        stashId,

                    settings = {
                        slots =
                            slots,

                        weight =
                            weight
                    },

                    source =
                        file,

                    confidence =
                        'medium'
                }
            )
        end
    )
end


-- =========================================================
-- VEHICLES
-- =========================================================

local function addVehicle(result, vehicle)
    if not vehicle.model
        or vehicle.model == '' then

        return
    end

    result._vehicleSeen =
        result._vehicleSeen or {}

    local key =
        vehicle.model:lower()

    if result._vehicleSeen[key] then
        return
    end

    result._vehicleSeen[key] = true

    result.vehicles[
        #result.vehicles + 1
    ] = vehicle
end


local function scanVehicles(content, file, result)
    scanSimpleBlocks(
        content,
        function(block)
            local model =
                block:match(
                    "[Mm][Oo][Dd][Ee][Ll]%s*=%s*['\"]([^'\"]+)['\"]"
                )
                or block:match(
                    "[Vv][Ee][Hh][Ii][Cc][Ll][Ee]%s*=%s*['\"]([^'\"]+)['\"]"
                )


            if not model then
                return
            end


            local label =
                block:match(
                    "[Ll][Aa][Bb][Ee][Ll]%s*=%s*['\"]([^'\"]+)['\"]"
                )


            addVehicle(
                result,
                {
                    model =
                        model,

                    label =
                        label
                        or model,

                    source =
                        file
                }
            )
        end
    )
end


-- =========================================================
-- LOCATIONS
-- =========================================================

local function addLocation(result, location)
    if not location.x
        or not location.y
        or not location.z then

        return
    end


    result._locationSeen =
        result._locationSeen or {}


    local key = (
        '%.3f:%.3f:%.3f:%.3f'
    ):format(
        location.x,
        location.y,
        location.z,
        location.w or 0.0
    )


    if result._locationSeen[key] then
        return
    end


    result._locationSeen[key] = true


    result.locations[
        #result.locations + 1
    ] = location
end


local function scanCoords(content, file, result)
    -- =====================================================
    -- vector3(...)
    -- =====================================================

    for x, y, z in content:gmatch(
        "vector3%s*%(%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*%)"
    ) do
        addLocation(
            result,
            {
                x =
                    tonumber(x),

                y =
                    tonumber(y),

                z =
                    tonumber(z),

                w =
                    0.0,

                source =
                    file,

                type =
                    'vector3'
            }
        )
    end


    -- =====================================================
    -- vector4(...)
    -- =====================================================

    for x, y, z, w in content:gmatch(
        "vector4%s*%(%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*%)"
    ) do
        addLocation(
            result,
            {
                x =
                    tonumber(x),

                y =
                    tonumber(y),

                z =
                    tonumber(z),

                w =
                    tonumber(w),

                source =
                    file,

                type =
                    'vector4'
            }
        )
    end


    -- =====================================================
    -- vec3(...)
    -- =====================================================

    for x, y, z in content:gmatch(
        "vec3%s*%(%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*%)"
    ) do
        addLocation(
            result,
            {
                x =
                    tonumber(x),

                y =
                    tonumber(y),

                z =
                    tonumber(z),

                w =
                    0.0,

                source =
                    file,

                type =
                    'vec3'
            }
        )
    end


    -- =====================================================
    -- vec4(...)
    -- =====================================================

    for x, y, z, w in content:gmatch(
        "vec4%s*%(%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*,%s*([%-]?[%d%.]+)%s*%)"
    ) do
        addLocation(
            result,
            {
                x =
                    tonumber(x),

                y =
                    tonumber(y),

                z =
                    tonumber(z),

                w =
                    tonumber(w),

                source =
                    file,

                type =
                    'vec4'
            }
        )
    end


    -- =====================================================
    -- { x = ..., y = ..., z = ... }
    -- =====================================================

    for x, y, z in content:gmatch(
        "[Xx]%s*=%s*([%-]?[%d%.]+)%s*,%s*[Yy]%s*=%s*([%-]?[%d%.]+)%s*,%s*[Zz]%s*=%s*([%-]?[%d%.]+)"
    ) do
        addLocation(
            result,
            {
                x =
                    tonumber(x),

                y =
                    tonumber(y),

                z =
                    tonumber(z),

                w =
                    0.0,

                source =
                    file,

                type =
                    'table'
            }
        )
    end
end


-- =========================================================
-- BLIPS
-- =========================================================

local function addBlip(result, blip)
    result._blipSeen =
        result._blipSeen or {}

    local key = (
        '%s:%s:%s:%s'
    ):format(
        tostring(blip.sprite),
        tostring(blip.colour),
        tostring(blip.scale),
        tostring(blip.source)
    )

    if result._blipSeen[key] then
        return
    end

    result._blipSeen[key] = true

    result.blips[
        #result.blips + 1
    ] = blip
end


local function scanBlips(content, file, result)
    scanSimpleBlocks(
        content,
        function(block)
            local sprite =
                block:match(
                    "[Ss][Pp][Rr][Ii][Tt][Ee]%s*=%s*([%d]+)"
                )

            if not sprite then
                return
            end


            local colour =
                block:match(
                    "[Cc][Oo][Ll][Oo][Uu][Rr]%s*=%s*([%d]+)"
                )
                or block:match(
                    "[Cc][Oo][Ll][Oo][Rr]%s*=%s*([%d]+)"
                )


            local scale =
                block:match(
                    "[Ss][Cc][Aa][Ll][Ee]%s*=%s*([%d%.]+)"
                )


            addBlip(
                result,
                {
                    sprite =
                        safeNumber(
                            sprite,
                            1
                        ),

                    colour =
                        safeNumber(
                            colour,
                            3
                        ),

                    scale =
                        safeNumber(
                            scale,
                            0.65
                        ),

                    source =
                        file
                }
            )
        end
    )
end


-- =========================================================
-- BUILD IMPORT SUGGESTIONS
-- =========================================================

local function buildSuggestions(scan)
    local suggestions = {}


    -- =====================================================
    -- SHOP
    -- =====================================================

    if #scan.items > 0 then
        local items = {}

        for _, item in ipairs(scan.items) do
            items[#items + 1] = {
                name =
                    item.name,

                label =
                    item.label,

                price =
                    item.price
            }
        end


        suggestions[
            #suggestions + 1
        ] = {
            type =
                'shop',

            label =
                'Geïmporteerde shop',

            description =
                ('%s item(s) gevonden'):format(
                    #items
                ),

            settings = {
                account =
                    'bank',

                items =
                    items
            },

            confidence =
                'medium'
        }
    end


    -- =====================================================
    -- CRAFTING
    -- =====================================================

    if #scan.recipes > 0 then
        suggestions[
            #suggestions + 1
        ] = {
            type =
                'crafting',

            label =
                'Geïmporteerde crafting',

            description =
                ('%s recept(en) gevonden'):format(
                    #scan.recipes
                ),

            settings = {
                recipes =
                    scan.recipes
            },

            confidence =
                'medium'
        }
    end


    -- =====================================================
    -- HARVEST
    -- =====================================================

    for _, harvest in ipairs(scan.harvest) do
        suggestions[
            #suggestions + 1
        ] = {
            type =
                'harvest',

            label =
                harvest.label,

            description =
                ('%sx %s'):format(
                    harvest.count,
                    harvest.item
                ),

            settings = {
                item =
                    harvest.item,

                count =
                    harvest.count,

                duration =
                    harvest.duration
            },

            source =
                harvest.source,

            confidence =
                harvest.confidence
        }
    end


    -- =====================================================
    -- PROCESS
    -- =====================================================

    for _, process in ipairs(scan.processes) do
        suggestions[
            #suggestions + 1
        ] = {
            type =
                'process',

            label =
                process.label,

            description =
                ('%sx %s → %sx %s'):format(
                    process.input.count,
                    process.input.item,
                    process.output.count,
                    process.output.item
                ),

            settings = {
                input =
                    process.input,

                output =
                    process.output,

                duration =
                    process.duration
            },

            source =
                process.source,

            confidence =
                process.confidence
        }
    end


    -- =====================================================
    -- STASH / ARMORY
    -- =====================================================

    for _, stash in ipairs(scan.stashes) do
        suggestions[
            #suggestions + 1
        ] = {
            type =
                stash.type,

            label =
                stash.label,

            description =
                ('%s slots / %s gewicht'):format(
                    stash.settings.slots,
                    stash.settings.weight
                ),

            settings =
                stash.settings,

            source =
                stash.source,

            confidence =
                stash.confidence
        }
    end


    -- =====================================================
    -- GARAGE
    -- =====================================================

    if #scan.vehicles > 0 then
        local vehicles = {}

        for _, vehicle in ipairs(scan.vehicles) do
            vehicles[
                #vehicles + 1
            ] = {
                model =
                    vehicle.model,

                label =
                    vehicle.label
            }
        end


        suggestions[
            #suggestions + 1
        ] = {
            type =
                'garage',

            label =
                'Geïmporteerde garage',

            description =
                ('%s voertuig(en) gevonden'):format(
                    #vehicles
                ),

            settings = {
                vehicles =
                    vehicles
            },

            confidence =
                'medium'
        }
    end


    return suggestions
end


-- =========================================================
-- PUBLIC SCAN
-- =========================================================

function RSJobScanner.Scan(resource)
    if not validResourceName(resource) then
        return nil,
            'Ongeldige resource.'
    end


    local resourceState =
        GetResourceState(resource)


    if resourceState == 'missing'
        or resourceState == 'unknown' then

        return nil,
            ('Resource "%s" bestaat niet.'):format(
                resource
            )
    end


    scannerDebug(
        '========================================'
    )

    scannerDebug(
        ('SCAN START: %s [%s]'):format(
            resource,
            resourceState
        )
    )


    local files =
        collectFiles(resource)


    if #files == 0 then
        scannerDebug(
            'Geen leesbare Lua-bestanden gevonden.'
        )

        scannerDebug(
            '========================================'
        )

        return nil,
            'Geen leesbare Lua-bestanden gevonden. Controleer het fxmanifest of de bestandsstructuur.'
    end


    local result = {
        resource =
            resource,

        state =
            resourceState,

        files =
            files,

        items =
            {},

        recipes =
            {},

        processes =
            {},

        harvest =
            {},

        stashes =
            {},

        vehicles =
            {},

        locations =
            {},

        blips =
            {}
    }


    -- =====================================================
    -- SCAN EVERY FILE
    -- =====================================================

    for _, file in ipairs(files) do
        local content =
            readFile(
                resource,
                file
            )


        if content then
            scannerDebug(
                ('Scannen: %s'):format(
                    file
                )
            )


            scanItems(
                content,
                file,
                result
            )


            scanRecipes(
                content,
                file,
                result
            )


            scanProcesses(
                content,
                file,
                result
            )


            scanHarvest(
                content,
                file,
                result
            )


            scanStashes(
                content,
                file,
                result
            )


            scanVehicles(
                content,
                file,
                result
            )


            scanCoords(
                content,
                file,
                result
            )


            scanBlips(
                content,
                file,
                result
            )
        end
    end


    -- =====================================================
    -- CLEAN TEMP DATA
    -- =====================================================

    result._itemSeen =
        nil

    result._recipeSeen =
        nil

    result._processSeen =
        nil

    result._harvestSeen =
        nil

    result._stashSeen =
        nil

    result._vehicleSeen =
        nil

    result._locationSeen =
        nil

    result._blipSeen =
        nil


    -- =====================================================
    -- BUILD SUGGESTIONS
    -- =====================================================

    result.suggestions =
        buildSuggestions(
            result
        )


    -- =====================================================
    -- SUMMARY
    -- =====================================================

    result.summary = {
        files =
            #result.files,

        items =
            #result.items,

        recipes =
            #result.recipes,

        processes =
            #result.processes,

        harvest =
            #result.harvest,

        stashes =
            #result.stashes,

        vehicles =
            #result.vehicles,

        locations =
            #result.locations,

        blips =
            #result.blips,

        suggestions =
            #result.suggestions
    }


    scannerDebug(
        ('Items: %s'):format(
            #result.items
        )
    )

    scannerDebug(
        ('Recipes: %s'):format(
            #result.recipes
        )
    )

    scannerDebug(
        ('Processes: %s'):format(
            #result.processes
        )
    )

    scannerDebug(
        ('Harvest: %s'):format(
            #result.harvest
        )
    )

    scannerDebug(
        ('Stashes: %s'):format(
            #result.stashes
        )
    )

    scannerDebug(
        ('Vehicles: %s'):format(
            #result.vehicles
        )
    )

    scannerDebug(
        ('Locations: %s'):format(
            #result.locations
        )
    )

    scannerDebug(
        ('Blips: %s'):format(
            #result.blips
        )
    )

    scannerDebug(
        ('Suggestions: %s'):format(
            #result.suggestions
        )
    )

    scannerDebug(
        ('SCAN KLAAR: %s'):format(
            resource
        )
    )

    scannerDebug(
        '========================================'
    )


    return result
end


-- =========================================================
-- RESOURCE LIST
-- =========================================================

function RSJobScanner.GetResources(prefix)
    prefix =
        tostring(
            prefix or 'rs-'
        )


    local resources = {}

    local count =
        GetNumResources()


    for index = 0, count - 1 do
        local resource =
            GetResourceByFindIndex(
                index
            )


        if resource then
            local allowed =
                prefix == ''
                or resource:sub(
                    1,
                    #prefix
                ) == prefix


            if allowed then
                resources[
                    #resources + 1
                ] = {
                    name =
                        resource,

                    state =
                        GetResourceState(
                            resource
                        )
                }
            end
        end
    end


    table.sort(
        resources,
        function(a, b)
            return a.name:lower()
                < b.name:lower()
        end
    )


    return resources
end


-- =========================================================
-- OPTIONAL EXPORTS
-- =========================================================

exports(
    'ScanJobResource',
    function(resource)
        return RSJobScanner.Scan(
            resource
        )
    end
)


exports(
    'GetJobResources',
    function(prefix)
        return RSJobScanner.GetResources(
            prefix
        )
    end
)


scannerDebug(
    ('Scanner geladen in %s.'):format(
        RESOURCE
    )
)