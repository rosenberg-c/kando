import type { HTMLAttributes } from "react";
import styles from "./Spinner.module.css";

type SpinnerProps = HTMLAttributes<HTMLSpanElement> & {
  label?: string;
};

export function Spinner({ className, label = "Loading", ...props }: SpinnerProps) {
  const mergedClassName = [styles.spinner, className].filter(Boolean).join(" ");
  return <span className={mergedClassName} role="status" aria-label={label} {...props} />;
}
