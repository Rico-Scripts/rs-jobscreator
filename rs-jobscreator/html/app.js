const $ = (selector) =>
    document.querySelector(selector);

const $$ = (selector) =>
    document.querySelectorAll(selector);

const app = $('#app');


/* =========================================================
   STATE
========================================================= */

let state = {
    jobs: [],
    grades: [],
    points: [],
    logs: [],
    pointTypes: {},
    examples: {}
};

let builderBaseSettings = {};

let importScan = null;
let importedCoords = null;

let inventoryItems = [];

let importResourcesLoaded = false;
let inventoryItemsLoaded = false;


/* =========================================================
   NUI REQUESTS
========================================================= */

async function post(name, data = {}) {
    try {
        const response = await fetch(
            `https://${GetParentResourceName()}/${name}`,
            {
                method: 'POST',

                headers: {
                    'Content-Type':
                        'application/json'
                },

                body:
                    JSON.stringify(data)
            }
        );

        const text =
            await response.text();

        if (!text) {
            return {};
        }

        return JSON.parse(text);
    } catch (error) {
        console.error(
            `[rs-jobscreator] ${name}`,
            error
        );

        return {
            success: false,
            message:
                'Verbinding met de gameclient mislukt.'
        };
    }
}


/* =========================================================
   HELPERS
========================================================= */

function safe(value) {
    const element =
        document.createElement(
            'span'
        );

    element.textContent =
        value ?? '';

    return element.innerHTML;
}


function numeric(
    selector,
    fallback = 0
) {
    const element =
        $(selector);

    if (!element) {
        return fallback;
    }

    const value =
        Number(
            element.value
        );

    return Number.isFinite(value)
        ? value
        : fallback;
}


function clone(value) {
    try {
        return JSON.parse(
            JSON.stringify(
                value || {}
            )
        );
    } catch {
        return {};
    }
}


function notice(
    message,
    ok = true
) {
    const host =
        $('#notice');

    if (!host) {
        return;
    }

    host.innerHTML = `
        <span class="${ok ? '' : 'bad'}">
            ${safe(message || '')}
        </span>
    `;

    setTimeout(
        () => {
            host.innerHTML = '';
        },
        3500
    );
}


/* =========================================================
   PED / PROP MODEL LISTS
========================================================= */

const pedModels = [
    {
        model: 's_m_m_autoshop_01',
        label: 'Monteur'
    },
    {
        model: 's_m_y_xmech_01',
        label: 'Monteur 2'
    },
    {
        model: 's_m_y_xmech_02',
        label: 'Monteur 3'
    },

    {
        model: 's_m_y_cop_01',
        label: 'Politieagent'
    },
    {
        model: 's_f_y_cop_01',
        label: 'Politieagent vrouw'
    },
    {
        model: 's_m_y_sheriff_01',
        label: 'Sheriff'
    },
    {
        model: 's_f_y_sheriff_01',
        label: 'Sheriff vrouw'
    },

    {
        model: 's_m_m_paramedic_01',
        label: 'Ambulancemedewerker'
    },
    {
        model: 's_m_m_doctor_01',
        label: 'Dokter'
    },

    {
        model: 's_m_m_security_01',
        label: 'Beveiliger'
    },
    {
        model: 's_m_m_highsec_01',
        label: 'High Security'
    },
    {
        model: 's_m_m_highsec_02',
        label: 'High Security 2'
    },
    {
        model: 's_m_m_bouncer_01',
        label: 'Uitsmijter'
    },

    {
        model: 's_m_y_dealer_01',
        label: 'Dealer'
    },

    {
        model: 'mp_m_shopkeep_01',
        label: 'Winkelier'
    },
    {
        model: 's_f_y_shop_mid',
        label: 'Winkelmedewerker vrouw'
    },

    {
        model: 'a_m_m_business_01',
        label: 'Zakenman'
    },
    {
        model: 'a_m_y_business_01',
        label: 'Zakenman jong'
    },
    {
        model: 'a_f_y_business_01',
        label: 'Zakenvrouw'
    },
    {
        model: 'a_f_y_business_02',
        label: 'Zakenvrouw 2'
    },

    {
        model: 'a_m_m_farmer_01',
        label: 'Boer'
    },
    {
        model: 's_m_m_gardener_01',
        label: 'Tuinman'
    },

    {
        model: 's_m_m_trucker_01',
        label: 'Vrachtwagenchauffeur'
    },
    {
        model: 's_m_m_pilot_01',
        label: 'Piloot'
    },
    {
        model: 's_m_y_airworker',
        label: 'Luchthavenmedewerker'
    },

    {
        model: 's_m_y_busboy_01',
        label: 'Restaurantmedewerker'
    },
    {
        model: 's_m_m_linecook',
        label: 'Kok'
    },

    {
        model: 'a_m_y_hipster_01',
        label: 'Burger man'
    },
    {
        model: 'a_f_y_hipster_01',
        label: 'Burger vrouw'
    },
    {
        model: 'a_m_y_beach_01',
        label: 'Burger casual man'
    },
    {
        model: 'a_f_y_beach_01',
        label: 'Burger casual vrouw'
    }
];


const propModels = [
    {
        model: 'prop_tool_bench02',
        label: 'Werkbank'
    },
    {
        model: 'prop_tool_bench02_ld',
        label: 'Werkbank klein'
    },

    {
        model: 'prop_tool_chest_01',
        label: 'Gereedschapskist'
    },
    {
        model: 'prop_tool_box_04',
        label: 'Gereedschapsbox'
    },
    {
        model: 'prop_tool_box_05',
        label: 'Gereedschapsbox 2'
    },

    {
        model: 'prop_boxpile_06b',
        label: 'Dozenstapel'
    },
    {
        model: 'prop_box_wood02a_pu',
        label: 'Houten kist'
    },

    {
        model: 'prop_crate_11e',
        label: 'Krat'
    },
    {
        model: 'prop_crate_07a',
        label: 'Grote krat'
    },

    {
        model: 'prop_barrel_02a',
        label: 'Vat'
    },
    {
        model: 'prop_oiltub_06',
        label: 'Olievat'
    },

    {
        model: 'prop_gas_tank_01a',
        label: 'Gastank'
    },

    {
        model: 'prop_generator_03b',
        label: 'Generator'
    },

    {
        model: 'prop_laptop_01a',
        label: 'Laptop'
    },
    {
        model: 'prop_monitor_01c',
        label: 'Monitor'
    },
    {
        model: 'prop_cs_keyboard_01',
        label: 'Toetsenbord'
    },

    {
        model: 'prop_off_chair_04',
        label: 'Bureaustoel'
    },
    {
        model: 'prop_office_desk_01',
        label: 'Bureau'
    },

    {
        model: 'prop_table_03',
        label: 'Tafel'
    },
    {
        model: 'prop_chair_01a',
        label: 'Stoel'
    },

    {
        model: 'prop_bin_01a',
        label: 'Prullenbak'
    },

    {
        model: 'prop_vend_soda_01',
        label: 'Frisdrankautomaat'
    },
    {
        model: 'prop_vend_soda_02',
        label: 'Frisdrankautomaat 2'
    },

    {
        model: 'prop_atm_01',
        label: 'Pinautomaat'
    },

    {
        model: 'prop_cash_register_01',
        label: 'Kassa'
    },

    {
        model: 'prop_ld_int_safe_01',
        label: 'Kluis'
    },

    {
        model: 'prop_fib_clipboard',
        label: 'Klembord'
    },

    {
        model: 'prop_roadcone02a',
        label: 'Verkeerskegel'
    },

    {
        model: 'prop_barrier_work05',
        label: 'Werkbarrière'
    },

    {
        model: 'prop_worklight_03b',
        label: 'Werklamp'
    },

    {
        model: 'prop_engine_hoist',
        label: 'Motortakel'
    },

    {
        model: 'prop_carcreeper',
        label: 'Monteur ligkar'
    }
];


/* =========================================================
   PED / PROP DROPDOWN INITIALISATION
========================================================= */

