/** @type {import('tailwindcss').Config} */
export default {
    content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
    darkMode: 'class',
    theme: {
        extend: {
            screens: {
                '3xl': '1920px',
                '4xl': '2240px',
                '5xl': '2560px',
            },
        },
    },
    plugins: [],
};
