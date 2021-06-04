const isProd = process.env.NODE_ENV === 'production';

module.exports = {
  plugins: [
    require('tailwindcss'),
    require('postcss-import'),
    require('autoprefixer'),
    isProd && require('cssnano')({ preset: 'default' }),
  ].filter(Boolean),
  sourceMap: !isProd,
};
