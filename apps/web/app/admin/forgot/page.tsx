import type { Metadata } from "next";
import { AuthFrame } from "@/components/admin/auth-frame";
import { ForgotForm } from "./forgot-form";

export const metadata: Metadata = { title: "Reset admin password" };

export default function Page() {
  return (
    <AuthFrame title="Reset your password" subtitle="We email you a code. Enter it with a new password, then confirm with your authenticator app as usual.">
      <ForgotForm />
    </AuthFrame>
  );
}
