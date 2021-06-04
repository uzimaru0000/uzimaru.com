module.exports = {
  purge: ['./src/index.html', './src/Elm/**/*.elm'],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {
      colors: {
        gray: '#575757',
        lightGreen: '#88ff63',
        orange: '#ffbb38',
        black: '#282828',
        red: '#ff5454',
        yellow: '#ffc054',
        green: '#83d328',
      },
    },
    fontFamily: {
      sans: ['"Press Start 2P"', 'sans-serif'],
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
};