function createModelDatalist(
    inputSelector,
    listId,
    models,
    placeholder
) {
    const input =
        $(inputSelector);

    if (!input) {
        return;
    }

    let list =
        document.getElementById(
            listId
        );

    if (!list) {
        list =
            document.createElement(
                'datalist'
            );

        list.id =
            listId;

        document.body.appendChild(
            list
        );
    }

    list.innerHTML =
        models
            .map(
                (entry) => `
                    <option
                        value="${safe(entry.model)}"
                        label="${safe(entry.label)}"
                    >
                        ${safe(entry.label)}
                    </option>
                `
            )
            .join('');

    input.setAttribute(
        'list',
        listId
    );

    input.setAttribute(
        'autocomplete',
        'off'
    );

    if (placeholder) {
        input.placeholder =
            placeholder;
    }
}


function initialiseModelDropdowns() {
    createModelDatalist(
        '#settingPedModel',
        'rsPedModels',
        pedModels,
        'Selecteer NPC of typ een custom model'
    );

    createModelDatalist(
        '#settingObjectModel',
        'rsPropModels',
        propModels,
        'Selecteer prop of typ een custom model'
    );
}


/* =========================================================
   VIEW SWITCHING
========================================================= */

function setView(name) {
    $$('nav button')
        .forEach(
            (button) => {
                button.classList.toggle(
                    'active',
                    button.dataset.view === name
                );
            }
        );

    $$('.view')
        .forEach(
            (view) => {
                view.classList.remove(
                    'active'
                );
            }
        );

    const target =
        $(`#${name}View`);

    if (target) {
        target.classList.add(
            'active'
        );
    }

    const labels = {
        jobs: [
            'Jobs',
            'Maak en beheer ESX-jobs live.'
        ],

        grades: [
            'Rangen',
            'Beheer hiërarchie, rechten en salarissen.'
        ],

        points: [
            'Interactiepunten',
            'Plaats werkfuncties direct op je huidige positie.'
        ],

        import: [
            'Importeren',
            'Scan bestaande FiveM-resources en zet gevonden onderdelen om naar interactiepunten.'
        ],

        logs: [
            'Logboek',
            'Controleer de laatste beheeracties.'
        ]
    };

    if (labels[name]) {
        const title =
            $('#title');

        const subtitle =
            $('#subtitle');

        if (title) {
            title.textContent =
                labels[name][0];
        }

        if (subtitle) {
            subtitle.textContent =
                labels[name][1];
        }
    }

    if (name === 'import') {
        Promise.all([
            loadInventoryItems(),
            loadImportResources()
        ])
            .then(
                () => loadLastResourceScan()
            );
    }

    if (name === 'points') {
        loadInventoryItems()
            .then(
                () => {
                    if (
                        $('#pointType')
                        && $('#pointType').value
                    ) {
                        renderSettingsBuilder(
                            builderBaseSettings
                        );
                    }

                    initialiseModelDropdowns();
                }
            );
    }
}


/* =========================================================
   OX INVENTORY ITEMS
========================================================= */

async function loadInventoryItems(
    force = false
) {
    if (
        inventoryItemsLoaded
        && !force
    ) {
        return true;
    }

    const result =
        await post(
            'getInventoryItems'
        );

    if (!result.success) {
        console.warn(
            '[rs-jobscreator] ox_inventory items:',
            result.message
        );

        return false;
    }

    inventoryItems =
        Array.isArray(
            result.items
        )
            ? result.items
            : [];

    inventoryItemsLoaded =
        true;

    console.log(
        `[rs-jobscreator] ${inventoryItems.length} inventory items geladen.`
    );

    return true;
}


function getInventoryItem(name) {
    return inventoryItems.find(
        (item) =>
            item.name === name
    );
}


function itemSelectOptions(
    selected = '',
    allowEmpty = true
) {
    const current =
        String(
            selected || ''
        );

    let html =
        allowEmpty
            ? `
                <option value="">
                    Selecteer item...
                </option>
            `
            : '';

    if (
        current
        && !inventoryItems.some(
            (item) =>
                item.name === current
        )
    ) {
        html += `
            <option
                value="${safe(current)}"
                selected
            >
                ${safe(current)}
                (niet gevonden)
            </option>
        `;
    }

    for (const item of inventoryItems) {
        const name =
            String(
                item.name || ''
            );

        const label =
            String(
                item.label
                || name
            );

        html += `
            <option
                value="${safe(name)}"
                ${
                    name === current
                        ? 'selected'
                        : ''
                }
            >
                ${safe(label)}
                (${safe(name)})
            </option>
        `;
    }

    return html;
}


/* =========================================================
   RESOURCE IMPORTER
========================================================= */

async function loadImportResources(
    force = false
) {
    if (
        importResourcesLoaded
        && !force
    ) {
        return true;
    }

    const select =
        $('#importResource');

    if (!select) {
        return false;
    }

    const previous =
        select.value;

    select.innerHTML = `
        <option value="">
            Resources laden...
        </option>
    `;

    const result =
        await post(
            'getImportResources'
        );

    if (!result.success) {
        select.innerHTML = `
            <option value="">
                Laden mislukt
            </option>
        `;

        notice(
            result.message
            || 'Resources konden niet worden geladen.',
            false
        );

        return false;
    }

    const resources =
        Array.isArray(
            result.resources
        )
            ? result.resources
            : [];

    select.innerHTML = `
        <option value="">
            Selecteer resource...
        </option>

        ${
            resources
                .map(
                    (resource) => `
                        <option
                            value="${safe(resource.name)}"
                        >
                            ${safe(resource.name)}
                            [${safe(resource.state)}]
                        </option>
                    `
                )
                .join('')
        }
    `;

    if (
        previous
        && resources.some(
            (resource) =>
                resource.name === previous
        )
    ) {
        select.value =
            previous;
    }

    importResourcesLoaded =
        true;

    return true;
}


async function loadLastResourceScan() {
    const result =
        await post(
            'getLastResourceScan'
        );

    if (!result.success) {
        return;
    }

    if (!result.scan) {
        return;
    }

    importScan =
        result.scan;

    const select =
        $('#importResource');

    if (
        select
        && result.resource
    ) {
        select.value =
            result.resource;
    }

    renderImportScan();
}


function confidenceLabel(value) {
    if (value === 'high') {
        return 'Hoge zekerheid';
    }

    if (value === 'medium') {
        return 'Controle aanbevolen';
    }

    return 'Suggestie';
}


function renderImportScan() {
    const host =
        $('#importSuggestions');

    if (!host) {
        return;
    }

    if (!importScan) {
        host.innerHTML = `
            <div class="empty">
                Selecteer een resource en start een scan.
            </div>
        `;

        const summary =
            $('#importSummary');

        if (summary) {
            summary.innerHTML = '';
        }

        return;
    }

    const suggestions =
        Array.isArray(
            importScan.suggestions
        )
            ? importScan.suggestions
            : [];

    const summary =
        $('#importSummary');

    if (summary) {
        summary.innerHTML = `
            <div class="import-stats">

                <span>
                    ${
                        importScan.files?.length
                        || 0
                    }
                    bestanden
                </span>

                <span>
                    ${
                        importScan.items?.length
                        || 0
                    }
                    items
                </span>

                <span>
                    ${
                        importScan.recipes?.length
                        || 0
                    }
                    recepten
                </span>

                <span>
                    ${
                        importScan.processes?.length
                        || 0
                    }
                    processen
                </span>

                <span>
                    ${
                        importScan.harvest?.length
                        || 0
                    }
                    harvest
                </span>

                <span>
                    ${
                        importScan.stashes?.length
                        || 0
                    }
                    opslag
                </span>

                <span>
                    ${
                        importScan.vehicles?.length
                        || 0
                    }
                    voertuigen
                </span>

                <span>
                    ${
                        importScan.locations?.length
                        || 0
                    }
                    locaties
                </span>

                <span>
                    ${
                        importScan.blips?.length
                        || 0
                    }
                    blips
                </span>

                <span>
                    ${suggestions.length}
                    suggesties
                </span>

            </div>
        `;
    }

    if (!suggestions.length) {
        host.innerHTML = `
            <div class="empty">
                De resource is gescand, maar er zijn geen
                bruikbare interactiepunten gevonden.
            </div>
        `;

        return;
    }

    host.innerHTML =
        suggestions
            .map(
                (suggestion, index) => `
                    <article class="import-card">

                        <div class="import-card-head">

                            <div>

                                <span class="badge">
                                    ${safe(
                                        state.pointTypes?.[
                                            suggestion.type
                                        ]
                                        || suggestion.type
                                    )}
                                </span>

                                <h3>
                                    ${safe(
                                        suggestion.label
                                        || suggestion.type
                                    )}
                                </h3>

                            </div>

                            <span class="muted">
                                ${safe(
                                    confidenceLabel(
                                        suggestion.confidence
                                    )
                                )}
                            </span>

                        </div>

                        ${
                            suggestion.description
                                ? `
                                    <p>
                                        ${safe(
                                            suggestion.description
                                        )}
                                    </p>
                                `
                                : ''
                        }

                        ${
                            suggestion.source
                                ? `
                                    <small class="muted">
                                        Bron:
                                        ${safe(
                                            suggestion.source
                                        )}
                                    </small>
                                `
                                : ''
                        }

                        <button
                            type="button"
                            class="primary import-use"
                            data-import-index="${index}"
                        >
                            Naar interactiepunt
                        </button>

                    </article>
                `
            )
            .join('');

    $$('[data-import-index]')
        .forEach(
            (button) => {
                button.onclick =
                    () => {
                        useImportSuggestion(
                            Number(
                                button.dataset.importIndex
                            )
                        );
                    };
            }
        );
}


