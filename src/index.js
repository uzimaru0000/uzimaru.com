'use strict'

import './style.scss';

import {Elm} from './Elm/Main.elm';

const main = document.getElementById('main');
const app = Elm.Main.init({node: main});
