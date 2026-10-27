"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowCounterClockwise } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { undoImport } from "./actions";

export function UndoButton({ id, rows }: { id: string; rows: number }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <Button size="sm" variant="outline" disabled={pending}
      onClick={() => {
        if (!confirm(`Undo this import? Its ${rows} question(s) will be removed from the bank.`)) return;
        start(async () => {
          const r = await undoImport(id);
          if (r.ok) { toast.success(`Import undone. ${r.data} question(s) removed.`); router.refresh(); } else toast.error(r.error);
        });
      }}>
      <ArrowCounterClockwise size={16} /> Undo
    </Button>
  );
}