async function useImportSuggestion(index) {
    if (!importScan) {
        return;
    }

    const suggestion =
        importScan.suggestions?.[
            index
        ];

    if (!suggestion) {
        return;
    }

    await loadInventoryItems();

    setView(
        'points'
    );

    resetPoint();

    if (
        $('#pointType')
        && state.pointTypes[
            suggestion.type
        ]
    ) {
        $('#pointType').value =
            suggestion.type;
    }

    const pointLabel =
        $('#pointLabel');

    if (pointLabel) {
        pointLabel.value =
            suggestion.label
            || suggestion.type;

        pointLabel.dataset.autoLabel =
            'false';
    }

    const importedSettings =
        clone(
            suggestion.settings
            || {}
        );

    if (
        Array.isArray(
            importedSettings.items
        )
    ) {
        importedSettings.items =
            importedSettings.items.map(
                (item) => {
                    const inventoryItem =
                        getInventoryItem(
                            item.name
                        );

                    return {
                        ...item,

                        label:
                            inventoryItem?.label
                            || item.label
                            || item.name
                    };
                }
            );
    }

    renderSettingsBuilder(
        importedSettings
    );

    if (
        Array.isArray(
            importScan.locations
        )
        && importScan.locations.length
            === 1
    ) {
        importedCoords =
            clone(
                importScan.locations[0]
            );
    } else {
        importedCoords =
            null;
    }

    notice(
        importedCoords
            ? 'Suggestie geladen inclusief gevonden locatie.'
            : 'Suggestie geladen. Plaats het punt op je huidige positie.',
        true
    );
}


/* =========================================================
   JOBS
========================================================= */

function jobOptions(
    selected = ''
) {
    return state.jobs
        .map(
            (job) => `
                <option
                    value="${safe(job.name)}"
                    ${
                        job.name === selected
                            ? 'selected'
                            : ''
                    }
                >
                    ${safe(job.label)}
                    (${safe(job.name)})
                </option>
            `
        )
        .join('');
}


function resetJob() {
    $('#jobOriginal').value =
        '';

    $('#jobName').value =
        '';

    $('#jobLabel').value =
        '';

    $('#jobWhitelist').checked =
        false;

    $('#jobEnabled').checked =
        true;
}


function editJob(job) {
    if (!job) {
        return;
    }

    $('#jobOriginal').value =
        job.name || '';

    $('#jobName').value =
        job.name || '';

    $('#jobLabel').value =
        job.label || '';

    $('#jobWhitelist').checked =
        Number(
            job.whitelisted
        ) === 1;

    $('#jobEnabled').checked =
        Number(
            job.enabled
        ) === 1;
}


/* =========================================================
   GRADES
========================================================= */

function resetGrade() {
    $('#gradeNumber').value =
        '';

    $('#gradeName').value =
        '';

    $('#gradeLabel').value =
        '';

    $('#gradeSalary').value =
        0;

    $('#gradeBoss').checked =
        false;
}


function editGrade(grade) {
    if (!grade) {
        return;
    }

    $('#gradeJob').value =
        grade.job_name || '';

    $('#gradeNumber').value =
        grade.grade ?? '';

    $('#gradeName').value =
        grade.name || '';

    $('#gradeLabel').value =
        grade.label || '';

    $('#gradeSalary').value =
        grade.salary ?? 0;

    $('#gradeBoss').checked =
        grade.name === 'boss';
}


/* =========================================================
   COMMON POINT SETTINGS
========================================================= */

function toggleCommonFields() {
    const blipFields =
        $('#blipFields');

    const pedField =
        $('#pedField');

    const objectField =
        $('#objectField');

    if (blipFields) {
        blipFields.classList.toggle(
            'hidden',
            !$('#settingBlip')?.checked
        );
    }

    if (pedField) {
        pedField.classList.toggle(
            'hidden',
            !$('#settingPed')?.checked
        );
    }

    if (objectField) {
        objectField.classList.toggle(
            'hidden',
            !$('#settingObject')?.checked
        );
    }
}


/* =========================================================
   SHOP ITEM ROW
========================================================= */

function addItemRow(
    item = {}
) {
    const host =
        $('#itemRows');

    if (!host) {
        return;
    }

    const inventoryItem =
        getInventoryItem(
            item.name
        );

    const row =
        document.createElement(
            'div'
        );

    row.className =
        'repeat-row item-setting-row';

    row.innerHTML = `
        <label>
            Item

            <select class="item-name">
                ${itemSelectOptions(
                    item.name
                )}
            </select>
        </label>

        <label>
            Label

            <input
                class="item-label"
                value="${safe(
                    item.label
                    || inventoryItem?.label
                    || ''
                )}"
                placeholder="Productlabel"
            >
        </label>

        <label>
            Prijs

            <input
                class="item-price"
                type="number"
                min="0"
                value="${
                    Number(
                        item.price
                    )
                    || 0
                }"
            >
        </label>

        <button
            type="button"
            class="danger remove-row"
        >
            ×
        </button>
    `;

    const select =
        row.querySelector(
            '.item-name'
        );

    const labelInput =
        row.querySelector(
            '.item-label'
        );

    select.onchange =
        () => {
            const selected =
                getInventoryItem(
                    select.value
                );

            if (selected) {
                labelInput.value =
                    selected.label
                    || selected.name;
            }
        };

    row.querySelector(
        '.remove-row'
    ).onclick =
        () => row.remove();

    host.appendChild(
        row
    );
}


/* =========================================================
   CRAFTING INGREDIENT ROWS
========================================================= */

function ingredientsToArray(
    ingredients = {}
) {
    if (
        !ingredients
        || typeof ingredients
        !== 'object'
    ) {
        return [];
    }

    return Object
        .entries(
            ingredients
        )
        .map(
            ([name, count]) => ({
                name,

                count:
                    Number(
                        count
                    )
                    || 1
            })
        );
}


function addIngredientRow(
    host,
    ingredient = {}
) {
    if (!host) {
        return;
    }

    const row =
        document.createElement(
            'div'
        );

    row.className =
        'ingredient-setting-row repeat-row';

    row.innerHTML = `
        <label>
            Item

            <select class="ingredient-name">
                ${itemSelectOptions(
                    ingredient.name
                )}
            </select>
        </label>

        <label>
            Aantal

            <input
                class="ingredient-count"
                type="number"
                min="1"
                value="${
                    Number(
                        ingredient.count
                    )
                    || 1
                }"
            >
        </label>

        <button
            type="button"
            class="danger remove-ingredient"
        >
            ×
        </button>
    `;

    row.querySelector(
        '.remove-ingredient'
    ).onclick =
        () => row.remove();

    host.appendChild(
        row
    );
}


