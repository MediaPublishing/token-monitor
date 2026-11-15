import Foundation

enum ClaudeUsageAPI {
    // Executed in the same account's isolated WebKit world. Only this projection
    // crosses back to Swift; organization IDs and raw responses stay in-page.
    static let script = #"""
    let stage = 'origin';
    let status = null;
    const result = (outcome, extra = {}) => JSON.stringify({outcome, stage, httpStatus: status, ...extra});
    if (!['https://claude.ai', 'https://www.claude.ai'].includes(location.origin)) {
      return result('untrustedOrigin');
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    const getJSON = async (path) => {
      status = null;
      const response = await fetch(location.origin + path, {method: 'GET', credentials: 'same-origin',
        cache: 'no-store', redirect: 'error', headers: {Accept: 'application/json'}, signal: controller.signal});
      status = response.status;
      if (response.headers.get('cf-mitigated') === 'challenge') throw 'challenge';
      if (status === 401) throw 'unauthorized';
      if (status === 403) throw 'forbidden';
      if (status === 429) throw 'rateLimited';
      if (status !== 200 || !/application\/json/i.test(response.headers.get('content-type') || '')) throw 'invalidResponse';
      if (!response.body || Number(response.headers.get('content-length')) > 65536) throw 'invalidResponse';
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let text = '', size = 0;
      try {
        while (true) {
          const {value, done} = await reader.read();
          if (done) break;
          size += value.byteLength;
          if (size > 65536) { await reader.cancel(); throw 'invalidResponse'; }
          text += decoder.decode(value, {stream: true});
        }
        text += decoder.decode();
        return JSON.parse(text);
      } catch (error) {
        if (error === 'invalidResponse') throw error;
        if (controller.signal.aborted) throw 'timedOut';
        throw 'invalidResponse';
      } finally { reader.releaseLock(); }
    };
    try {
      stage = 'organizations';
      const organizations = await getJSON('/api/organizations');
      if (!Array.isArray(organizations) || organizations.length > 100) throw 'invalidResponse';
      const valid = organizations.filter(org => org && typeof org.uuid === 'string'
        && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(org.uuid));
      if (valid.length !== organizations.length) throw 'invalidResponse';
      const chat = valid.filter(org => Array.isArray(org.capabilities) && org.capabilities.includes('chat'));
      const candidates = chat.length ? chat : valid.filter(org => org.capabilities == null
        || (Array.isArray(org.capabilities) && org.capabilities.length === 0));
      if (candidates.length > 1) throw 'ambiguousWorkspace';
      if (candidates.length !== 1) throw 'noWorkspace';
      stage = 'usage';
      const usage = await getJSON('/api/organizations/' + encodeURIComponent(candidates[0].uuid) + '/usage');
      if (!usage || typeof usage !== 'object' || Array.isArray(usage)) throw 'invalidResponse';
      if (usage.error != null || usage.type === 'error') throw 'invalidResponse';
      const specs = [['five_hour', 'session'], ['seven_day', 'weekly'],
        ['seven_day_sonnet', 'sonnet'], ['seven_day_opus', 'opus'], ['seven_day_fable', 'fable']];
      const windows = [];
      for (const [key, scope] of specs) {
        const window = usage[key];
        if (window == null) continue;
        if (typeof window !== 'object' || Array.isArray(window) || typeof window.utilization !== 'number'
            || !Number.isFinite(window.utilization) || window.utilization < 0 || window.utilization > 100) throw 'invalidResponse';
        let resetsAt = null;
        if (window.resets_at != null) {
          if (typeof window.resets_at !== 'string' || window.resets_at.length > 40
              || !/^\d{4}-\d{2}-\d{2}T/.test(window.resets_at) || !Number.isFinite(Date.parse(window.resets_at))) throw 'invalidResponse';
          resetsAt = new Date(window.resets_at).toISOString();
        }
        windows.push({scope, used: window.utilization, resetsAt});
      }
      if (windows.length) return result('available', {windows});
      if (Object.hasOwn(usage, 'five_hour') && Object.hasOwn(usage, 'seven_day')
          && usage.five_hour === null && usage.seven_day === null) {
        return result('notReported', {confirmedEmpty: true, windows: []});
      }
      throw 'invalidResponse';
    } catch (error) {
      const allowed = ['unauthorized', 'forbidden', 'challenge', 'rateLimited', 'ambiguousWorkspace', 'noWorkspace', 'invalidResponse', 'timedOut'];
      return result(controller.signal.aborted ? 'timedOut' : allowed.includes(error) ? error : 'networkFailure');
    } finally { clearTimeout(timer); }
    """#
}
