import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Privacy Policy", description: "SolutionTee CBT Privacy Policy." };

export default function Page() {
  return <LegalPage name="privacy" />;
}