/* =========================================================
   RECIPE ROW
========================================================= */

function addRecipeRow(
    recipe = {}
) {
    const host =
        $('#recipeRows');

    if (!host) {
        return;
    }

    const row =
        document.createElement(
            'div'
        );

    row.className =
        'recipe-setting-row recipe-card';

    row.innerHTML = `
        <div class="repeat-row">

            <label>
                Label

                <input
                    class="recipe-label"
                    value="${safe(
                        recipe.label
                        || ''
                    )}"
                    placeholder="Reparatieset"
                >
            </label>

            <label>
                Resultaat

                <select class="recipe-result">
                    ${itemSelectOptions(
                        recipe.result
                    )}
                </select>
            </label>

            <label>
                Aantal

                <input
                    class="recipe-count"
                    type="number"
                    min="1"
                    value="${
                        Number(
                            recipe.count
                        )
                        || 1
                    }"
                >
            </label>

            <label>
                Tijd (ms)

                <input
                    class="recipe-duration"
                    type="number"
                    min="500"
                    value="${
                        Number(
                            recipe.duration
                        )
                        || 5000
                    }"
                >
            </label>

            <button
                type="button"
                class="danger remove-recipe"
            >
                ×
            </button>

        </div>

        <div class="recipe-ingredients-wrap">

            <p class="type-title">
                Benodigdheden
            </p>

            <div class="ingredient-rows"></div>

            <button
                type="button"
                class="small-button add-ingredient"
            >
                + Benodigd item
            </button>

        </div>
    `;

    const ingredientHost =
        row.querySelector(
            '.ingredient-rows'
        );

    const ingredients =
        ingredientsToArray(
            recipe.ingredients
        );

    if (ingredients.length) {
        ingredients.forEach(
            (ingredient) => {
                addIngredientRow(
                    ingredientHost,
                    ingredient
                );
            }
        );
    } else {
        addIngredientRow(
            ingredientHost
        );
    }

    row.querySelector(
        '.add-ingredient'
    ).onclick =
        () => {
            addIngredientRow(
                ingredientHost
            );
        };

    row.querySelector(
        '.remove-recipe'
    ).onclick =
        () => row.remove();

    host.appendChild(
        row
    );
}


/* =========================================================
   VEHICLES
========================================================= */

function addVehicleRow(
    vehicle = {}
) {
    const host =
        $('#vehicleRows');

    if (!host) {
        return;
    }

    const row =
        document.createElement(
            'div'
        );

    row.className =
        'repeat-row vehicle vehicle-setting-row';

    row.innerHTML = `
        <label>
            Spawnmodel

            <input
                class="vehicle-model"
                value="${safe(
                    vehicle.model
                    || ''
                )}"
                placeholder="speedo"
            >
        </label>

        <label>
            Label

            <input
                class="vehicle-label"
                value="${safe(
                    vehicle.label
                    || ''
                )}"
                placeholder="Werkbus"
            >
        </label>

        <button
            type="button"
            class="danger remove-row"
        >
            ×
        </button>
    `;

    row.querySelector(
        '.remove-row'
    ).onclick =
        () => row.remove();

    host.appendChild(
        row
    );
}


/* =========================================================
   TYPE SETTINGS
========================================================= */

function renderTypeFields(
    type,
    settings = {}
) {
    const host =
        $('#typeSettings');

    if (!host) {
        return;
    }

    host.innerHTML =
        '';


    /* -----------------------------------------------------
       DUTY
    ----------------------------------------------------- */

    if (type === 'duty') {
        host.innerHTML = `
            <p class="muted">
                Dit punt schakelt de speler in of uit dienst via rs-duty.
            </p>
        `;

        return;
    }


    /* -----------------------------------------------------
       BOSS MENU
    ----------------------------------------------------- */

    if (type === 'bossmenu') {
        host.innerHTML = `
            <p class="muted">
                Dit punt opent rs-bossmenu.
                Alleen een boss-rang krijgt toegang.
            </p>
        `;

        return;
    }


    /* -----------------------------------------------------
       STASH / ARMORY
    ----------------------------------------------------- */

    if (
        type === 'stash'
        || type === 'armory'
    ) {
        host.innerHTML = `
            <p class="type-title">
                Opslaginstellingen
            </p>

            <div class="grid2">

                <label>
                    Aantal vakken

                    <input
                        id="settingSlots"
                        type="number"
                        min="1"
                        value="${
                            Number(
                                settings.slots
                            )
                            || 80
                        }"
                    >
                </label>

                <label>
                    Maximaal gewicht

                    <input
                        id="settingWeight"
                        type="number"
                        min="1000"
                        value="${
                            Number(
                                settings.weight
                            )
                            || 250000
                        }"
                    >
                </label>

            </div>
        `;

        return;
    }


    /* -----------------------------------------------------
       SHOP
    ----------------------------------------------------- */

    if (
        type === 'shop'
        || type === 'jobshop'
        || type === 'market'
    ) {
        host.innerHTML = `
            <p class="type-title">
                Producten
            </p>

            <div
                id="itemRows"
                class="repeat-list"
            ></div>

            <button
                id="addItem"
                type="button"
                class="small-button"
            >
                + Product toevoegen
            </button>

            <label class="check">

                <input
                    id="settingShopCash"
                    type="checkbox"
                >

                Contant betalen

            </label>
        `;

        const items =
            Array.isArray(
                settings.items
            )
                ? settings.items
                : [];

        if (items.length) {
            items.forEach(
                addItemRow
            );
        } else {
            addItemRow();
        }

        $('#addItem').onclick =
            () => addItemRow();

        $('#settingShopCash').checked =
            settings.account
            === 'money';

        return;
    }


    /* -----------------------------------------------------
       CRAFTING
    ----------------------------------------------------- */

    if (type === 'crafting') {
        host.innerHTML = `
            <p class="type-title">
                Recepten
            </p>

            <div
                id="recipeRows"
                class="repeat-list"
            ></div>

            <button
                id="addRecipe"
                type="button"
                class="small-button"
            >
                + Recept toevoegen
            </button>
        `;

        const recipes =
            Array.isArray(
                settings.recipes
            )
                ? settings.recipes
                : [];

        if (recipes.length) {
            recipes.forEach(
                addRecipeRow
            );
        } else {
            addRecipeRow();
        }

        $('#addRecipe').onclick =
            () => addRecipeRow();

        return;
    }


    /* -----------------------------------------------------
       HARVEST
    ----------------------------------------------------- */

    if (type === 'harvest') {
        host.innerHTML = `
            <p class="type-title">
                Verzamelen
            </p>

            <div class="grid2">

                <label>
                    Ontvangen item

                    <select id="settingHarvestItem">
                        ${itemSelectOptions(
                            settings.item
                        )}
                    </select>
                </label>

                <label>
                    Aantal

                    <input
                        id="settingHarvestCount"
                        type="number"
                        min="1"
                        value="${
                            Number(
                                settings.count
                            )
                            || 1
                        }"
                    >
                </label>

                <label>
                    Tijd (ms)

                    <input
                        id="settingHarvestDuration"
                        type="number"
                        min="500"
                        value="${
                            Number(
                                settings.duration
                            )
                            || 3500
                        }"
                    >
                </label>

                <label>
                    Benodigd gereedschap

                    <select id="settingHarvestTool">

                        <option value="">
                            Geen gereedschap
                        </option>

                        ${itemSelectOptions(
                            settings.tool,
                            false
                        )}

                    </select>
                </label>

            </div>
        `;

        return;
    }


    /* -----------------------------------------------------
       PROCESS
    ----------------------------------------------------- */

    if (type === 'process') {
        host.innerHTML = `
            <p class="type-title">
                Verwerken
            </p>

            <div class="grid2">

                <label>
                    Inleveritem

                    <select id="settingInputItem">
                        ${itemSelectOptions(
                            settings.input?.item
                        )}
                    </select>
                </label>

                <label>
                    Inleveraantal

                    <input
                        id="settingInputCount"
                        type="number"
                        min="1"
                        value="${
                            Number(
                                settings.input?.count
                            )
                            || 1
                        }"
                    >
                </label>

                <label>
                    Resultaatitem

                    <select id="settingOutputItem">
                        ${itemSelectOptions(
                            settings.output?.item
                        )}
                    </select>
                </label>

                <label>
                    Resultaataantal

                    <input
                        id="settingOutputCount"
                        type="number"
                        min="1"
                        value="${
                            Number(
                                settings.output?.count
                            )
                            || 1
                        }"
                    >
                </label>

                <label>
                    Tijd (ms)

                    <input
                        id="settingProcessDuration"
                        type="number"
                        min="500"
                        value="${
                            Number(
                                settings.duration
                            )
                            || 5000
                        }"
                    >
                </label>

            </div>
        `;

        return;
    }


    /* -----------------------------------------------------
       GARAGE
    ----------------------------------------------------- */

    if (type === 'garage') {
        host.innerHTML = `
            <p class="type-title">
                Werkvoertuigen
            </p>

            <div
                id="vehicleRows"
                class="repeat-list"
            ></div>

            <button
                id="addVehicle"
                type="button"
                class="small-button"
            >
                + Voertuig toevoegen
            </button>
        `;

        const vehicles =
            Array.isArray(
                settings.vehicles
            )
                ? settings.vehicles
                : [];

        if (vehicles.length) {
            vehicles.forEach(
                addVehicleRow
            );
        } else {
            addVehicleRow();
        }

        $('#addVehicle').onclick =
            () => addVehicleRow();

        return;
    }


    /* -----------------------------------------------------
       TELEPORT
    ----------------------------------------------------- */

    if (type === 'teleport') {
        const destination =
            settings.destination
            || {};

        host.innerHTML = `
            <p class="type-title">
                Bestemming
            </p>

            <div class="grid2">

                <label>
                    X

                    <input
                        id="settingTeleportX"
                        type="number"
                        step="0.001"
                        value="${
                            Number(
                                destination.x
                            )
                            || 0
                        }"
                    >
                </label>

                <label>
                    Y

                    <input
                        id="settingTeleportY"
                        type="number"
                        step="0.001"
                        value="${
                            Number(
                                destination.y
                            )
                            || 0
                        }"
                    >
                </label>

                <label>
                    Z

                    <input
                        id="settingTeleportZ"
                        type="number"
                        step="0.001"
                        value="${
                            Number(
                                destination.z
                            )
                            || 0
                        }"
                    >
                </label>

                <label>
                    Heading

                    <input
                        id="settingTeleportW"
                        type="number"
                        step="0.1"
                        value="${
                            Number(
                                destination.w
                            )
                            || 0
                        }"
                    >
                </label>

            </div>

            <label class="check">

                <input
                    id="settingTeleportVehicle"
                    type="checkbox"
                >

                Voertuig meenemen

            </label>
        `;

        $('#settingTeleportVehicle').checked =
            settings.allowVehicle
            === true;

        return;
    }


    host.innerHTML = `
        <p class="muted">
            Voor dit type zijn geen extra instellingen nodig.
        </p>
    `;
}


