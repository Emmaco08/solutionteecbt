import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";

export const metadata: Metadata = { title: "Terms of Service", description: "SolutionTee CBT Terms of Service." };

export default function Page() {
  return <LegalPage name="terms" />;
}
