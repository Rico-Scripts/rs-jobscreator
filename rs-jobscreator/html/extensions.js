(() => {
    const modelControls = [];

    function modelList(type) {
        try {
            if (type === 'ped' && typeof pedModels !== 'undefined') {
                return Array.isArray(pedModels) ? pedModels : [];
            }

            if (type === 'prop' && typeof propModels !== 'undefined') {
                return Array.isArray(propModels) ? propModels : [];
            }
        } catch (error) {
            console.warn('[rs-jobscreator] model catalog:', error);
        }

        return [];
    }

    function installModelStyles() {
        if (document.getElementById('rsjc-extension-style')) {
            return;
        }

        const style = document.createElement('style');
        style.id = 'rsjc-extension-style';
        style.textContent = `
            .rsjc-model-wrap {
                display: grid;
                gap: 7px;
            }

            .rsjc-model-custom.hidden {
                display: none !important;
            }

            .rsjc-import-panel {
                display: grid;
                gap: 12px;
                margin-bottom: 16px;
            }

            .rsjc-import-toolbar {
                display: grid;
                grid-template-columns: minmax(180px, 1fr) auto auto;
                gap: 8px;
                align-items: end;
            }

            .rsjc-job-results {
                display: grid;
                gap: 9px;
            }

            .rsjc-job-card {
                padding: 12px;
                border: 1px solid #2a374b;
                border-radius: 10px;
                background: #111a26;
            }

            .rsjc-job-head {
                display: flex;
                justify-content: space-between;
                align-items: flex-start;
                gap: 10px;
            }

            .rsjc-job-card h3 {
                margin: 0 0 4px;
                font-size: 14px;
            }

            .rsjc-job-card p {
                margin: 0;
                color: #8493a8;
                font-size: 11px;
            }

            .rsjc-grade-list {
                display: flex;
                flex-wrap: wrap;
                gap: 6px;
                margin-top: 10px;
            }

            .rsjc-grade-chip {
                padding: 4px 7px;
                border-radius: 20px;
                background: #29364a;
                color: #c2ccda;
                font-size: 10px;
            }

            .rsjc-confidence {
                font-size: 10px;
                color: #91a1b8;
            }

            @media (max-width: 900px) {
                .rsjc-import-toolbar {
                    grid-template-columns: 1fr;
                }
            }
        `;

        document.head.appendChild(style);
    }

    function enhanceModelInput(inputId, type, emptyLabel) {
        const input = document.getElementById(inputId);
        if (!input || input.dataset.rsjcEnhanced === 'true') {
            return;
        }

        const models = modelList(type);
        if (!models.length) {
            console.warn(`[rs-jobscreator] Geen ${type}-modellen gevonden.`);
            return;
        }

        input.dataset.rsjcEnhanced = 'true';
        input.removeAttribute('list');
        input.classList.add('rsjc-model-custom', 'hidden');

        const wrap = document.createElement('div');
        wrap.className = 'rsjc-model-wrap';

        const select = document.createElement('select');
        select.className = 'rsjc-model-select';

        const options = [
            `<option value="">${safe(emptyLabel)}</option>`,
            ...models.map((entry) => `
                <option value="${safe(entry.model)}">
                    ${safe(entry.label)} — ${safe(entry.model)}
                </option>
            `),
            '<option value="__custom__">Custom model invoeren...</option>'
        ];

        select.innerHTML = options.join('');

        input.parentNode.insertBefore(wrap, input);
        wrap.appendChild(select);
        wrap.appendChild(input);

        const syncFromInput = () => {
            const value = String(input.value || '').trim();
            const known = models.some((entry) => entry.model === value);

            if (!value) {
                select.value = '';
                input.classList.add('hidden');
            } else if (known) {
                select.value = value;
                input.classList.add('hidden');
            } else {
                select.value = '__custom__';
                input.classList.remove('hidden');
            }
        };

        select.addEventListener('change', () => {
            if (select.value === '__custom__') {
                input.classList.remove('hidden');
                input.focus();
                return;
            }

            input.value = select.value;
            input.classList.add('hidden');
            input.dispatchEvent(new Event('change', { bubbles: true }));
        });

        select.addEventListener('focus', syncFromInput);
        select.addEventListener('pointerdown', syncFromInput);

        modelControls.push(syncFromInput);
        syncFromInput();
    }

    function syncModelControls() {
        modelControls.forEach((sync) => sync());
    }

    function installModelDropdowns() {
        installModelStyles();
        enhanceModelInput('settingPedModel', 'ped', 'Selecteer NPC...');
        enhanceModelInput('settingObjectModel', 'prop', 'Selecteer prop...');
        syncModelControls();
    }

    if (typeof renderSettingsBuilder === 'function') {
        const originalRenderSettingsBuilder = renderSettingsBuilder;

        renderSettingsBuilder = function(...args) {
            const result = originalRenderSettingsBuilder(...args);
            queueMicrotask(syncModelControls);
            return result;
        };
    }

    let jobImportResourcesLoaded = false;
    let currentJobScan = null;

    function installJobImportPanel() {
        const importView = document.getElementById('importView');

        if (!importView || document.getElementById('rsjcJobImportPanel')) {
            return;
        }

        const panel = document.createElement('div');
        panel.id = 'rsjcJobImportPanel';
        panel.className = 'panel grow rsjc-import-panel';

        panel.innerHTML = `
            <div>
                <h2>Jobs & rangen uit resource halen</h2>
                <p class="muted">
                    Scan Lua-configs op ESX jobnamen, society-registraties en rangtabellen.
                    Controleer de vondsten voordat je ze importeert.
                </p>
            </div>

            <div class="rsjc-import-toolbar">
                <label>
                    Resource
                    <select id="rsjcJobResource">
                        <option value="">Resources laden...</option>
                    </select>
                </label>

                <button type="button" id="rsjcReloadJobResources">
                    Vernieuwen
                </button>

                <button type="button" class="primary" id="rsjcScanJobs">
                    Jobs scannen
                </button>
            </div>

            <div id="rsjcJobScanMessage" class="muted"></div>

            <div id="rsjcJobResults" class="rsjc-job-results">
                <div class="empty">Nog geen jobscan uitgevoerd.</div>
            </div>
        `;

        importView.prepend(panel);

        document.getElementById('rsjcReloadJobResources').onclick =
            () => loadJobImportResources(true);

        document.getElementById('rsjcScanJobs').onclick = scanJobs;
    }

    async function loadJobImportResources(force = false) {
        const select = document.getElementById('rsjcJobResource');
        if (!select || (jobImportResourcesLoaded && !force)) {
            return;
        }

        select.innerHTML = '<option value="">Laden...</option>';

        const result = await post('getJobImportResources');

        if (!result.success) {
            select.innerHTML = '<option value="">Kon resources niet laden</option>';
            notice(result.message || 'Resources laden mislukt.', false);
            return;
        }

        const resources = Array.isArray(result.resources)
            ? result.resources
            : [];

        select.innerHTML = `
            <option value="">Selecteer resource...</option>
            ${resources.map((resource) => `
                <option value="${safe(resource)}">${safe(resource)}</option>
            `).join('')}
        `;

        jobImportResourcesLoaded = true;
    }

    function renderJobScan(scan) {
        const host = document.getElementById('rsjcJobResults');
        if (!host) {
            return;
        }

        const jobs = Array.isArray(scan?.jobs) ? scan.jobs : [];

        if (!jobs.length) {
            host.innerHTML = `
                <div class="empty">
                    Geen duidelijke jobdefinities gevonden. De resource kan dynamische of versleutelde configs gebruiken.
                </div>
            `;
            return;
        }

        host.innerHTML = jobs.map((job, index) => {
            const grades = Array.isArray(job.grades) ? job.grades : [];

            return `
                <article class="rsjc-job-card">
                    <div class="rsjc-job-head">
                        <div>
                            <h3>${safe(job.label || job.name)}</h3>
                            <p>
                                ${safe(job.name)} · ${safe(job.source || 'onbekend bestand')}
                            </p>
                            <span class="rsjc-confidence">
                                Detectie ${Number(job.confidence || 0)}% · ${safe(job.reason || '')}
                            </span>
                        </div>

                        <button
                            type="button"
                            class="primary"
                            data-rsjc-import-job="${index}"
                        >
                            Importeren
                        </button>
                    </div>

                    <div class="rsjc-grade-list">
                        ${grades.map((grade) => `
                            <span class="rsjc-grade-chip">
                                ${Number(grade.grade || 0)} · ${safe(grade.label || grade.name)} · €${Number(grade.salary || 0)}
                            </span>
                        `).join('')}
                    </div>
                </article>
            `;
        }).join('');

        host.querySelectorAll('[data-rsjc-import-job]').forEach((button) => {
            button.onclick = async () => {
                const index = Number(button.dataset.rsjcImportJob);
                const job = jobs[index];

                if (!job || !currentJobScan) {
                    return;
                }

                button.disabled = true;
                const oldText = button.textContent;
                button.textContent = 'Importeren...';

                try {
                    const result = await post('importJobDefinition', {
                        resource: currentJobScan.resource,
                        name: job.name
                    });

                    notice(
                        result.message || (result.success ? 'Job geïmporteerd.' : 'Import mislukt.'),
                        result.success === true
                    );

                    if (result.success && typeof refresh === 'function') {
                        await refresh();
                    }
                } finally {
                    button.disabled = false;
                    button.textContent = oldText;
                }
            };
        });
    }

    async function scanJobs() {
        const resource = document.getElementById('rsjcJobResource')?.value || '';
        const message = document.getElementById('rsjcJobScanMessage');

        if (!resource) {
            notice('Selecteer eerst een resource.', false);
            return;
        }

        if (message) {
            message.textContent = `${resource} wordt gescand...`;
        }

        const result = await post('scanJobDefinitions', { resource });

        if (!result.success) {
            if (message) {
                message.textContent = result.message || 'Scan mislukt.';
            }
            notice(result.message || 'Jobscan mislukt.', false);
            return;
        }

        currentJobScan = result.scan || null;

        if (message) {
            message.textContent = result.message || 'Scan voltooid.';
        }

        renderJobScan(currentJobScan);
    }

    installModelDropdowns();
    installJobImportPanel();
    loadJobImportResources();
})();
