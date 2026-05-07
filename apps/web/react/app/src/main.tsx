import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { AuthProvider } from "@kando/auth";
import { authTransport } from "./auth/transport";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <AuthProvider transport={authTransport}>
      <App />
    </AuthProvider>
  </React.StrictMode>,
);
