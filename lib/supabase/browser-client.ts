import { createBrowserClient } from "@supabase/ssr";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    "Missing NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_ANON_KEY env variable.",
  );
}

/**
 * Module-level singleton Supabase client for the browser.
 *
 * IMPORTANT: never call createBrowserClient() inside a component or hook.
 * A new client per render opens a new Realtime channel on every render,
 * which causes the CLOSED -> SUBSCRIBED reconnect loop. Always import this
 * shared instance instead.
 */
export const supabaseBrowser = createBrowserClient(supabaseUrl, supabaseAnonKey);