/* =========================================================
   SETTINGS BUILDER
========================================================= */

function renderSettingsBuilder(
    settings = {}
) {
    builderBaseSettings =
        clone(
            settings
        );

    const duty =
        $('#settingDuty');

    const icon =
        $('#settingIcon');

    const blip =
        $('#settingBlip');

    const blipSprite =
        $('#settingBlipSprite');

    const blipColour =
        $('#settingBlipColour');

    const blipScale =
        $('#settingBlipScale');

    const ped =
        $('#settingPed');

    const pedModel =
        $('#settingPedModel');

    const object =
        $('#settingObject');

    const objectModel =
        $('#settingObjectModel');


    if (duty) {
        /*
            Duty-punt zelf mag altijd gebruikt
            kunnen worden, anders kun je nooit
            in dienst gaan.
        */
        if (
            $('#pointType')?.value
            === 'duty'
        ) {
            duty.checked =
                false;
        } else {
            duty.checked =
                settings.requireDuty
                !== false;
        }
    }


    if (icon) {
        icon.value =
            settings.icon
            || '';
    }


    if (blip) {
        blip.checked =
            Boolean(
                settings.blip
            );
    }


    if (blipSprite) {
        blipSprite.value =
            Number(
                settings.blip?.sprite
            )
            || 280;
    }


    if (blipColour) {
        blipColour.value =
            Number(
                settings.blip?.colour
            )
            || 3;
    }


    if (blipScale) {
        blipScale.value =
            Number(
                settings.blip?.scale
            )
            || 0.65;
    }


    if (ped) {
        ped.checked =
            Boolean(
                settings.ped
            );
    }


    if (pedModel) {
        pedModel.value =
            settings.ped
            || '';
    }


    if (object) {
        object.checked =
            Boolean(
                settings.object
            );
    }


    if (objectModel) {
        objectModel.value =
            settings.object
            || '';
    }


    toggleCommonFields();


    renderTypeFields(
        $('#pointType')?.value
        || '',
        settings
    );


    initialiseModelDropdowns();
}


/* =========================================================
   READ SETTINGS
========================================================= */

