import type { HTMLAttributes, ReactNode } from "react";
import styles from "./Card.module.css";

type CardProps = HTMLAttributes<HTMLElement> & {
  children: ReactNode;
};

export function Card({ children, className, ...props }: CardProps) {
  const mergedClassName = className ? `${styles.card} ${className}` : styles.card;
  return (
    <section className={mergedClassName} {...props}>
      {children}
    </section>
  );
}
