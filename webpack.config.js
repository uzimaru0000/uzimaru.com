'use strict'

const MiniCssExtractPlugin = require("mini-css-extract-plugin");

module.exports = {
    entry: {
        app: './src/index.js'
    },
    output: {
        path: `${__dirname}/dist`,
        filename: '[name].js'
    },
    module: {
        rules: [
            {
                test: /\.html$/,
                exclude: [/node_modules/, /elm-stuff/ ],
                use: 'file-loader?name=[name].[ext]'
            },
            {
                test: /\.scss$/,
                use: [
                    {
                        loader: MiniCssExtractPlugin.loader,
                    },
                    "css-loader",
                    "sass-loader"
                ]
            },
            {
                test: /\.png$/,
                exclude: [ /node_modules/, /elm-stuff/ ],
                use: 'file-loader?name=[name].[ext]'
            },
            {
                test: /\.elm$/,
                exclude: [ /node_modules/, /elm-stuff/ ],
                use: [
                    {
                        loader: 'elm-webpack-loader',
                        options: {
                            debug: true
                        },
                    }
                ]
            }
        ]
    },
    plugins: [
        new MiniCssExtractPlugin({
            filename: "css/style.css",
            chunkFilename: "css/[id].css"
        })
    ],
    devServer: {
        inline: true,
        stats: 'errors-only',
        historyApiFallback: {
            index: '/'
        }
    }
};
