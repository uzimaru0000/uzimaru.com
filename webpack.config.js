'use strict'

const path = require('path');

module.exposrt = {
    entry: {
        app: [
            'index.js'
        ]
    },
    output: {
        path: path.join(__dirname, '/dist'),
        filename: '[name].js'
    },
    module: {
        loader: [
            {
                test: /\.html$/,
                exclude: /node_modules/,
                loader: 'file-loader?name=[name].[ext]'
            },
            {
                test: /\.elm$/,
                exclude: [/node_modules/, /elm-stuff/, /Stylesheets\.elm$/],
                loader: 'elm-webpack-loader'
            }
        ]
    }
};
