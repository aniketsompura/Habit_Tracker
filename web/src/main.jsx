import React from "react";
import { createRoot } from "react-dom/client";
import { App } from "./app.jsx";
import { start } from "./store.js";

start();
createRoot(document.getElementById("root")).render(<App />);