function readSettingsBuilder() {
    const settings =
        clone(
            builderBaseSettings
        );

    [
        'requireDuty',
        'icon',
        'blip',
        'ped',
        'object',

        'slots',
        'weight',

        'items',
        'recipes',

        'item',
        'count',
        'duration',
        'tool',

        'input',
        'output',

        'vehicles',

        'destination',
        'allowVehicle',

        'account'
    ].forEach(
        (key) => {
            delete settings[key];
        }
    );


    settings.requireDuty =
        $('#pointType')?.value
        === 'duty'
            ? false
            : $('#settingDuty')?.checked
                !== false;


    const icon =
        $('#settingIcon')
            ?.value
            ?.trim()
        || '';


    if (icon) {
        settings.icon =
            icon;
    }


    if (
        $('#settingBlip')
            ?.checked
    ) {
        settings.blip = {
            enabled: true,

            sprite:
                numeric(
                    '#settingBlipSprite',
                    280
                ),

            colour:
                numeric(
                    '#settingBlipColour',
                    3
                ),

            scale:
                numeric(
                    '#settingBlipScale',
                    0.65
                )
        };
    }


    if (
        $('#settingPed')?.checked
        && $('#settingPedModel')
            ?.value
            ?.trim()
    ) {
        settings.ped =
            $('#settingPedModel')
                .value
                .trim();
    }


    if (
        $('#settingObject')?.checked
        && $('#settingObjectModel')
            ?.value
            ?.trim()
    ) {
        settings.object =
            $('#settingObjectModel')
                .value
                .trim();
    }


    const type =
        $('#pointType')?.value
        || '';


    /* -----------------------------------------------------
       STORAGE
    ----------------------------------------------------- */

    if (
        type === 'stash'
        || type === 'armory'
    ) {
        settings.slots =
            numeric(
                '#settingSlots',
                80
            );

        settings.weight =
            numeric(
                '#settingWeight',
                250000
            );
    }


    /* -----------------------------------------------------
       SHOP
    ----------------------------------------------------- */

    else if (
        type === 'shop'
        || type === 'jobshop'
        || type === 'market'
    ) {
        settings.items =
            [
                ...$$(
                    '.item-setting-row'
                )
            ]
                .map(
                    (row) => ({
                        name:
                            row
                                .querySelector(
                                    '.item-name'
                                )
                                ?.value
                            || '',

                        label:
                            row
                                .querySelector(
                                    '.item-label'
                                )
                                ?.value
                                ?.trim()
                            || '',

                        price:
                            Number(
                                row
                                    .querySelector(
                                        '.item-price'
                                    )
                                    ?.value
                            )
                            || 0
                    })
                )
                .filter(
                    (item) =>
                        item.name
                );


        settings.account =
            $('#settingShopCash')
                ?.checked
                ? 'money'
                : 'bank';
    }


    /* -----------------------------------------------------
       CRAFTING
    ----------------------------------------------------- */

    else if (
        type === 'crafting'
    ) {
        settings.recipes =
            [
                ...$$(
                    '.recipe-setting-row'
                )
            ]
                .map(
                    (row) => {
                        const ingredients =
                            {};

                        row
                            .querySelectorAll(
                                '.ingredient-setting-row'
                            )
                            .forEach(
                                (ingredientRow) => {
                                    const name =
                                        ingredientRow
                                            .querySelector(
                                                '.ingredient-name'
                                            )
                                            ?.value
                                        || '';

                                    const count =
                                        Math.max(
                                            1,
                                            Number(
                                                ingredientRow
                                                    .querySelector(
                                                        '.ingredient-count'
                                                    )
                                                    ?.value
                                            )
                                            || 1
                                        );

                                    if (name) {
                                        ingredients[
                                            name
                                        ] =
                                            Math.floor(
                                                count
                                            );
                                    }
                                }
                            );

                        return {
                            label:
                                row
                                    .querySelector(
                                        '.recipe-label'
                                    )
                                    ?.value
                                    ?.trim()
                                || '',

                            result:
                                row
                                    .querySelector(
                                        '.recipe-result'
                                    )
                                    ?.value
                                || '',

                            count:
                                Math.max(
                                    1,
                                    Number(
                                        row
                                            .querySelector(
                                                '.recipe-count'
                                            )
                                            ?.value
                                    )
                                    || 1
                                ),

                            duration:
                                Math.max(
                                    500,
                                    Number(
                                        row
                                            .querySelector(
                                                '.recipe-duration'
                                            )
                                            ?.value
                                    )
                                    || 5000
                                ),

                            ingredients
                        };
                    }
                )
                .filter(
                    (recipe) =>
                        recipe.result
                );
    }


    /* -----------------------------------------------------
       HARVEST
    ----------------------------------------------------- */

    else if (
        type === 'harvest'
    ) {
        settings.item =
            $('#settingHarvestItem')
                ?.value
            || '';

        settings.count =
            numeric(
                '#settingHarvestCount',
                1
            );

        settings.duration =
            numeric(
                '#settingHarvestDuration',
                3500
            );

        settings.tool =
            $('#settingHarvestTool')
                ?.value
            || '';
    }


    /* -----------------------------------------------------
       PROCESS
    ----------------------------------------------------- */

    else if (
        type === 'process'
    ) {
        settings.input = {
            item:
                $('#settingInputItem')
                    ?.value
                || '',

            count:
                numeric(
                    '#settingInputCount',
                    1
                )
        };


        settings.output = {
            item:
                $('#settingOutputItem')
                    ?.value
                || '',

            count:
                numeric(
                    '#settingOutputCount',
                    1
                )
        };


        settings.duration =
            numeric(
                '#settingProcessDuration',
                5000
            );
    }


    /* -----------------------------------------------------
       GARAGE
    ----------------------------------------------------- */

    else if (
        type === 'garage'
    ) {
        settings.vehicles =
            [
                ...$$(
                    '.vehicle-setting-row'
                )
            ]
                .map(
                    (row) => ({
                        model:
                            row
                                .querySelector(
                                    '.vehicle-model'
                                )
                                ?.value
                                ?.trim()
                            || '',

                        label:
                            row
                                .querySelector(
                                    '.vehicle-label'
                                )
                                ?.value
                                ?.trim()
                            || ''
                    })
                )
                .filter(
                    (vehicle) =>
                        vehicle.model
                );
    }


    /* -----------------------------------------------------
       TELEPORT
    ----------------------------------------------------- */

    else if (
        type === 'teleport'
    ) {
        settings.destination = {
            x:
                numeric(
                    '#settingTeleportX'
                ),

            y:
                numeric(
                    '#settingTeleportY'
                ),

            z:
                numeric(
                    '#settingTeleportZ'
                ),

            w:
                numeric(
                    '#settingTeleportW'
                )
        };


        settings.allowVehicle =
            $('#settingTeleportVehicle')
                ?.checked
            === true;
    }


    return settings;
}


/* =========================================================
   POINT LABEL HELPERS
========================================================= */

function getPointTypeLabel(type) {
    return state.pointTypes?.[
        type
    ]
        || type
        || '';
}


function getSelectedJobLabel() {
    const jobName =
        $('#pointJob')?.value
        || '';

    if (!jobName) {
        return '';
    }

    const job =
        state.jobs.find(
            (entry) =>
                entry.name
                === jobName
        );

    return job?.label
        || jobName;
}


function updatePointLabel(
    force = false
) {
    const labelInput =
        $('#pointLabel');

    if (!labelInput) {
        return;
    }

    if (
        !force
        && labelInput.value.trim()
            !== ''
        && labelInput.dataset.autoLabel
            !== 'true'
    ) {
        return;
    }

    const jobLabel =
        getSelectedJobLabel();

    const typeLabel =
        getPointTypeLabel(
            $('#pointType')?.value
        );

    let label =
        '';

    if (
        jobLabel
        && typeLabel
    ) {
        label =
            `${jobLabel} - ${typeLabel}`;
    } else if (typeLabel) {
        label =
            typeLabel;
    } else if (jobLabel) {
        label =
            jobLabel;
    }

    labelInput.value =
        label;

    labelInput.dataset.autoLabel =
        'true';
}


/* =========================================================
   POINT FORM
========================================================= */

function resetPoint() {
    $('#pointId').value =
        '';

    $('#pointGrade').value =
        0;

    $('#pointRadius').value =
        1.5;

    $('#pointPublic').checked =
        false;

    $('#pointEnabled').checked =
        true;

    importedCoords =
        null;

    $('#pointLabel').value =
        '';

    $('#pointLabel')
        .dataset
        .autoLabel =
        'true';

    renderSettingsBuilder(
        {}
    );

    updatePointLabel(
        true
    );

    initialiseModelDropdowns();
}


function editPoint(point) {
    if (!point) {
        return;
    }

    importedCoords =
        null;

    $('#pointId').value =
        point.id || '';

    $('#pointJob').value =
        point.job_name || '';

    $('#pointType').value =
        point.type || '';

    $('#pointLabel').value =
        point.label || '';

    $('#pointLabel')
        .dataset
        .autoLabel =
        'false';

    $('#pointGrade').value =
        point.min_grade ?? 0;

    $('#pointRadius').value =
        point.radius ?? 1.5;

    $('#pointPublic').checked =
        Number(
            point.public
        ) === 1;

    $('#pointEnabled').checked =
        Number(
            point.enabled
        ) === 1;

    let settings =
        {};

    if (
        point.settings
        && typeof point.settings
            === 'object'
    ) {
        settings =
            point.settings;
    } else {
        try {
            settings =
                JSON.parse(
                    point.settings
                    || '{}'
                );
        } catch {
            settings =
                {};
        }
    }

    renderSettingsBuilder(
        settings
    );
}


/* =========================================================
   RENDER
========================================================= */

