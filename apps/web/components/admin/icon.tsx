"use client";
import {
  Article, Books, Circle, Database, EnvelopeSimple, DeviceMobile, Exam, FileCsv, Gift, IdentificationBadge, Layout, ListChecks,
  MagnifyingGlass, Newspaper, PlusCircle, Ranking, Receipt, Scales, ShieldWarning, SlidersHorizontal, Sparkle, SquaresFour,
  Ticket, ToggleRight, Trophy, Users, Wrench, type IconWeight,
} from "@phosphor-icons/react";

// Only the icons the admin uses, so the bundle stays small.
const ICONS = {
  Article, Books, Database, EnvelopeSimple, DeviceMobile, Exam, FileCsv, Gift, IdentificationBadge, Layout, ListChecks, MagnifyingGlass,
  Newspaper, PlusCircle, Ranking, Receipt, Scales, ShieldWarning, SlidersHorizontal, Sparkle, SquaresFour, Ticket, ToggleRight,
  Trophy, Users, Wrench,
};

export function Icon({ name, size = 18, weight = "regular", className }: { name: string; size?: number; weight?: IconWeight; className?: string }) {
  const Cmp = ICONS[name as keyof typeof ICONS] ?? Circle;
  return <Cmp size={size} weight={weight} className={className} aria-hidden="true" />;
}
