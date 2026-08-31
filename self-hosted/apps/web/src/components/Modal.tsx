import { X } from "lucide-react";
import { useEffect, type PropsWithChildren } from "react";

interface ModalProps extends PropsWithChildren {
  title: string;
  onClose: () => void;
  wide?: boolean;
}

export function Modal({ title, onClose, wide = false, children }: ModalProps) {
  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [onClose]);

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={onClose}>
      <section
        className={`modal${wide ? " is-wide" : ""}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby="modal-title"
        onMouseDown={(event) => event.stopPropagation()}
      >
        <header>
          <h2 id="modal-title">{title}</h2>
          <button className="icon-button" type="button" aria-label="Close" onClick={onClose}><X /></button>
        </header>
        {children}
      </section>
    </div>
  );
}
