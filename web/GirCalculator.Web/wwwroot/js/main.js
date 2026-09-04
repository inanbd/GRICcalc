// Entry point for the calculator page. A real file rather than an inline
// script, because the page's Content-Security-Policy allows only same-origin
// scripts - which is part of how the calculator is kept off the network.
import { start } from './app.js';

start();
