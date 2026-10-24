import type { BackendApi } from "@/lib/backend/api";
import { OfflineError, isAbortError } from "@/lib/backend/errors";
import type { Message } from "@/lib/domain/types";
import { saveMessage } from "@/lib/repositories/messages";
import { touchConversation } from "@/lib/repositories/conversations";
import { streamChatTurn } from "./reply";
import { Throttler } from "./throttler";
import {
  type GenStatus,
  type ReplyRequest,
  ReplyError,
  type ReplySettings,
  type ServerTurnInfo,
} from "./types";

// Orchestrates one chat turn against the server, writing streamed text into a
// message store through a 60ms throttle. Transient state only (status, the
// active reply, errors, free replies left) — the message list lives in the
// store the UI owns. Framework-agnostic port of ChatController.

/** The conversation's message list, owned by the UI (React state / store). */
export interface ConversationStore {
  getMessages(): Message[];
  setMessages(messages: Message[]): void;
}

export interface ChatControllerConfig {
  api: BackendApi;
  conversationId: string;
  store: ConversationStore;
  modelId: string;
  personaId: string;
  settings: ReplySettings;
  /** False when animations are off: the reply arrives whole at the end. */
  stream: boolean;
  /** Relationship snapshots / usage reported by the server during a turn. */
  onInfo?(info: ServerTurnInfo): void;
}

export interface ChatState {
  status: GenStatus;
  /** The reply currently being written, or null. */
  activeId: string | null;
  error: ReplyError | OfflineError | null;
  /** Free replies left today for the selected model (null = no limit). */
  freeRepliesLeft: number | null;
}

interface GenerateOpts {
  userMessageId?: string;
  /** Rewrite: the existing AI message to add an alt to. */
  aiMessageId?: string;
  altIndex?: number;
  replaceMessageId?: string;
}

const uuid = () => crypto.randomUUID();

export class ChatController {
  private cfg: ChatControllerConfig;
  private state: ChatState = {
    status: "idle",
    activeId: null,
    error: null,
    freeRepliesLeft: null,
  };
  private readonly listeners = new Set<(s: ChatState) => void>();
  private readonly throttle = new Throttler(60);
  private readonly stoppedIds = new Set<string>();
  private abort: AbortController | null = null;

  constructor(config: ChatControllerConfig) {
    this.cfg = config;
  }

  // ── state / subscription ──────────────────────────────────────────────
  getState(): ChatState {
    return this.state;
  }

  subscribe(fn: (s: ChatState) => void): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  /** Update model / settings / persona / stream without recreating. */
  configure(patch: Partial<ChatControllerConfig>): void {
    this.cfg = { ...this.cfg, ...patch };
  }

  private set(patch: Partial<ChatState>): void {
    this.state = { ...this.state, ...patch };
    for (const l of this.listeners) l(this.state);
  }

  // ── message helpers ───────────────────────────────────────────────────
  private get messages(): Message[] {
    return this.cfg.store.getMessages();
  }

  private setMessages(messages: Message[]): void {
    this.cfg.store.setMessages(messages);
  }

  private updateMessage(id: string, fn: (m: Message) => Message): void {
    this.setMessages(this.messages.map((m) => (m.id === id ? fn(m) : m)));
  }

  private writeAlt(id: string, index: number, text: string): void {
    this.updateMessage(id, (m) => {
      const alts = [...m.alts];
      while (alts.length <= index) alts.push("");
      alts[index] = text;
      return { ...m, alts, altIndex: index };
    });
  }

  private altText(id: string, index: number): string {
    return this.messages.find((m) => m.id === id)?.alts[index] ?? "";
  }

  // ── public actions ────────────────────────────────────────────────────
  /** Send a user message and generate the reply. */
  async send(text: string): Promise<void> {
    const trimmed = text.trim();
    if (!trimmed || this.state.status !== "idle") return;
    const userMsg: Message = {
      id: uuid(),
      role: "user",
      alts: [trimmed],
      altIndex: 0,
      notes: {},
    };
    this.setMessages([...this.messages, userMsg]);
    // Flush the user message before the turn; the server reads it by id.
    await saveMessage(this.cfg.api, userMsg, this.cfg.conversationId);
    await touchConversation(this.cfg.api, this.cfg.conversationId);
    await this.generate({ userMessageId: userMsg.id });
  }

  /** Story "Continue": generate without a new user message. */
  async continueStory(): Promise<void> {
    if (this.state.status !== "idle") return;
    await this.generate({});
  }

  /** Rewrite the latest AI reply as a new alternate. */
  async rewrite(): Promise<void> {
    if (this.state.status !== "idle") return;
    const last = [...this.messages].reverse().find((m) => m.role === "ai");
    if (!last) return;
    const newIndex = last.alts.length;
    this.updateMessage(last.id, (m) => ({
      ...m,
      alts: [...m.alts, ""],
      altIndex: newIndex,
    }));
    await this.generate({
      aiMessageId: last.id,
      altIndex: newIndex,
      replaceMessageId: last.id,
    });
  }

