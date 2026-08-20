Config = {}

Config.Debug = false
Config.OpenCommand = 'jobscreator'
Config.OpenKey = 'F10'

Config.AdminAce = 'rsjobscreator.admin'
Config.AdminGroups = {
    admin = true,
    superadmin = true,
}

-- Discord webhook logging. Laat leeg om webhooklogging uit te schakelen.
Config.WebhookUrl = ''
Config.WebhookName = 'RS Jobs Creator'

Config.MaxLogs = 100
Config.PointDrawDistance = 25.0
Config.InteractDistance = 2.0
Config.ServerDistanceBuffer = 3.0
Config.Marker = {
    type = 2,
    scale = vec3(0.22, 0.22, 0.22),
    colour = { r = 76, g = 124, b = 255, a = 180 },
}

-- Do not change the jobs table schema automatically.
-- rs-jobscreator detects optional columns at runtime.
Config.JobColumns = {
    whitelisted = 'whitelisted',
    enabled = 'enabled',
}

Config.DefaultPointSettings = {
    requireDuty = true,
    icon = 'fa-solid fa-briefcase',
}


Config.PointTypes = {
    duty = 'Dienst',
    bossmenu = 'Baasmenu',

    shop = 'Winkel',
    jobshop = 'Jobwinkel',
    market = 'Markt',

    crafting = 'Crafting',
    harvest = 'Verzamelen',
    process = 'Verwerken',

    stash = 'Opslag',
    armory = 'Wapenkamer',

    garage = 'Garage',
    teleport = 'Teleport'
}

Config.Examples = {
    stash = { requireDuty = true, icon = 'fa-solid fa-box-open', slots = 80, weight = 250000 },
    armory = { requireDuty = true, icon = 'fa-solid fa-shield-halved', slots = 80, weight = 250000 },
    shop = { requireDuty = true, icon = 'fa-solid fa-cart-shopping', items = {
        { name = 'water', label = 'Water', price = 5 },
        { name = 'bread', label = 'Brood', price = 5 },
    } },
    jobshop = { requireDuty = true, icon = 'fa-solid fa-toolbox', items = {
        { name = 'repairkit', label = 'Reparatieset', price = 250 },
    } },
    market = { requireDuty = false, icon = 'fa-solid fa-store', account = 'bank', items = {
        { name = 'water', label = 'Water', price = 5 },
    } },
    crafting = { requireDuty = true, icon = 'fa-solid fa-hammer', recipes = {
        { label = 'Reparatieset', result = 'repairkit', count = 1, duration = 5000, ingredients = { iron = 2, plastic = 1 } },
    } },
    harvest = { requireDuty = true, icon = 'fa-solid fa-tree', item = 'wood', count = 1, duration = 3500, tool = '' },
    process = { requireDuty = true, icon = 'fa-solid fa-gears', input = { item = 'wood', count = 2 }, output = { item = 'plank', count = 1 }, duration = 5000 },
    garage = { requireDuty = true, icon = 'fa-solid fa-car', vehicles = { { model = 'speedo', label = 'Werkbus' } } },
    teleport = { requireDuty = false, icon = 'fa-solid fa-location-arrow', destination = { x = 0, y = 0, z = 0, w = 0 }, allowVehicle = false },
    duty = { requireDuty = false, icon = 'fa-solid fa-user-clock' },
}
