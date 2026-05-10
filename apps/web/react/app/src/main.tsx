import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { AuthProvider } from "@kando/auth";
import "@kando/styles/tokens.css";
import "@kando/styles/base.css";
import { BrowserRouter } from "react-router-dom";
import { authTransport } from "./auth/transport";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <AuthProvider transport={authTransport}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </AuthProvider>
  </React.StrictMode>,
);
