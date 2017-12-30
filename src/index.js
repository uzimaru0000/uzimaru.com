'use strict'

require('./index.html');

const elm = require('./Elm/Main.elm');

const main = document.getElementById('main');
const app = elm.Main.embed(main);
