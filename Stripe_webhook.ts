// Supabase > Edge Functions > New function "stripe-webhook" (désactiver "Verify JWT")
// Secrets à créer : STRIPE_KEY, STRIPE_WHSEC (SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY existent déjà)
import Stripe from "https://esm.sh/stripe@14?target=denonext";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const stripe = new Stripe(Deno.env.get("STRIPE_KEY")!, { apiVersion: "2024-06-20" });
Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature")!, body = await req.text();
  let ev;
  try { ev = await stripe.webhooks.constructEventAsync(body, sig, Deno.env.get("STRIPE_WHSEC")!); }
  catch { return new Response("signature invalide", { status: 400 }); }
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  if (ev.type === "checkout.session.completed") {
    const s: any = ev.data.object;
    await sb.from("entitlements").upsert({ user_id: s.client_reference_id, premium: true, stripe_customer: s.customer, updated_at: new Date().toISOString() });
  }
  if (ev.type === "customer.subscription.deleted") {
    const sub: any = ev.data.object;
    await sb.from("entitlements").update({ premium: false }).eq("stripe_customer", sub.customer);
  }
  return new Response("ok");
});
