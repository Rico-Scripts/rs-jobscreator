(() => {
    const REQUEST_TIMEOUT = 15000;

    const originalPost =
        typeof post === 'function'
            ? post
            : null;

    if (originalPost) {
        post = async function(name, data = {}) {
            let timer = null;

            try {
                return await Promise.race([
                    originalPost(name, data),

                    new Promise((resolve) => {
                        timer = setTimeout(
                            () => resolve({
                                success: false,
                                message: 'De server antwoordde niet op tijd. Controleer de serverconsole.'
                            }),
                            REQUEST_TIMEOUT
                        );
                    })
                ]);
            } finally {
                if (timer) {
                    clearTimeout(timer);
                }
            }
        };
    }

    if (typeof action === 'function') {
        action = async function(name, data) {
            const result = await post(name, data);

            notice(
                result.message || (
                    result.success
                        ? 'Actie uitgevoerd.'
                        : 'Actie mislukt.'
                ),
                result.success === true
            );

            // De clientcallback pusht na CRUD-acties zelf de nieuwe state.
            // Geen tweede refresh starten: dit voorkomt dubbele queries/races.
            return result;
        };
    }

    function installConfirmStyles() {
        if (document.getElementById('rsjc-confirm-style')) {
            return;
        }

        const style = document.createElement('style');
        style.id = 'rsjc-confirm-style';
        style.textContent = `
            .rsjc-confirm-overlay {
                position: fixed;
                inset: 0;
                z-index: 99999;
                display: grid;
                place-items: center;
                background: rgba(3, 8, 15, 0.72);
                backdrop-filter: blur(3px);
            }

            .rsjc-confirm-box {
                width: min(440px, calc(100vw - 40px));
                padding: 20px;
                border: 1px solid #33425a;
                border-radius: 14px;
                background: #17212f;
                box-shadow: 0 24px 80px rgba(0, 0, 0, 0.55);
            }

            .rsjc-confirm-box h3 {
                margin: 0 0 10px;
                color: #eaf0f8;
                font-size: 17px;
            }

            .rsjc-confirm-box p {
                margin: 0;
                color: #aab6c8;
                line-height: 1.5;
                font-size: 13px;
            }

            .rsjc-confirm-actions {
                display: flex;
                justify-content: flex-end;
                gap: 8px;
                margin-top: 18px;
            }

            .rsjc-confirm-actions button:disabled,
            button.rsjc-busy:disabled {
                opacity: 0.55;
                cursor: wait;
            }
        `;

        document.head.appendChild(style);
    }

    function rsConfirm(message, title = 'Bevestigen') {
        installConfirmStyles();

        return new Promise((resolve) => {
            const overlay = document.createElement('div');
            overlay.className = 'rsjc-confirm-overlay';

            overlay.innerHTML = `
                <div class="rsjc-confirm-box" role="dialog" aria-modal="true">
                    <h3>${safe(title)}</h3>
                    <p>${safe(message)}</p>

                    <div class="rsjc-confirm-actions">
                        <button type="button" data-rsjc-cancel>
                            Annuleren
                        </button>

                        <button type="button" class="danger" data-rsjc-confirm>
                            Verwijderen
                        </button>
                    </div>
                </div>
            `;

            document.body.appendChild(overlay);

            let finished = false;

            const finish = (result) => {
                if (finished) {
                    return;
                }

                finished = true;
                document.removeEventListener('keydown', onKeyDown, true);
                overlay.remove();
                resolve(result);
            };

            const onKeyDown = (event) => {
                if (event.key === 'Escape') {
                    event.preventDefault();
                    event.stopPropagation();
                    finish(false);
                }
            };

            overlay.querySelector('[data-rsjc-cancel]').onclick =
                () => finish(false);

            overlay.querySelector('[data-rsjc-confirm]').onclick =
                () => finish(true);

            overlay.addEventListener('mousedown', (event) => {
                if (event.target === overlay) {
                    finish(false);
                }
            });

            document.addEventListener('keydown', onKeyDown, true);
        });
    }

    async function runDelete(button, requestName, payload, message, resetFn) {
        if (!button || button.disabled) {
            return;
        }

        const confirmed = await rsConfirm(message);

        if (!confirmed) {
            return;
        }

        const previousText = button.textContent;
        button.disabled = true;
        button.classList.add('rsjc-busy');
        button.textContent = 'Verwijderen...';

        try {
            const result = await action(requestName, payload);

            if (result.success && typeof resetFn === 'function') {
                resetFn();
            }
        } finally {
            button.disabled = false;
            button.classList.remove('rsjc-busy');
            button.textContent = previousText;
        }
    }

    const deleteJob = document.getElementById('deleteJob');

    if (deleteJob) {
        deleteJob.onclick = async () => {
            const name = document.getElementById('jobOriginal')?.value || '';

            if (!name) {
                return;
            }

            await runDelete(
                deleteJob,
                'deleteJob',
                { name },
                `Job ${name} verwijderen? Alle medewerkers worden werkloos.`,
                typeof resetJob === 'function' ? resetJob : null
            );
        };
    }

    const deleteGrade = document.getElementById('deleteGrade');

    if (deleteGrade) {
        deleteGrade.onclick = async () => {
            const jobName = document.getElementById('gradeJob')?.value || '';
            const grade = Number(document.getElementById('gradeNumber')?.value);

            if (!jobName || !Number.isFinite(grade)) {
                return;
            }

            await runDelete(
                deleteGrade,
                'deleteGrade',
                { jobName, grade },
                `Rang ${grade} van ${jobName} verwijderen?`,
                typeof resetGrade === 'function' ? resetGrade : null
            );
        };
    }

    const deletePoint = document.getElementById('deletePoint');

    if (deletePoint) {
        deletePoint.onclick = async () => {
            const id = Number(document.getElementById('pointId')?.value);

            if (!id) {
                return;
            }

            await runDelete(
                deletePoint,
                'deletePoint',
                { id },
                'Dit interactiepunt verwijderen?',
                typeof resetPoint === 'function' ? resetPoint : null
            );
        };
    }

    // Laad uitbreidingen pas nadat app.js + deze stabilisatielaag gereed zijn.
    if (!document.querySelector('script[data-rsjc-extensions]')) {
        const script = document.createElement('script');
        script.src = 'extensions.js';
        script.dataset.rsjcExtensions = 'true';
        document.body.appendChild(script);
    }
})();
