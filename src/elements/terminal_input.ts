import { LitElement, html, css, property } from 'lit-element'

export class TerminalInput extends LitElement {
    @property({type: Number})
    selectionStart: number = 0
    @property({type: Number})
    selectionEnd: number = 0
    _value: string = ""

    static get properties() {
        return {
            value: { type: String }
        }
    }

    set value(value) {
        const oldVal = this._value
        this._value = value
        this.selectionStart = this.selectionEnd = this._value.length
        this.requestUpdate('value', oldVal)
    }

    get value() { return this._value }

    constructor() {
        super()
    }

    focus() {
        this.shadowRoot?.querySelector('input')?.focus()
    }

    static get styles() {
        return css`
            :host {
                display: inline;
            }

            div {
                display: inline;
            }

            input {
                position: absolute;
                top: -100%;
                left: -100%;
                opacity: 0;
            } 

            span {
                white-space: pre; 
            }

            .caret {
                background: currentColor;
                white-space: pre;
            }
        `
    }

    render() {
        return html`
            <div>
                <input
                    .value="${this.value}"
                    @input="${this.bindValue}"
                    @keydown="${this.caretUpdate}"
                    @select="${this.caretUpdate}"
                >
                <span>${this.beforeString}<span class="caret">${this.currentChar}</span>${this.afterString}</span>
            </div>
        `
    }

    private caretUpdate(e: KeyboardEvent | InputEvent) {
        const input = e.target as HTMLInputElement;

        if (e instanceof KeyboardEvent) {
            if ((e as KeyboardEvent).key === 'ArrowRight') {
                this.selectionStart = Math.min(this.selectionStart + 1, input.value.length)
                this.selectionEnd = Math.min(this.selectionEnd + 1, input.value.length)
            } else if ((e as KeyboardEvent).key === 'ArrowLeft') {
                this.selectionStart = Math.max(this.selectionStart - 1, 0)
                this.selectionEnd = Math.max(this.selectionEnd - 1, 0)
            }
        } else {
            this.selectionStart = input.selectionStart ?? 0
            this.selectionEnd = input.selectionEnd ?? 0
        }
    }

    private bindValue(e: InputEvent) {
        this.value = (e.target as HTMLInputElement | null)?.value ?? ""
        this.caretUpdate(e)
    }

    private get beforeString() {
        return this.value.slice(0, this.selectionStart)
    }

    private get currentChar() {
        return this.value.slice(this.selectionStart, this.selectionEnd+1) || " "
    }

    private get afterString() {
        return this.value.slice(this.selectionEnd+1)
    }

}
