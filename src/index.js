'use strict'

require('./index.html');
require('./style.scss');
require('./assets/icon2.png');
require('./assets/link.png');
require('./assets/work.png');

import {Elm} from './Elm/Main.elm';

const main = document.getElementById('main');
const app = Elm.Main.init({node: main});
