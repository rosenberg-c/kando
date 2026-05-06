import type { ComponentPropsWithoutRef, ElementType, ReactNode } from "react";
import styles from "./Text.module.css";

type TextTone = "default" | "muted";

type TextProps<T extends ElementType> = {
  as?: T;
  children: ReactNode;
  className?: string;
  variant?: TextTone;
} & Omit<ComponentPropsWithoutRef<T>, "as" | "children" | "className">;

export function Text<T extends ElementType = "p">({
  as,
  children,
  className,
  variant = "default",
  ...props
}: TextProps<T>) {
  const Component = (as ?? "p") as ElementType;
  const toneClassName = variant === "muted" ? styles.muted : "";
  const mergedClassName = [styles.base, toneClassName, className].filter(Boolean).join(" ");

  return (
    <Component className={mergedClassName} {...props}>
      {children}
    </Component>
  );
}