  /** Retry after an error: regenerate answering the last user message. */
  async retry(): Promise<void> {
    if (this.state.status !== "idle") return;
    this.set({ error: null });
    const lastUser = [...this.messages].reverse().find((m) => m.role === "user");
    await this.generate({ userMessageId: lastUser?.id });
  }

  /** Stop generation: closes the connection so the server stops the model. */
  stop(): void {
    this.abort?.abort();
  }

  /** Switch which alternate of a reply is shown. */
  setAlt(messageId: string, index: number): void {
    this.updateMessage(messageId, (m) => ({
      ...m,
      altIndex: Math.max(0, Math.min(index, m.alts.length - 1)),
    }));
  }

  /** Edit a user message's text and persist it. */
  async edit(messageId: string, text: string): Promise<void> {
    this.updateMessage(messageId, (m) => ({ ...m, alts: [text] }));
    const m = this.messages.find((x) => x.id === messageId);
    if (m) await saveMessage(this.cfg.api, m, this.cfg.conversationId);
  }

  // ── generation ────────────────────────────────────────────────────────
  private async generate(opts: GenerateOpts): Promise<void> {
    const aiId = opts.aiMessageId ?? uuid();
    const altIndex = opts.altIndex ?? 0;
    const isRewrite = Boolean(opts.aiMessageId);

    if (!isRewrite) {
      const placeholder: Message = {
        id: aiId,
        role: "ai",
        alts: [""],
        altIndex: 0,
        notes: {},
      };
      this.setMessages([...this.messages, placeholder]);
    }

    this.set({ status: "thinking", activeId: aiId, error: null });
    this.abort = new AbortController();
    let gotText = false;

    const request: ReplyRequest = {
      conversationId: this.cfg.conversationId,
      personaId: this.cfg.personaId,
      modelId: this.cfg.modelId,
      aiMessageId: aiId,
      altIndex,
      settings: this.cfg.settings,
      userMessageId: opts.userMessageId ?? null,
      replaceMessageId: opts.replaceMessageId ?? null,
      stream: this.cfg.stream,
    };

    try {
      await streamChatTurn(
        this.cfg.api,
        request,
        {
          onServerInfo: (info) => {
            if (info.freeRepliesLeft != null) {
              this.set({ freeRepliesLeft: info.freeRepliesLeft });
            }
            if (info.userNote && opts.userMessageId) {
              const userNote = info.userNote;
              this.updateMessage(opts.userMessageId, (m) => ({
                ...m,
                notes: { ...m.notes, 0: userNote },
              }));
            }
            if (info.replyNote) {
              const replyNote = info.replyNote;
              this.updateMessage(aiId, (m) => ({
                ...m,
                notes: { ...m.notes, [altIndex]: replyNote },
              }));
            }
            this.cfg.onInfo?.(info);
          },
          onText: (cumulative) => {
            gotText = true;
            if (this.state.status !== "streaming") this.set({ status: "streaming" });
            this.throttle.run(() => this.writeAlt(aiId, altIndex, cumulative));
          },
        },
        this.abort.signal,
      );
      this.throttle.flush();
      this.set({ status: "idle", activeId: null });
    } catch (e) {
      this.throttle.flush();
      if (isAbortError(e)) {
        this.stoppedIds.add(aiId);
        if (!gotText) {
          this.removePlaceholder(aiId, isRewrite);
        } else {
          // Keep the partial text with an ellipsis (prototype behaviour).
          this.writeAlt(aiId, altIndex, `${this.altText(aiId, altIndex)} …`);
        }
        this.set({ status: "idle", activeId: null });
        return;
      }
      if (!gotText) this.removePlaceholder(aiId, isRewrite);
      const err =
        e instanceof ReplyError || e instanceof OfflineError ? e : new OfflineError();
      this.set({ status: "idle", activeId: null, error: err });
    } finally {
      this.abort = null;
    }
  }

  /** Nothing was written: drop the empty reply (or the empty rewrite alt). */
  private removePlaceholder(aiId: string, isRewrite: boolean): void {
    if (isRewrite) {
      this.updateMessage(aiId, (m) => {
        const alts = m.alts.slice(0, -1);
        return {
          ...m,
          alts: alts.length ? alts : [""],
          altIndex: Math.max(0, alts.length - 1),
        };
      });
    } else {
      this.setMessages(this.messages.filter((m) => m.id !== aiId));
    }
  }

  wasStopped(messageId: string): boolean {
    return this.stoppedIds.has(messageId);
  }

  dispose(): void {
    this.throttle.cancel();
    this.abort?.abort();
    this.listeners.clear();
  }
}