function render() {
    state.jobs =
        Array.isArray(
            state.jobs
        )
            ? state.jobs
            : [];

    state.grades =
        Array.isArray(
            state.grades
        )
            ? state.grades
            : [];

    state.points =
        Array.isArray(
            state.points
        )
            ? state.points
            : [];

    state.logs =
        Array.isArray(
            state.logs
        )
            ? state.logs
            : [];

    state.pointTypes =
        state.pointTypes
        && typeof state.pointTypes
            === 'object'
            ? state.pointTypes
            : {};


    const selectedGradeJob =
        $('#gradeJob')?.value
        || '';

    const selectedPointJob =
        $('#pointJob')?.value
        || '';

    const selectedType =
        $('#pointType')?.value
        || '';


    /* -----------------------------------------------------
       SELECTS
    ----------------------------------------------------- */

    if ($('#gradeJob')) {
        $('#gradeJob').innerHTML =
            jobOptions(
                selectedGradeJob
            );
    }


    if ($('#pointJob')) {
        $('#pointJob').innerHTML = `
            <option value="">
                Geen job / publiek
            </option>

            ${jobOptions(
                selectedPointJob
            )}
        `;

        if (
            selectedPointJob
        ) {
            $('#pointJob').value =
                selectedPointJob;
        }
    }


    if ($('#pointType')) {
        $('#pointType').innerHTML =
            Object
                .entries(
                    state.pointTypes
                )
                .map(
                    ([key, label]) => `
                        <option
                            value="${safe(key)}"
                        >
                            ${safe(label)}
                        </option>
                    `
                )
                .join('');

        if (
            selectedType
            && state.pointTypes[
                selectedType
            ]
        ) {
            $('#pointType').value =
                selectedType;
        }
    }


    /* -----------------------------------------------------
       JOBS
    ----------------------------------------------------- */

    if ($('#jobsList')) {
        $('#jobsList').innerHTML =
            state.jobs.length
                ? state.jobs
                    .map(
                        (job) => `
                            <article
                                class="card"
                                data-job="${safe(job.name)}"
                            >

                                <h3>
                                    ${safe(job.label)}
                                </h3>

                                <p>
                                    ${safe(job.name)}
                                    ·
                                    ${
                                        Number(
                                            job.enabled
                                        )
                                            ? 'Actief'
                                            : 'Uitgeschakeld'
                                    }
                                </p>

                                <div class="stats">

                                    <span class="badge">
                                        ${
                                            Number(
                                                job.whitelisted
                                            )
                                                ? 'Whitelist'
                                                : 'Publiek'
                                        }
                                    </span>

                                    <span class="badge">
                                        ${
                                            Number(
                                                job.grades
                                            )
                                            || 0
                                        }
                                        rangen
                                    </span>

                                    <span class="badge">
                                        ${
                                            Number(
                                                job.employees
                                            )
                                            || 0
                                        }
                                        medewerkers
                                    </span>

                                </div>

                            </article>
                        `
                    )
                    .join('')

                : `
                    <div class="empty">
                        Nog geen jobs gevonden.
                    </div>
                `;

        $$('[data-job]')
            .forEach(
                (element) => {
                    element.onclick =
                        () => {
                            const job =
                                state.jobs.find(
                                    (item) =>
                                        item.name
                                        === element.dataset.job
                                );

                            editJob(
                                job
                            );
                        };
                }
            );
    }


    /* -----------------------------------------------------
       GRADES
    ----------------------------------------------------- */

    if ($('#gradesList')) {
        $('#gradesList').innerHTML =
            state.grades.length
                ? `
                    <div class="row head">
                        <span>Job</span>
                        <span>Rang</span>
                        <span>Label</span>
                        <span>Salaris</span>
                    </div>

                    ${
                        state.grades
                            .map(
                                (grade, index) => `
                                    <div
                                        class="row"
                                        data-grade="${index}"
                                    >

                                        <span>
                                            ${safe(
                                                grade.job_name
                                            )}
                                        </span>

                                        <span>
                                            ${
                                                Number(
                                                    grade.grade
                                                )
                                                || 0
                                            }
                                            ·
                                            ${safe(
                                                grade.name
                                            )}
                                        </span>

                                        <span>
                                            ${safe(
                                                grade.label
                                            )}
                                        </span>

                                        <span>
                                            €${
                                                Number(
                                                    grade.salary
                                                )
                                                || 0
                                            }
                                        </span>

                                    </div>
                                `
                            )
                            .join('')
                    }
                `

                : `
                    <div class="empty">
                        Nog geen rangen.
                    </div>
                `;

        $$('[data-grade]')
            .forEach(
                (element) => {
                    element.onclick =
                        () => {
                            editGrade(
                                state.grades[
                                    Number(
                                        element.dataset.grade
                                    )
                                ]
                            );
                        };
                }
            );
    }


    /* -----------------------------------------------------
       POINTS
    ----------------------------------------------------- */

    if ($('#pointsList')) {
        $('#pointsList').innerHTML =
            state.points.length
                ? `
                    <div class="row head">
                        <span>Label</span>
                        <span>Type</span>
                        <span>Job</span>
                        <span>Rang</span>
                    </div>

                    ${
                        state.points
                            .map(
                                (point, index) => `
                                    <div
                                        class="row"
                                        data-point="${index}"
                                    >

                                        <span>
                                            ${safe(
                                                point.label
                                            )}
                                        </span>

                                        <span>
                                            ${safe(
                                                state.pointTypes[
                                                    point.type
                                                ]
                                                || point.type
                                            )}
                                        </span>

                                        <span>
                                            ${
                                                Number(
                                                    point.public
                                                )
                                                    ? 'Publiek'
                                                    : safe(
                                                        point.job_name
                                                        || '-'
                                                    )
                                            }
                                        </span>

                                        <span>
                                            ${
                                                Number(
                                                    point.min_grade
                                                )
                                                || 0
                                            }
                                        </span>

                                    </div>
                                `
                            )
                            .join('')
                    }
                `

                : `
                    <div class="empty">
                        Nog geen interactiepunten.
                    </div>
                `;

        $$('[data-point]')
            .forEach(
                (element) => {
                    element.onclick =
                        () => {
                            editPoint(
                                state.points[
                                    Number(
                                        element.dataset.point
                                    )
                                ]
                            );
                        };
                }
            );
    }


    /* -----------------------------------------------------
       LOGS
    ----------------------------------------------------- */

    if ($('#logsList')) {
        $('#logsList').innerHTML =
            state.logs.length
                ? `
                    <div class="row head">
                        <span>Datum</span>
                        <span>Job</span>
                        <span>Actie</span>
                        <span>Uitvoerder</span>
                    </div>

                    ${
                        state.logs
                            .map(
                                (entry) => `
                                    <div class="row">

                                        <span>
                                            ${safe(
                                                entry.created_at
                                            )}
                                        </span>

                                        <span>
                                            ${safe(
                                                entry.job_name
                                                || '-'
                                            )}
                                        </span>

                                        <span>
                                            ${safe(
                                                entry.action
                                            )}
                                        </span>

                                        <span class="muted">
                                            ${safe(
                                                entry.identifier
                                            )}
                                        </span>

                                    </div>
                                `
                            )
                            .join('')
                    }
                `

                : `
                    <div class="empty">
                        Nog geen beheeracties.
                    </div>
                `;
    }


    if (
        $('#typeSettings')
        && !$('#typeSettings')
            .children
            .length
        && $('#pointType')?.value
    ) {
        renderSettingsBuilder(
            builderBaseSettings
        );
    }


    initialiseModelDropdowns();
}


/* =========================================================
   REFRESH / ACTION
========================================================= */

async function refresh() {
    const data =
        await post(
            'refresh'
        );

    if (
        data.success
        === false
    ) {
        notice(
            data.message,
            false
        );

        return;
    }

    state = {
        ...state,
        ...data
    };

    render();
}


async function action(
    name,
    data
) {
    const result =
        await post(
            name,
            data
        );

    notice(
        result.message,
        result.success
    );

    if (result.success) {
        await refresh();
    }

    return result;
}


/* =========================================================
   FORMS
========================================================= */

if ($('#jobForm')) {
    $('#jobForm').onsubmit =
        async (event) => {
            event.preventDefault();

            await action(
                'saveJob',
                {
                    original:
                        $('#jobOriginal').value
                        || null,

                    name:
                        $('#jobName')
                            .value
                            .trim()
                            .toLowerCase(),

                    label:
                        $('#jobLabel')
                            .value
                            .trim(),

                    whitelisted:
                        $('#jobWhitelist')
                            .checked,

                    enabled:
                        $('#jobEnabled')
                            .checked
                }
            );
        };
}


if ($('#gradeForm')) {
    $('#gradeForm').onsubmit =
        async (event) => {
            event.preventDefault();

            await action(
                'saveGrade',
                {
                    jobName:
                        $('#gradeJob').value,

                    grade:
                        Number(
                            $('#gradeNumber')
                                .value
                        ),

                    name:
                        $('#gradeName')
                            .value
                            .trim()
                            .toLowerCase(),

                    label:
                        $('#gradeLabel')
                            .value
                            .trim(),

                    salary:
                        Number(
                            $('#gradeSalary')
                                .value
                        ),

                    boss:
                        $('#gradeBoss')
                            .checked
                }
            );
        };
}


