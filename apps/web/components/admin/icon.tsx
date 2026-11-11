"use client";
import {
  Article, BellRinging, Books, Briefcase, ChalkboardTeacher, ChatsCircle, Circle, Medal, Coins, Database, EnvelopeSimple, DeviceMobile, Exam, FileCsv, Gift, IdentificationBadge, Layout, Lightbulb, ListChecks,
  MagnifyingGlass, Megaphone, Newspaper, PlusCircle, Quotes, Ranking, Receipt, Robot, Scales, ShieldWarning, SlidersHorizontal, Sparkle, SquaresFour, Storefront, Strategy,
  GameController, Ticket, ToggleRight, Trophy, Users, Wrench, type IconWeight,
} from "@phosphor-icons/react";

// Only the icons the admin uses, so the bundle stays small.
const ICONS = {
  Article, BellRinging, Books, Briefcase, ChalkboardTeacher, ChatsCircle, Coins, Medal, Database, EnvelopeSimple, DeviceMobile, Exam, FileCsv, Gift, IdentificationBadge, Layout, Lightbulb, ListChecks, MagnifyingGlass,
  Megaphone, Newspaper, PlusCircle, Quotes, Ranking, Receipt, Robot, Scales, ShieldWarning, SlidersHorizontal, Sparkle, SquaresFour, Storefront, Strategy, Ticket, ToggleRight,
  GameController, Trophy, Users, Wrench,
};

export function Icon({ name, size = 18, weight = "regular", className }: { name: string; size?: number; weight?: IconWeight; className?: string }) {
  const Cmp = ICONS[name as keyof typeof ICONS] ?? Circle;
  return <Cmp size={size} weight={weight} className={className} aria-hidden="true" />;
}
