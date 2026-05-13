import { Button, Text } from "@kando/components";
import { keys, t } from "@kando/locale";
import styles from "./BoardsPage.module.css";

type CreateBoardModalProps = {
  isBusy: boolean;
  value: string;
  onChange: (value: string) => void;
  onCancel: () => void;
  onSubmit: () => void;
};

export function CreateBoardModal({ isBusy, value, onChange, onCancel, onSubmit }: CreateBoardModalProps) {
  return (
    <div className={styles.modalBackdrop} data-testid="app.boards.create.modal.backdrop">
      <div
        className={styles.modal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="app.boards.create.modal.title"
        data-testid="app.boards.create.modal"
      >
        <h2 id="app.boards.create.modal.title" className={styles.modalTitle}>
          {t(keys.boards.create.title)}
        </h2>
        <label className={styles.fieldWrap} htmlFor="app.boards.create.input">
          <span className={styles.fieldLabel}>{t(keys.boards.create.fieldLabel)}</span>
          <input
            id="app.boards.create.input"
            className={styles.fieldInput}
            data-testid="app.boards.create.input"
            value={value}
            onChange={(event) => {
              onChange(event.target.value);
            }}
            placeholder={t(keys.boards.create.placeholder)}
            disabled={isBusy}
          />
        </label>
        <div className={styles.modalActions}>
          <Button type="button" variant="neutral" data-testid="app.boards.create.cancel" disabled={isBusy} onClick={onCancel}>
            {t(keys.boards.create.cancel)}
          </Button>
          <Button type="button" variant="primary" data-testid="app.boards.create.submit" disabled={isBusy} onClick={onSubmit}>
            {t(keys.boards.create.submit)}
          </Button>
        </div>
      </div>
    </div>
  );
}

type EditBoardModalProps = {
  onOpenRename: () => void;
  onCancel: () => void;
};

export function EditBoardModal({ onOpenRename, onCancel }: EditBoardModalProps) {
  return (
    <div className={styles.modalBackdrop} data-testid="app.boards.edit.modal.backdrop">
      <div
        className={styles.modal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="app.boards.edit.modal.title"
        data-testid="app.boards.edit.modal"
      >
        <h2 id="app.boards.edit.modal.title" className={styles.modalTitle}>
          {t(keys.boards.edit.title)}
        </h2>
        <div className={styles.modalActions}>
          <Button type="button" variant="neutral" data-testid="app.boards.rename.open" onClick={onOpenRename}>
            {t(keys.boards.rename.button)}
          </Button>
          <Button type="button" variant="neutral" data-testid="app.boards.edit.cancel" onClick={onCancel}>
            {t(keys.boards.edit.cancel)}
          </Button>
        </div>
      </div>
    </div>
  );
}

type RenameBoardModalProps = {
  isBusy: boolean;
  value: string;
  onChange: (value: string) => void;
  onCancel: () => void;
  onSubmit: () => void;
};

export function RenameBoardModal({ isBusy, value, onChange, onCancel, onSubmit }: RenameBoardModalProps) {
  return (
    <div className={styles.modalBackdrop} data-testid="app.boards.rename.modal.backdrop">
      <div
        className={styles.modal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="app.boards.rename.modal.title"
        data-testid="app.boards.rename.modal"
      >
        <h2 id="app.boards.rename.modal.title" className={styles.modalTitle}>
          {t(keys.boards.rename.title)}
        </h2>
        <label className={styles.fieldWrap} htmlFor="app.boards.rename.input">
          <span className={styles.fieldLabel}>{t(keys.boards.rename.fieldLabel)}</span>
          <input
            id="app.boards.rename.input"
            className={styles.fieldInput}
            data-testid="app.boards.rename.input"
            value={value}
            onChange={(event) => {
              onChange(event.target.value);
            }}
            placeholder={t(keys.boards.rename.placeholder)}
            disabled={isBusy}
          />
        </label>
        <div className={styles.modalActions}>
          <Button type="button" variant="neutral" data-testid="app.boards.rename.cancel" disabled={isBusy} onClick={onCancel}>
            {t(keys.boards.rename.cancel)}
          </Button>
          <Button type="button" variant="primary" data-testid="app.boards.rename.submit" disabled={isBusy} onClick={onSubmit}>
            {t(keys.boards.rename.submit)}
          </Button>
        </div>
      </div>
    </div>
  );
}

type CreateColumnModalProps = {
  isBusy: boolean;
  value: string;
  onChange: (value: string) => void;
  onCancel: () => void;
  onSubmit: () => void;
};

export function CreateColumnModal({ isBusy, value, onChange, onCancel, onSubmit }: CreateColumnModalProps) {
  return (
    <div className={styles.modalBackdrop} data-testid="app.columns.create.modal.backdrop">
      <div
        className={styles.modal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="app.columns.create.modal.title"
        data-testid="app.columns.create.modal"
      >
        <h2 id="app.columns.create.modal.title" className={styles.modalTitle}>
          {t(keys.columns.create.title)}
        </h2>
        <label className={styles.fieldWrap} htmlFor="app.columns.create.input">
          <span className={styles.fieldLabel}>{t(keys.columns.create.fieldLabel)}</span>
          <input
            id="app.columns.create.input"
            className={styles.fieldInput}
            data-testid="app.columns.create.input"
            value={value}
            onChange={(event) => {
              onChange(event.target.value);
            }}
            placeholder={t(keys.columns.create.placeholder)}
            disabled={isBusy}
          />
        </label>
        <div className={styles.modalActions}>
          <Button type="button" variant="neutral" data-testid="app.columns.create.cancel" disabled={isBusy} onClick={onCancel}>
            {t(keys.columns.create.cancel)}
          </Button>
          <Button type="button" variant="primary" data-testid="app.columns.create.submit" disabled={isBusy} onClick={onSubmit}>
            {t(keys.columns.create.submit)}
          </Button>
        </div>
      </div>
    </div>
  );
}

type CreateTaskModalProps = {
  isBusy: boolean;
  title: string;
  description: string;
  onChangeTitle: (value: string) => void;
  onChangeDescription: (value: string) => void;
  onCancel: () => void;
  onSubmit: () => void;
};

export function CreateTaskModal({
  isBusy,
  title,
  description,
  onChangeTitle,
  onChangeDescription,
  onCancel,
  onSubmit,
}: CreateTaskModalProps) {
  return (
    <div className={styles.modalBackdrop} data-testid="app.tasks.create.modal.backdrop">
      <div
        className={styles.modal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="app.tasks.create.modal.title"
        data-testid="app.tasks.create.modal"
      >
        <h2 id="app.tasks.create.modal.title" className={styles.modalTitle}>
          {t(keys.tasks.create.title)}
        </h2>
        <div className={styles.fieldWrap}>
          <input
            id="app.tasks.create.title"
            className={styles.fieldInput}
            data-testid="app.tasks.create.title"
            aria-label={t(keys.tasks.create.titleAriaLabel)}
            value={title}
            onChange={(event) => {
              onChangeTitle(event.target.value);
            }}
            placeholder={t(keys.tasks.create.titlePlaceholder)}
            disabled={isBusy}
          />
          <textarea
            id="app.tasks.create.description"
            className={styles.fieldInput}
            data-testid="app.tasks.create.description"
            aria-label={t(keys.tasks.create.descriptionAriaLabel)}
            value={description}
            onChange={(event) => {
              onChangeDescription(event.target.value);
            }}
            placeholder={t(keys.tasks.create.descriptionPlaceholder)}
            disabled={isBusy}
            rows={4}
          />
        </div>
        <div className={styles.modalActions}>
          <Button type="button" variant="neutral" data-testid="app.tasks.create.cancel" disabled={isBusy} onClick={onCancel}>
            {t(keys.tasks.create.cancel)}
          </Button>
          <Button type="button" variant="primary" data-testid="app.tasks.create.submit" disabled={isBusy} onClick={onSubmit}>
            {t(keys.tasks.create.submit)}
          </Button>
        </div>
      </div>
    </div>
  );
}

type DeleteColumnModalProps = {
  isBusy: boolean;
  columnTitle: string;
  onCancel: () => void;
  onSubmit: () => void;
};

export function DeleteColumnModal({ isBusy, columnTitle, onCancel, onSubmit }: DeleteColumnModalProps) {
  return (
    <div className={styles.modalBackdrop} data-testid="app.columns.delete.modal.backdrop">
      <div
        className={styles.modal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="app.columns.delete.modal.title"
        data-testid="app.columns.delete.modal"
      >
        <h2 id="app.columns.delete.modal.title" className={styles.modalTitle}>
          {t(keys.columns.delete.title)}
        </h2>
        <Text>{t(keys.columns.delete.confirm, { title: columnTitle })}</Text>
        <div className={styles.modalActions}>
          <Button type="button" variant="neutral" data-testid="app.columns.delete.cancel" disabled={isBusy} onClick={onCancel}>
            {t(keys.columns.delete.cancel)}
          </Button>
          <Button type="button" variant="primary" data-testid="app.columns.delete.submit" disabled={isBusy} onClick={onSubmit}>
            {t(keys.columns.delete.submit)}
          </Button>
        </div>
      </div>
    </div>
  );
}

type DeleteTaskModalProps = {
  isBusy: boolean;
  taskTitle: string;
  onCancel: () => void;
  onSubmit: () => void;
};

export function DeleteTaskModal({ isBusy, taskTitle, onCancel, onSubmit }: DeleteTaskModalProps) {
  return (
    <div className={styles.modalBackdrop} data-testid="app.tasks.delete.modal.backdrop">
      <div
        className={styles.modal}
        role="dialog"
        aria-modal="true"
        aria-labelledby="app.tasks.delete.modal.title"
        data-testid="app.tasks.delete.modal"
      >
        <h2 id="app.tasks.delete.modal.title" className={styles.modalTitle}>
          {t(keys.tasks.delete.title)}
        </h2>
        <Text>{t(keys.tasks.delete.confirm, { title: taskTitle })}</Text>
        <div className={styles.modalActions}>
          <Button type="button" variant="neutral" data-testid="app.tasks.delete.cancel" disabled={isBusy} onClick={onCancel}>
            {t(keys.tasks.delete.cancel)}
          </Button>
          <Button type="button" variant="primary" data-testid="app.tasks.delete.submit" disabled={isBusy} onClick={onSubmit}>
            {t(keys.tasks.delete.submit)}
          </Button>
        </div>
      </div>
    </div>
  );
}