if ($('#pointForm')) {
    $('#pointForm').onsubmit =
        async (event) => {
            event.preventDefault();

            const existing =
                Boolean(
                    $('#pointId').value
                );

            const payload = {
                id:
                    Number(
                        $('#pointId').value
                    )
                    || null,

                jobName:
                    $('#pointJob').value
                    || null,

                type:
                    $('#pointType').value,

                label:
                    $('#pointLabel')
                        .value
                        .trim(),

                minGrade:
                    Number(
                        $('#pointGrade').value
                    ),

                radius:
                    Number(
                        $('#pointRadius').value
                    ),

                public:
                    $('#pointPublic')
                        .checked,

                enabled:
                    $('#pointEnabled')
                        .checked,

                settings:
                    readSettingsBuilder(),

                useCurrent:
                    !existing
                    && !importedCoords
            };


            if (
                !existing
                && importedCoords
            ) {
                payload.x =
                    importedCoords.x;

                payload.y =
                    importedCoords.y;

                payload.z =
                    importedCoords.z;

                payload.w =
                    importedCoords.w
                    || 0;
            }


            const result =
                await action(
                    'savePoint',
                    payload
                );


            if (result.success) {
                importedCoords =
                    null;
            }
        };
}


/* =========================================================
   BUTTONS
========================================================= */

if ($('#newJob')) {
    $('#newJob').onclick =
        resetJob;
}


if ($('#newGrade')) {
    $('#newGrade').onclick =
        resetGrade;
}


if ($('#newPoint')) {
    $('#newPoint').onclick =
        resetPoint;
}


if ($('#deleteJob')) {
    $('#deleteJob').onclick =
        async () => {
            const name =
                $('#jobOriginal').value;

            if (!name) {
                return;
            }

            if (
                !confirm(
                    `Job ${name} verwijderen? Alle medewerkers worden werkloos.`
                )
            ) {
                return;
            }

            await action(
                'deleteJob',
                {
                    name
                }
            );
        };
}


if ($('#deleteGrade')) {
    $('#deleteGrade').onclick =
        async () => {
            const jobName =
                $('#gradeJob').value;

            const grade =
                Number(
                    $('#gradeNumber').value
                );

            if (
                !Number.isFinite(
                    grade
                )
            ) {
                return;
            }

            if (
                !confirm(
                    `Rang ${grade} verwijderen?`
                )
            ) {
                return;
            }

            await action(
                'deleteGrade',
                {
                    jobName,
                    grade
                }
            );
        };
}


if ($('#deletePoint')) {
    $('#deletePoint').onclick =
        async () => {
            const id =
                Number(
                    $('#pointId').value
                );

            if (!id) {
                return;
            }

            if (
                !confirm(
                    'Dit interactiepunt verwijderen?'
                )
            ) {
                return;
            }

            await action(
                'deletePoint',
                {
                    id
                }
            );
        };
}


if ($('#example')) {
    $('#example').onclick =
        () => {
            renderSettingsBuilder(
                state.examples[
                    $('#pointType').value
                ]
                || {}
            );
        };
}


/* =========================================================
   POINT TYPE / LABEL
========================================================= */

if ($('#pointType')) {
    $('#pointType').onchange =
        async () => {
            await loadInventoryItems();

            renderSettingsBuilder(
                {}
            );

            updatePointLabel();

            initialiseModelDropdowns();
        };
}


if ($('#pointJob')) {
    $('#pointJob').onchange =
        () => {
            updatePointLabel();
        };
}


if ($('#pointLabel')) {
    $('#pointLabel')
        .addEventListener(
            'input',
            () => {
                $('#pointLabel')
                    .dataset
                    .autoLabel =
                    'false';
            }
        );
}


/* =========================================================
   COMMON SETTINGS EVENTS
========================================================= */

if ($('#settingBlip')) {
    $('#settingBlip').onchange =
        toggleCommonFields;
}


if ($('#settingPed')) {
    $('#settingPed').onchange =
        () => {
            if (
                $('#settingPed')
                    .checked
                && $('#settingObject')
            ) {
                $('#settingObject')
                    .checked =
                    false;
            }

            toggleCommonFields();

            initialiseModelDropdowns();
        };
}


if ($('#settingObject')) {
    $('#settingObject').onchange =
        () => {
            if (
                $('#settingObject')
                    .checked
                && $('#settingPed')
            ) {
                $('#settingPed')
                    .checked =
                    false;
            }

            toggleCommonFields();

            initialiseModelDropdowns();
        };
}


if ($('#refresh')) {
    $('#refresh').onclick =
        refresh;
}


/* =========================================================
   IMPORT BUTTONS
========================================================= */

if ($('#reloadImportResources')) {
    $('#reloadImportResources').onclick =
        async () => {
            importResourcesLoaded =
                false;

            await loadImportResources(
                true
            );
        };
}


if ($('#scanImportResource')) {
    $('#scanImportResource').onclick =
        async () => {
            const resource =
                $('#importResource')?.value
                || '';

            if (!resource) {
                notice(
                    'Selecteer eerst een resource.',
                    false
                );

                return;
            }

            const host =
                $('#importSuggestions');

            if (host) {
                host.innerHTML = `
                    <div class="empty">
                        ${safe(resource)}
                        wordt gescand...
                    </div>
                `;
            }

            const result =
                await post(
                    'scanResource',
                    {
                        resource
                    }
                );

            if (!result.success) {
                importScan =
                    null;

                if (host) {
                    host.innerHTML = `
                        <div class="empty">
                            Scan mislukt.
                        </div>
                    `;
                }

                notice(
                    result.message
                    || 'Scan mislukt.',
                    false
                );

                return;
            }

            importScan =
                result.scan;

            renderImportScan();

            notice(
                result.message
                || 'Resource scan voltooid.',
                true
            );
        };
}


/* =========================================================
   CLOSE
========================================================= */

async function closeUi() {
    app.classList.add(
        'hidden'
    );

    await post(
        'close'
    );
}


if ($('#close')) {
    $('#close').onclick =
        closeUi;
}


window.addEventListener(
    'keydown',
    (event) => {
        if (
            event.key
            === 'Escape'
            || event.key
            === 'F10'
        ) {
            event.preventDefault();

            closeUi();
        }
    }
);


/* =========================================================
   NAVIGATION
========================================================= */

$$('nav button')
    .forEach(
        (button) => {
            button.onclick =
                () => {
                    setView(
                        button.dataset.view
                    );
                };
        }
    );


/* =========================================================
   GAME -> NUI
========================================================= */

window.addEventListener(
    'message',
    async (event) => {
        const data =
            event.data
            || {};

        if (
            data.action
            === 'close'
        ) {
            app.classList.add(
                'hidden'
            );

            return;
        }

        if (
            data.action
            === 'open'
            || data.action
            === 'refresh'
        ) {
            state = {
                ...state,
                ...(data.data || {})
            };

            render();

            await loadInventoryItems();

            initialiseModelDropdowns();

            app.classList.remove(
                'hidden'
            );

            return;
        }

        if (
            data.action
            === 'setState'
        ) {
            state = {
                ...state,
                ...(data.data || {})
            };

            render();

            initialiseModelDropdowns();
        }
    }
);


/* =========================================================
   READY
========================================================= */

async function signalReady() {
    await post(
        'ready'
    );
}


window.addEventListener(
    'DOMContentLoaded',
    async () => {
        /*
            NPC/prop dropdowns meteen vullen.
        */
        initialiseModelDropdowns();

        /*
            Client laten weten dat NUI klaar is.
        */
        await signalReady();

        /*
            ox_inventory items laden.
        */
        await loadInventoryItems();

        /*
            Nogmaals koppelen nadat alles geladen is.
        */
        initialiseModelDropdowns();
    }
);