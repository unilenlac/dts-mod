/**
 * Fetches the rendered HTML of the /endpoint-infos API and inserts it into the element.
 *
 * Attributes:
 *  - resource: DTS resource identifier
 *  - ref: optional passage reference (enables the excerpt link).
 *    Resolved from the latest pb-refresh event, then this attribute,
 *    then the `ref` query parameter of the page URL.
 *  - subscribe: optional pb-components channel; when set, only pb-refresh
 *    events of that channel are handled.
 *
 * Slot: the child nodes of the element (text or pb-i18n) are moved into the
 * rendered title (.dts-title) so that custom elements stay live.
 *
 * The app base URL is taken from the enclosing pb-page.
 */
class DmodEndpointInfos extends HTMLElement {
    static get observedAttributes() {
        return ['resource', 'ref'];
    }

    constructor() {
        super();
        this._onNavigate = () => this.load();
        this._onRefresh = event => this.handleRefresh(event);
    }

    connectedCallback() {
        this._connected = true;
        // Keep the slotted nodes; the rendered HTML replaces them in the DOM
        this._slotNodes ??= Array.from(this.childNodes);
        window.addEventListener('popstate', this._onNavigate);
        document.addEventListener('pb-refresh', this._onRefresh);
        this.load();
    }

    disconnectedCallback() {
        this._connected = false;
        window.removeEventListener('popstate', this._onNavigate);
        document.removeEventListener('pb-refresh', this._onRefresh);
    }

    attributeChangedCallback(name, oldValue, newValue) {
        if (this._connected && oldValue !== newValue) {
            this.load();
        }
    }

    handleRefresh(event) {
        const detail = event.detail || {};
        const channel = this.getAttribute('subscribe');
        if (channel && detail.key !== channel) {
            return;
        }
        this._eventRef = detail.id ?? null;
        this.load();
    }

    get ref() {
        return this._eventRef
            || this.getAttribute('id')
            || new URLSearchParams(window.location.search).get('id');
    }

    async buildUrl() {
        await customElements.whenDefined('pb-page');
        const page = document.querySelector('pb-page');
        const base = (page?.getEndpoint?.() ?? page?.endpoint ?? '.').replace(/\/$/, '');
        const params = new URLSearchParams();
        const values = { resource: this.getAttribute('resource'), ref: this.ref };
        Object.entries(values).forEach(([name, value]) => {
            if (value) {
                params.set(name, value);
            }
        });
        const query = params.toString();
        return `${base}/endpoint-infos${query ? `?${query}` : ''}`;
    }

    async load() {
        const requestId = (this._requestId = (this._requestId || 0) + 1);
        try {
            const response = await fetch(await this.buildUrl(), { headers: { Accept: 'text/html' } });
            if (!response.ok) {
                throw new Error(`${response.status} ${response.statusText}`);
            }
            const html = await response.text();
            // Ignore responses superseded by a newer request
            if (requestId === this._requestId) {
                this.innerHTML = html;
                this.querySelector('.dts-title')?.append(...this._slotNodes);
                this.dispatchEvent(new CustomEvent('dmod-endpoint-infos-render', { bubbles: true }));
            }
        } catch (error) {
            if (requestId === this._requestId) {
                this.textContent = `Unable to load endpoint information: ${error.message}`;
            }
        }
    }
}

customElements.define('dmod-endpoint-infos', DmodEndpointInfos);
