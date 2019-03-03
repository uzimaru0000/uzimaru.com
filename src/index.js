'use strict'

require('./index.html');
require('./style.scss');
require('./assets/icon2.png');

import {Elm} from './Elm/Main.elm';

const dirData = localStorage.getItem('dir');
console.log(dirData);

const main = document.getElementById('main');
const app = Elm.Main.init({node: main, flags: JSON.parse(dirData) });

app.ports.store.subscribe(x => {
  localStorage.setItem('dir', JSON.stringify(x));
  const dirData = localStorage.getItem('dir');
  console.log(dirData);
});