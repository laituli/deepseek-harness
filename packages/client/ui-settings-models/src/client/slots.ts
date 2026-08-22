/**
 * The Models page's provider-editor slot: a keyed slot (key = provider route
 * id) rendered around every provider card's editor, with the generic
 * `ProviderEditor` as the fallback. A provider plugin registers an occupant
 * for its own route id to replace the generic editor with a custom one — the
 * Ollama setup form does this. Absent an occupant, the generic editor renders
 * unchanged, so this slot adds no behavior for DeepSeek or pi-ai routes.
 * @module @deepseek-ai/dsh-client-ui-settings-models/client/slots
 */

import type { SlotMap } from '@deepseek-ai/dsh-client-ui-slots'

declare module '@deepseek-ai/dsh-client-ui-slots' {
  interface SlotMap {
    /** Owner props handed to a provider's custom editor on the Models page. */
    'settings.models.provider-editor': {
      kind: 'keyed'
      scope: 'root'
      owner: { provider: string; displayName: string }
    }
  }
}

/** The keyed-slot map entry type, for consumers that import it. */
export type ModelsProviderEditorSlot = SlotMap['settings.models.provider-editor']
