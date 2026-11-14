import createClient, { type Middleware } from 'openapi-fetch';
import type { components, paths } from './schema';
import { API_URL } from '../config';
import { useSession } from '../store/session';

// schema.d.ts is generated from api/openapi.yaml (`npm run gen:api`); never edit it by hand.
export type Schemas = components['schemas'];
export type Order = Schemas['Order'];
export type BookSnapshot = Schemas['BookSnapshot'];
export type Trade = Schemas['Trade'];
export type Instrument = Schemas['Instrument'];
export type Problem = Schemas['Problem'];

const auth: Middleware = {
  onRequest({ request }) {
    const token = useSession.getState().token;
    if (token) request.headers.set('Authorization', `Bearer ${token}`);
    return request;
  },
};

export const api = createClient<paths>({ baseUrl: `${API_URL}/api/v1` });
api.use(auth);

export class ApiError extends Error {
  constructor(public readonly code: string) {
    super(code);
  }
}

export function unwrap<T>(r: { data?: T; error?: unknown }): T {
  if (r.error !== undefined || r.data === undefined) {
    throw new ApiError((r.error as Problem | undefined)?.code ?? 'BAD_REQUEST');
  }
  return r.data;
}

/** Network failures become NETWORK so the UI can say "server unreachable". */
export async function call<T>(p: Promise<{ data?: T; error?: unknown }>): Promise<T> {
  try {
    return unwrap(await p);
  } catch (e) {
    throw e instanceof ApiError ? e : new ApiError('NETWORK');
  }
}
