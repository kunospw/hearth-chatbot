import type { Session, User } from "@supabase/supabase-js";
import { getBrowserClient } from "@/lib/supabase/client";

// Email sign-in/up/out on the browser client. For a personal app, turn off
// "Confirm email" in Supabase so new accounts can sign in immediately
// (supabase/README.md). Age-gating and the styled sign-in screen live in the
// routes layer.

export async function signIn(email: string, password: string): Promise<User> {
  const { data, error } = await getBrowserClient().auth.signInWithPassword({
    email,
    password,
  });
  if (error) throw error;
  return data.user;
}

export async function signUp(email: string, password: string): Promise<User | null> {
  const { data, error } = await getBrowserClient().auth.signUp({ email, password });
  if (error) throw error;
  return data.user;
}

export async function signOut(): Promise<void> {
  const { error } = await getBrowserClient().auth.signOut();
  if (error) throw error;
}

export async function getSession(): Promise<Session | null> {
  const { data } = await getBrowserClient().auth.getSession();
  return data.session;
}

export async function getUser(): Promise<User | null> {
  const { data } = await getBrowserClient().auth.getUser();
  return data.user;
}

/** Subscribe to auth changes; returns an unsubscribe function. */
export function onAuthChange(cb: (session: Session | null) => void): () => void {
  const { data } = getBrowserClient().auth.onAuthStateChange((_event, session) => {
    cb(session);
  });
  return () => data.subscription.unsubscribe();
}
