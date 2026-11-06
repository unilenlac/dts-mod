class DmodToggle extends HTMLElement {
    constructor() {
        super();

        const root = this.attachShadow({ mode: 'open' });
        root.innerHTML = `
            <style>
                label { display: inline-flex; align-items: center; gap: 0.5rem; }
                input { position: absolute; opacity: 0; }
                .switch {
                    position: relative;
                    display: inline-block;
                    flex-shrink: 0;
                    width: var(--dmod-toggle-width, 38px);
                    height: var(--dmod-toggle-height, 20px);
                    border-radius: var(--dmod-toggle-height, 20px);
                    background: var(--dmod-toggle-off-color, #ccc);
                    cursor: pointer;
                }
                .switch::before {
                    content: "";
                    position: absolute;
                    left: 3px;
                    bottom: 3px;
                    width: var(--dmod-toggle-thumb-size, 14px);
                    height: var(--dmod-toggle-thumb-size, 14px);
                    border-radius: 50%;
                    background: white;
                    transition: transform 0.2s;
                }
                input:checked + .switch { background: var(--dmod-toggle-on-color, #3b82f6); }
                input:checked + .switch::before {
                    transform: translateX(calc(var(--dmod-toggle-width, 38px) - var(--dmod-toggle-thumb-size, 14px) - 6px));
                }
                input:focus-visible + .switch { outline: 2px solid #3b82f6; }
            </style>
            <label part="label">
                <slot></slot>
                <input type="checkbox">
                <span class="switch" part="switch"></span>
            </label>
        `;

        root.querySelector('input').addEventListener('change', event => {
            this.dispatchEvent(new CustomEvent('dmod-toggle-change', {
                detail: {
                    checked: event.currentTarget.checked,
                    action: this.getAttribute('action'),
                    targetClass: this.getAttribute('target-class')
                },
                bubbles: true,
                composed: true
            }));
        });
    }
}

customElements.define('dmod-toggle', DmodToggle);