import type { ButtonHTMLAttributes, ReactNode } from "react";
import styles from "./Button.module.css";

type ButtonVariant = "primary" | "neutral" | "danger";

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  children: ReactNode;
  variant?: ButtonVariant;
};

const variantClassNames: Record<ButtonVariant, string> = {
  primary: styles.primary,
  neutral: styles.neutral,
  danger: styles.danger,
};

export function Button({ children, className, variant = "primary", ...props }: ButtonProps) {
  const mergedClassName = [styles.button, variantClassNames[variant], className].filter(Boolean).join(" ");
  return (
    <button className={mergedClassName} {...props}>
      {children}
    </button>
  );
}
