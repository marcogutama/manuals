import http from "k6/http";
import { check } from "k6";
import { Trend, Rate, Counter } from "k6/metrics";

// ════════════════════════════════════════════════════════════════════════════
//  PARÁMETROS (variables de entorno)
//
//  K6_ENDPOINT    → URL del endpoint  (requerido)
//  K6_PAYLOAD     → Body JSON string  (opcional, usa DEFAULT_PAYLOAD si no se define)
//  K6_VUS         → Usuarios virtuales / requests paralelos (default: 1)
//  K6_ITERATIONS  → Iteraciones por VU (default: 5)
//  K6_SUCCESS_CODE→ Código de negocio OK en el JSON de respuesta (opcional, ej: "000")
//                   Si se define, se valida que response.body.code === K6_SUCCESS_CODE
//
//  Ejecución típica:
//    1 request secuencial:
//      k6 run -e K6_VUS=1 -e K6_ITERATIONS=5 load_test.js
//
//    5 requests paralelos:
//      k6 run -e K6_VUS=5 -e K6_ITERATIONS=5 load_test.js
//
//    Otro endpoint:
//      k6 run -e K6_ENDPOINT="https://mi-api.com/ruta" \
//             -e K6_VUS=5 -e K6_ITERATIONS=5 \
//             -e K6_PAYLOAD='{"id":"123"}' \
//             load_test.js
// ════════════════════════════════════════════════════════════════════════════

const ENDPOINT     = __ENV.K6_ENDPOINT    || "https://personasnaturales-baustro-personasnaturales-issue.apps.closnoprod.austro.grpfin/api/v1.0/msperson/con/person/basic";
const VUS          = parseInt(__ENV.K6_VUS         || "1");
const ITERATIONS   = parseInt(__ENV.K6_ITERATIONS  || "5");
const SUCCESS_CODE = __ENV.K6_SUCCESS_CODE || null;  // ej: "000", null = no valida

const DEFAULT_PAYLOAD = JSON.stringify({
  ipUser: "10.1.107.134",
  uuidUser: "fa50d2fd-18a4-4fc3-b38c-88daf202043d",
  userApp: "BA01000XXX",
  channel: "OSM",
  ctl: {
    user: "BA01002258",
    csucursal: "100",
    coficina: "100",
    ipterminal: "127.0.0.1",
    identification: "1105801318",
    nui: "1105801318",
    dactilar: "",
    flag: "6",
    ctipoidentificacion: "CED",
  },
});

const PAYLOAD = __ENV.K6_PAYLOAD || DEFAULT_PAYLOAD;

const HEADERS = {
  "Content-Type": "application/json",
  Accept: "application/json",
  "X-Payload-Encrypted": "false",
};

// ─── Métricas ──────────────────────────────────────────────────────────────
const latenciaTrend = new Trend("latencia_ms", true);
const errorRate     = new Rate("error_rate");
const requestCount  = new Counter("total_requests");

// ─── Opciones ──────────────────────────────────────────────────────────────
export const options = {
  scenarios: {
    carga: {
      executor: "per-vu-iterations",  // termina al completar las iteraciones, no por tiempo
      vus: VUS,
      iterations: ITERATIONS,
      maxDuration: "10m",             // límite de seguridad por si el endpoint es muy lento
    },
  },
  thresholds: {
    error_rate: ["rate<0.05"],        // menos del 5% de errores
  },
};

// ─── Request ───────────────────────────────────────────────────────────────
export default function () {
  const res = http.post(ENDPOINT, PAYLOAD, {
    headers: HEADERS,
    timeout: "120s",
  });

  latenciaTrend.add(res.timings.duration);
  requestCount.add(1);

  const checks = {
    "HTTP 200":      (r) => r.status === 200,
    "body no vacío": (r) => r.body && r.body.length > 0,
  };

  // Validación de código de negocio solo si se configuró K6_SUCCESS_CODE
  if (SUCCESS_CODE) {
    checks[`código negocio = ${SUCCESS_CODE}`] = (r) => {
      try { return JSON.parse(r.body).code === SUCCESS_CODE; } catch { return false; }
    };
  }

  const ok = check(res, checks);
  errorRate.add(!ok);

  if (!ok) {
    console.error(
      `[VU ${__VU} | iter ${__ITER}] ` +
      `HTTP ${res.status} | ${res.timings.duration.toFixed(0)} ms | ` +
      `${res.body?.slice(0, 300)}`
    );
  }
}

// ─── Resumen final ─────────────────────────────────────────────────────────
export function handleSummary(data) {
  const m = data.metrics;

  const avg    = (m.latencia_ms?.values?.avg  ?? 0).toFixed(0);
  const min    = (m.latencia_ms?.values?.min  ?? 0).toFixed(0);
  const max    = (m.latencia_ms?.values?.max  ?? 0).toFixed(0);
  const p90    = (m.latencia_ms?.values?.["p(90)"] ?? 0).toFixed(0);
  const p95    = (m.latencia_ms?.values?.["p(95)"] ?? 0).toFixed(0);
  const count  = m.total_requests?.values?.count ?? 0;
  const errPct = ((m.error_rate?.values?.rate ?? 0) * 100).toFixed(2);
  const rps    = (m.http_reqs?.values?.rate ?? 0).toFixed(2);

  const modo = VUS === 1
    ? "1 VU — request secuencial"
    : `${VUS} VUs — requests paralelos`;

  const W   = 58;
  const top = "╔" + "═".repeat(W) + "╗";
  const div = "╠" + "═".repeat(W) + "╣";
  const bot = "╚" + "═".repeat(W) + "╝";
  const hdr = (t) => `║${t.padStart(Math.floor((W + t.length) / 2)).padEnd(W)}║`;
  const row = (label, value) => `║  ${(label + ":").padEnd(22)} ${String(value).padEnd(31)} ║`;

  const endpointDisplay = ENDPOINT.length > 51
    ? ENDPOINT.slice(0, 48) + "..."
    : ENDPOINT;

  const summary = [
    "",
    top,
    hdr("  RESUMEN DE PRUEBA DE RENDIMIENTO  "),
    div,
    row("Modo",            modo),
    row("Endpoint",        endpointDisplay),
    row("Iteraciones/VU",  ITERATIONS),
    div,
    row("Total requests",  count),
    row("RPS",             rps),
    row("Tasa de errores", `${errPct}%`),
    div,
    hdr("  Tiempos de respuesta  "),
    div,
    row("Mínimo",  `${min} ms`),
    row("Promedio",`${avg} ms`),
    row("Máximo",  `${max} ms`),
    row("p90",     `${p90} ms`),
    row("p95",     `${p95} ms`),
    bot,
    "",
  ].join("\n");

  console.log(summary);
  return { stdout: summary };
}
