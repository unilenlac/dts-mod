const endpointText = () => {    
    const items = document.querySelectorAll('dmod-endpoint-infos .dts-endpoints li');
    return Array.from(items)
        .map(item => item.textContent.replace(/\s+/g, ' ').trim())
        .join('\n');
};

const citationSuffix = () => {
    const url = document.querySelector('li[name="dts-excerpt"] a')
        ?? document.querySelector('li[name="dts-document"] a');
    const date = new Date().toISOString().split('T')[0];
    return " url: <" + (url?.textContent || '') + "> consulté le: " + date;
};

// Same as citationText() but only with the metadata pb-view content (no document text).
const metadataText = () => {
    const view = document.querySelector('.metadata-panel pb-view');
    const content = (view?.___content?.textContent || '').replace(/\s+/g, ' ').trim();
    return content;
};

const citationText = () => {

    let citation = '';
    const views = document.querySelectorAll('pb-view');
    const resource = document.querySelector('li[name="dts-document"] a');
    const excerpt = document.querySelector('li[name="dts-excerpt"] a');
    // store all divs text content in stmts array
    if (views) {
        views.forEach((view, ind) => {
            const content = view.___content?.cloneNode(true);
            const notesAreHidden = Array.from(toggleStates.entries()).some(([targetClasses, hidden]) =>
                hidden && targetClasses.split(/\s+/).includes('footnotes')
            );
            if (content && notesAreHidden) {
                content.querySelectorAll('.footnotes, #footnotes, [part="footnotes"], .popovers, a.note[rel="footnote"]')
                    .forEach(element => element.remove());
            }
            let sectionContent = (content?.textContent || '').replace(/\s+/g, ' ').trim();
            if (ind === 0){
                sectionContent = `"${sectionContent}"`;
            }
            citation = citation + " " + sectionContent;
            // if excerpt element style display is not none, include its content
            console.log(citation);
        });
        // the excerpt link only exists in the DOM when a ref is set
        const urlElement = excerpt ?? resource;
        if (urlElement) {
            citation = citation + " url: <" + urlElement.textContent + ">";
        }
        // fetch date as a readable timestamp, no hour just date
        const date = new Date();
        //use i18n for date label
        citation = citation + " consulté le: " + date.toISOString().split('T')[0];
    }
    return citation;
};

const copyCitationButton = (copyFunc, selector) => {
    const citationDiv = document.querySelector(selector);
    if (citationDiv) {
        const copyButton = document.createElement('iron-icon');
        copyButton.classList.add('dts-metadata-copy-button');
        copyButton.setAttribute('icon', 'icons:content-copy');
        copyButton.setAttribute('title', 'Copy citation');
        copyButton.setAttribute('role', 'button');
        copyButton.setAttribute('tabindex', '0');
        copyButton.addEventListener('click', () => {
            console.log('Copying citation to clipboard');
            const citation = copyFunc(); 
            navigator.clipboard.writeText(citation);
        });
        citationDiv.appendChild(copyButton);
    }
};

document.addEventListener('DOMContentLoaded', function () {
    copyCitationButton(metadataText, 'h2.metadata');
});

// The component re-creates its title on every render, so the button is re-attached each time
document.addEventListener('dmod-endpoint-infos-render', function () {
    copyCitationButton(endpointText, 'dmod-endpoint-infos .dts-title');
});

const toggleStates = new Map();
const hiddenElementStyles = new WeakMap();

const updateTargetVisibility = (targetClasses, hidden) => {
    const mainView = document.querySelector('pb-view');
    const roots = [mainView?.___content, mainView?.shadowRoot]
        .filter(root => root?.querySelectorAll);
    if (!roots.length) {
        return;
    }

    const classNames = targetClasses.split(/\s+/).filter(Boolean);
    const elements = new Set(classNames.flatMap(className =>
        roots.flatMap(root => Array.from(root.querySelectorAll(`.${className}`)))
    ));

    elements.forEach(element => {
        if (hidden) {
            if (!hiddenElementStyles.has(element)) {
                hiddenElementStyles.set(element, {
                    value: element.style.getPropertyValue('display'),
                    priority: element.style.getPropertyPriority('display')
                });
            }
            element.style.setProperty('display', 'none', 'important');
        } else if (hiddenElementStyles.has(element)) {
            const previousDisplay = hiddenElementStyles.get(element);
            if (previousDisplay.value) {
                element.style.setProperty('display', previousDisplay.value, previousDisplay.priority);
            } else {
                element.style.removeProperty('display');
            }
            hiddenElementStyles.delete(element);
        }
    });
};

const toggleActions = {
    'hide-class': ({ targetClass, checked }) => {
        if (!targetClass) {
            return;
        }
        toggleStates.set(targetClass, checked);
        updateTargetVisibility(targetClass, checked);
    }
};

document.addEventListener('dmod-toggle-change', event => {
    const action = toggleActions[event.detail?.action];
    action?.({
        ...event.detail,
        checked: Boolean(event.detail?.checked)
    });
});

document.addEventListener('pb-refresh', () => {
    toggleStates.forEach((checked, targetClass) => {
        if (checked) {
            updateTargetVisibility(targetClass, true);
        }
    });
});


const displayCitationInModal = () => {
    const field = document.getElementById('citation-modal-text');
    if (field) {
        field.value = citationText().trim();
    }
};

document.addEventListener('click', (ev) => {
    const modal = document.getElementById('citation-modal');
    if (!modal) return;
    if (ev.target.closest('#citation-open')) {
        displayCitationInModal();
        modal.showModal();
        return;
    }
    const action = ev.target.closest('[data-modal-action]')?.dataset.modalAction;
    if (action === 'close') {
        modal.close();
    } else if (action === 'copy') {
        const text = modal.querySelector('#citation-modal-text').value;
        navigator.clipboard.writeText(text);
    } else if (ev.target === modal) {
        modal.close();
    }
});
