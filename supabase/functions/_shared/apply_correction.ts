// apply_correction: everything you can do to a relationship from the journal.
//
//   { action, relationshipId, ... }
//   undo               { eventId }
//   accept_suggestion  { suggestionId }          dismiss_suggestion { suggestionId }
//   correct            { values: {trust, affection, attraction, tension}, reason? }
//   set_type           { type }                  set_pacing         { pacing }
//   apply_preset       { presetId }              save_stages        { names[], current, lock }
//   set_starting_point { startingPoint }         start over as Just met / Friends / Together…
//   add_fact           { text, locked }          set_fact_locked    { factId, locked }
//   remove_fact        { factId }
//   reevaluate_message { messageId }    you edited a message; judge the new text
//   recount_proposal   { messageId, altIndex }  you switched back to a version of a reply
//
// The app can only ask. The engine decides, and the numbers are never taken
// from the request except in `correct` (your own correction, clamped to 0–100).
import { RelationshipEngine } from './engine/engine.ts';
import { presetById, STAGE_PRESETS } from './engine/bands.ts';
import {
  PACINGS,
  RELATION_TYPES,
  STARTING_POINTS,
  relationshipToJson,
  type Relationship,
  type RelationshipNote,
} from './engine/models.ts';
import { mutate } from './mutate.ts';
import { NotFoundError, type Store } from './store.ts';
import { BadRequestError, bool, int, obj, oneOf, optText, text, uuid } from './validate.ts';
import { errorResponse, jsonResponse } from './chat_turn.ts';

export interface CorrectionDeps {
  store: Store;
  engine: RelationshipEngine;
  now: () => Date;
}

const round1 = (v: number): number => Math.round(v * 10) / 10;

function number0to100(v: unknown, field: string): number {
  if (typeof v !== 'number' || !Number.isFinite(v)) throw new BadRequestError('bad_request', `${field} must be a number`);
  return round1(Math.min(100, Math.max(0, v)));
}

