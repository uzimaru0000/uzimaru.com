const isProd = process.env.NODE_ENV === 'production';

module.exports = {
  plugins: [
    require('postcss-import'),
    require('postcss-nested'),
    require('autoprefixer'),
    isProd && require('cssnano')({ preset: 'default' }),
  ].filter(Boolean),
  sourceMap: !isProd,
};
