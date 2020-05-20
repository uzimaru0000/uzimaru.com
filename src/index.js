'use strict';

import { Elm } from './Elm/Main.elm';

const dirData = localStorage.getItem('dir');
const main = document.getElementById('main');
const app = Elm.Main.init({ node: main, flags: JSON.parse(dirData) });

app.ports.store.subscribe((x) => {
  localStorage.setItem('dir', JSON.stringify(x));
});