export async function handleApplyCorrection(body: unknown, userId: string, deps: CorrectionDeps): Promise<Response> {
  try {
    const b = obj(body);
    const action = text(b.action, 'action', 40, { min: 1 });
    const relationshipId = uuid(b.relationshipId, 'relationshipId');
    const { store, engine } = deps;
    const now = deps.now();
    let note: RelationshipNote | null = null;
    let apply: (r: Relationship) => Relationship;

    switch (action) {
      case 'undo': {
        const eventId = uuid(b.eventId, 'eventId');
        const reason = optText(b.reason, 'reason', 300);
        apply = (r) => engine.undo(r, eventId, { now, reason: reason?.trim() === '' ? null : reason });
        break;
      }
      case 'accept_suggestion': {
        const id = uuid(b.suggestionId, 'suggestionId');
        apply = (r) => engine.acceptSuggestion(r, id, { now });
        break;
      }
      case 'dismiss_suggestion': {
        const id = uuid(b.suggestionId, 'suggestionId');
        apply = (r) => engine.dismissSuggestion(r, id);
        break;
      }
      case 'correct': {
        const v = obj(b.values, 'values');
        const target = {
          trust: number0to100(v.trust, 'trust'),
          affection: number0to100(v.affection, 'affection'),
          attraction: number0to100(v.attraction, 'attraction'),
          tension: number0to100(v.tension, 'tension'),
        };
        const reason = optText(b.reason, 'reason', 200);
        apply = (r) => engine.applyCorrection(r, target, { now, reason: reason ?? null });
        break;
      }
      case 'set_type': {
        const t = oneOf(b.type, RELATION_TYPES, 'type');
        apply = (r) => engine.setType(r, t);
        break;
      }
      case 'set_pacing': {
        const p = oneOf(b.pacing, PACINGS, 'pacing');
        apply = (r) => engine.setPacing(r, p);
        break;
      }
      case 'apply_preset': {
        const id = oneOf(b.presetId, STAGE_PRESETS.map((p) => p.id), 'presetId');
        apply = (r) => engine.applyPreset(r, presetById(id));
        break;
      }
      case 'set_starting_point': {
        const start = oneOf(b.startingPoint, STARTING_POINTS, 'startingPoint');
        apply = (r) => engine.applyStartingPoint(r, start, { now });
        break;
      }
      case 'save_stages': {
        if (!Array.isArray(b.names) || b.names.length > 6) throw new BadRequestError('bad_request', 'names must be a list of up to 6');
        const names = b.names.map((n, i) => text(n, `names[${i}]`, 40, { trim: false }));
        const current = int(b.current, 'current', 0, 5);
        const lock = bool(b.lock, 'lock');
        apply = (r) => engine.saveStages(r, names, current, lock, { now });
        break;
      }
      case 'add_fact': {
        const t = text(b.text, 'text', 300, { min: 1 });
        const locked = b.locked === undefined ? true : bool(b.locked, 'locked');
        apply = (r) => engine.addFact(r, t, { locked });
        break;
      }
      case 'set_fact_locked': {
        const id = uuid(b.factId, 'factId');
        const locked = bool(b.locked, 'locked');
        apply = (r) => engine.setFactLocked(r, id, locked);
        break;
      }
      case 'remove_fact': {
        const id = uuid(b.factId, 'factId');
        apply = (r) => engine.removeFact(r, id);
        break;
      }
      case 'reevaluate_message': {
        const messageId = uuid(b.messageId, 'messageId');
        const msg = await store.loadMessage(userId, messageId);
        if (msg === null || msg.role !== 'user') throw new NotFoundError('message');
        const turnText = msg.alts[Math.min(msg.altIndex, msg.alts.length - 1)] ?? '';
        const out = await mutate(store, userId, relationshipId, (r) => {
          const o = engine.reevaluateEdited(r, {
            messageId,
            text: turnText,
            now,
            conversationId: msg.conversationId,
            chatTitle: msg.title,
          });
          return { next: o.relationship, result: o.kind === 'ignored' ? null : o.note };
        });
        return jsonResponse(200, { relationship: relationshipToJson(out.relationship), note: out.result });
      }
      case 'recount_proposal': {
        const messageId = uuid(b.messageId, 'messageId');
        const altIndex = int(b.altIndex, 'altIndex', 0, 50);
        const proposal = await store.loadProposal(userId, messageId, altIndex);
        const msg = await store.loadMessage(userId, messageId);
        if (proposal === null || msg === null || proposal.relationshipId !== relationshipId) {
          // Nothing the model proposed for that version: nothing to count.
          const r = await store.loadRelationship(userId, relationshipId);
          if (r === null) throw new NotFoundError('relationship');
          return jsonResponse(200, { relationship: relationshipToJson(r), note: null });
        }
        const info = await store.conversationCharacter(userId, msg.conversationId);
        const thread = await store.loadThread(userId, msg.conversationId);
        const before = thread.slice(0, thread.findIndex((m) => m.id === messageId));
        const recent = [...before.map((m) => m.alts[Math.min(m.altIndex, m.alts.length - 1)] ?? ''), msg.alts[Math.min(altIndex, msg.alts.length - 1)] ?? ''];
        const out = await mutate(store, userId, relationshipId, (r) => {
          const o = engine.processModelProposal(
            r,
            {
              kindId: proposal.kind,
              evidence: proposal.evidence,
              reason: proposal.reason,
              messageId,
              recentMessages: recent,
              now,
              conversationId: msg.conversationId,
              chatTitle: msg.title,
            },
            { characterFirst: info?.first ?? 'They' },
          );
          return { next: o.relationship, result: o.kind === 'ignored' ? null : o.note };
        });
        return jsonResponse(200, { relationship: relationshipToJson(out.relationship), note: out.result });
      }
      default:
        throw new BadRequestError('unknown_action', `unknown action ${action}`);
    }

    const out = await mutate(store, userId, relationshipId, (r) => ({ next: apply(r), result: null }));
    return jsonResponse(200, { relationship: relationshipToJson(out.relationship), note });
  } catch (e) {
    if (e instanceof BadRequestError) return errorResponse(400, e.code, e.message);
    if (e instanceof NotFoundError) return errorResponse(404, 'not_found', 'Not found.');
    console.error('apply_correction', e);
    return errorResponse(500, 'server_error', 'Something went wrong on our side. Try again.');
  }
}
