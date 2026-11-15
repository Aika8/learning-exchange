import createClient, { type Middleware } from 'openapi-fetch';
import type { components, paths } from './schema';
import { API_URL } from '../config';

// Generated types (schema.d.ts) come from api/openapi.yaml: `npm run gen:api`. Never edit them by hand.
export type Schemas = components['schemas'];
export type Order = Schemas['Order'];
export type BookSnapshot = Schemas['BookSnapshot'];
export type Trade = Schemas['Trade'];
export type Instrument = Schemas['Instrument'];
export type AccountDetails = Schemas['AccountDetails'];
export type Clock = Schemas['Clock'];
export type Problem = Schemas['Problem'];
export type ConditionalOrder = Schemas['ConditionalOrder'];
export type ConditionalKind = Schemas['ConditionalKind'];
export type ConditionalState = Schemas['ConditionalState'];
export type MarginPosition = Schemas['MarginPosition'];
export type SavingsOverview = Schemas['SavingsOverview'];
export type Statement = Schemas['Statement'];
export type AccountChanged = Schemas['AccountChanged'];

let token: string | null = sessionStorage.getItem('token');

export function setToken(t: string | null) {
  token = t;
  if (t) sessionStorage.setItem('token', t);
  else sessionStorage.removeItem('token');
}

export function getToken() {
  return token;
}

const auth: Middleware = {
  onRequest({ request }) {
    if (token) request.headers.set('Authorization', `Bearer ${token}`);
    return request;
  },
};

export const api = createClient<paths>({ baseUrl: `${API_URL}/api/v1` });
api.use(auth);

/** Error carrying the contract's Problem code, so the UI can translate it. */
export class ApiError extends Error {
  constructor(public readonly code: string) {
    super(code);
  }
}

export function unwrap<T>(r: { data?: T; error?: unknown }): T {
  if (r.error !== undefined || r.data === undefined) {
    const code = (r.error as Problem | undefined)?.code ?? 'BAD_REQUEST';
    throw new ApiError(code);
  }
  return r.data;
}
