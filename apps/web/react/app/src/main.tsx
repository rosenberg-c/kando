import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { AuthProvider } from "@kando/auth";
import { authSessionStore } from "./auth/sessionStore";
import { authTransport } from "./auth/transport";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <AuthProvider transport={authTransport} sessionStore={authSessionStore}>
      <App />
    </AuthProvider>
  </React.StrictMode>,
);
