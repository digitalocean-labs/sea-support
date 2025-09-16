// LEARNING NOTE: Tailwind CSS Configuration
// This configures our MoodBrew coffee theme with custom colors and styling
// Tailwind CSS v4 uses a simplified configuration approach

module.exports = {
  content: [
    './public/*.html',
    './app/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/controllers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,html}',
  ],
  plugins: [
    require('@tailwindcss/typography'),
  ],
  theme: {
    extend: {
      // MOODBREW THEME: Coffee-inspired color palette
      colors: {
        // Coffee-themed brand colors from .env
        coffee: {
          50: '#fdf6f0',   // Lightest cream
          100: '#f7e6d3',  // Light cream
          200: '#efc49a',  // Warm cream
          300: '#e4a462',  // Light coffee
          400: '#d2b48c',  // Tan/beige (from .env)
          500: '#cd853f',  // Peru/coffee (from .env)
          600: '#8b4513',  // Coffee brown (primary from .env)
          700: '#7a3f11',  // Dark coffee
          800: '#6b370f',  // Very dark coffee
          900: '#5c300d',  // Darkest coffee
        },
        // Direct brand color mappings for easy use
        'brand-primary': '#8B4513',    // Coffee brown
        'brand-secondary': '#D2B48C',  // Tan/beige  
        'brand-accent': '#CD853F',     // Peru/coffee
      },
      // Coffee-themed spacing
      spacing: {
        '18': '4.5rem',
        '88': '22rem',
      },
      // Coffee cup inspired border radius
      borderRadius: {
        'coffee': '1.5rem',
      },
      // Box shadows for coffee-themed depth
      boxShadow: {
        'coffee': '0 4px 14px 0 rgba(139, 69, 19, 0.25)',
        'coffee-lg': '0 10px 25px 0 rgba(139, 69, 19, 0.35)',
      }
    },
  },
}