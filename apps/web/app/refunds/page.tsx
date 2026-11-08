import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Refund Policy", description: "SolutionTee CBT Refund Policy." };

export default function Page() {
  return <LegalPage name="refunds" />;
}
