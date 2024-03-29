import './style.pcss';

import { Elm } from './Elm/Main.elm';
import { TerminalInput } from './elements/terminal_input';

window.customElements.define('terminal-input', TerminalInput);

const dirData = localStorage.getItem('dir') ?? '{}';
const main = document.getElementById('main')!;
const app = Elm.Main.init({ node: main, flags: JSON.parse(dirData) });

app.ports.openExternalLink.subscribe((x: string) => {
  window.open(x, '__blank');
});
