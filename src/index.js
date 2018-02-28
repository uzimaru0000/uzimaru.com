'use strict'

require('./index.html');
require('./style.css');
require('./assets/icon2.png');

const elm = require('./Elm/Main.elm');

const main = document.getElementById('main');
const app = elm.Main.embed(main);