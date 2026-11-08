import type { Metadata } from "next";
import { Shot } from "./shot";

export const metadata: Metadata = { title: "Store image", robots: { index: false, follow: false } };

export function generateStaticParams() {
  return ["1", "2", "3", "4", "5", "feature", "icon"].map((shot) => ({ shot }));
}

/** /store-kit/<n>: one Google Play store image at its real size (see docs/play-console). */
export default async function Page({ params }: { params: Promise<{ shot: string }> }) {
  const { shot } = await params;
  return <Shot id={shot} />;
}
