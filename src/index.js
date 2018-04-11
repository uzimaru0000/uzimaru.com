'use strict'

require('./index.html');
require('./style.css');
require('./assets/icon2.png');
require('./assets/link.png');
require('./assets/work.png');

const elm = require('./Elm/Main.elm');

const main = document.getElementById('main');
const app = elm.Main.embed(main);

app.ports.requestUrl.subscribe(_ => {
    const protocol = location.protocol;
    const host = location.host;
    app.ports.getUrl.send(protocol + "//" + host);
});