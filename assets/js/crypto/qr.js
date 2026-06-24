/**
 * Minimal, hand-rolled QR encoder — numeric mode only (EPIC #291 / #302).
 *
 * Purpose: render the viewer's locally-computed Signal-style safety number (a
 * fixed 60-decimal-digit string, see ./fingerprint.js `safetyNumber`) as a QR
 * code so a peer can scan-to-compare in person instead of reading 60 digits
 * aloud. The QR carries NO secret — only the public-key-derived safety number,
 * which is identical (order-independent) on both devices.
 *
 * WHY HAND-ROLLED (no dependency): QR encoding is a deterministic, secret-free
 * algorithm (ISO/IEC 18004). Unlike cryptography it has no nonces/keys/timing
 * side-channels, and in this flow it FAILS SAFE: a malformed or wrong QR simply
 * fails the scanner's compare against its OWN computed safety number, so it can
 * never forge a "verified" result. Avoiding a third-party JS dependency removes
 * supply-chain attack surface from the authenticated, key-bearing page. The
 * encoder is locked by a deterministic KAT in test/.
 *
 * SCOPE: numeric mode, fixed QR Version 2 (25x25), error-correction level M
 * (single block: 28 data + 16 EC codewords, numeric capacity 63 digits). The
 * 60-digit safety number always fits. This is intentionally the smallest
 * configuration that fits the payload — least code, least to get wrong.
 *
 * Algorithm structure adapted from the public-domain reference by Project
 * Nayuki ("QR Code generator library"), reduced to the single fixed config.
 *
 * ============================================================================
 * CORRECTNESS / KAT
 * ============================================================================
 * Verified during development against an independent encoder (segno) and a
 * canonical Reed-Solomon vector, plus a full self-decode round-trip:
 *
 *   - Data codewords match an independent numeric-mode encoding.
 *   - rsRemainder([32,91,11,120,209,114,220,77,67,64,236,17,236,17,236,17], 10)
 *       === [196,35,39,119,235,215,231,226,93,23]   (canonical QR RS KAT).
 *   - encodeNumericQr("0123...89" × 6, i.e. 60 digits) placed at mask 6 is
 *       byte-for-byte identical to segno V2-M; mask auto-selection picks the
 *       minimum-penalty mask (1 for that input), and decode() of the result
 *       recovers mode=numeric, ECL=M, count=60, and the exact 60-digit string.
 */

// ---------------------------------------------------------------------------
// Fixed configuration for QR Version 2, ECC level M.
// ---------------------------------------------------------------------------
const VERSION = 2;
const SIZE = 25; // 4 * VERSION + 17
const EC_CODEWORDS = 16; // ECC level M, version 2, single block
const DATA_CODEWORDS = 28; // total 44 codewords - 16 EC
const NUMERIC_CAPACITY = 63; // numeric chars at V2-M
const FORMAT_ECL_BITS = 0; // ECC level M format indicator (2 bits) = 0b00

// ---------------------------------------------------------------------------
// GF(256) tables (primitive polynomial 0x11d), for Reed-Solomon ECC.
// ---------------------------------------------------------------------------
const GF_EXP = new Uint8Array(512);
const GF_LOG = new Uint8Array(256);
(function initGalois() {
  let x = 1;
  for (let i = 0; i < 255; i++) {
    GF_EXP[i] = x;
    GF_LOG[x] = i;
    x <<= 1;
    if (x & 0x100) x ^= 0x11d;
  }
  for (let i = 255; i < 512; i++) GF_EXP[i] = GF_EXP[i - 255];
})();

function gfMul(a, b) {
  if (a === 0 || b === 0) return 0;
  return GF_EXP[GF_LOG[a] + GF_LOG[b]];
}

// Reed-Solomon divisor (generator polynomial minus the leading 1 term),
// coefficients stored highest-power-first. Length === degree.
function rsDivisor(degree) {
  const result = new Array(degree).fill(0);
  result[degree - 1] = 1;
  let root = 1;
  for (let i = 0; i < degree; i++) {
    for (let j = 0; j < degree; j++) {
      result[j] = gfMul(result[j], root);
      if (j + 1 < degree) result[j] ^= result[j + 1];
    }
    root = gfMul(root, 0x02);
  }
  return result;
}

function rsRemainder(data, degree) {
  const divisor = rsDivisor(degree);
  const remainder = new Array(degree).fill(0);
  for (const b of data) {
    const factor = b ^ remainder.shift();
    remainder.push(0);
    for (let i = 0; i < degree; i++) {
      remainder[i] ^= gfMul(divisor[i], factor);
    }
  }
  return remainder;
}

// ---------------------------------------------------------------------------
// Bit buffer helpers.
// ---------------------------------------------------------------------------
function appendBits(bits, value, len) {
  for (let i = len - 1; i >= 0; i--) {
    bits.push((value >>> i) & 1);
  }
}

function getBit(value, i) {
  return ((value >>> i) & 1) !== 0;
}

// ---------------------------------------------------------------------------
// Numeric-mode segment -> data codewords (28 bytes).
// ---------------------------------------------------------------------------
function numericDataCodewords(digits) {
  if (!/^[0-9]+$/.test(digits)) {
    throw new Error("qr: numeric mode requires a digit-only string");
  }
  if (digits.length > NUMERIC_CAPACITY) {
    throw new Error(`qr: ${digits.length} digits exceeds V2-M numeric capacity`);
  }

  const bits = [];
  appendBits(bits, 0b0001, 4); // numeric mode indicator
  appendBits(bits, digits.length, 10); // char count (10 bits for V1-9)

  for (let i = 0; i < digits.length; i += 3) {
    const chunk = digits.slice(i, i + 3);
    appendBits(bits, parseInt(chunk, 10), chunk.length * 3 + 1);
  }

  const capacityBits = DATA_CODEWORDS * 8;
  if (bits.length > capacityBits) {
    throw new Error("qr: encoded data exceeds capacity");
  }

  // Terminator (up to 4 zero bits) + pad to byte boundary.
  const terminator = Math.min(4, capacityBits - bits.length);
  appendBits(bits, 0, terminator);
  while (bits.length % 8 !== 0) bits.push(0);

  const bytes = [];
  for (let i = 0; i < bits.length; i += 8) {
    let b = 0;
    for (let j = 0; j < 8; j++) b = (b << 1) | bits[i + j];
    bytes.push(b);
  }

  // Pad bytes alternate 0xEC, 0x11 until the data capacity is filled.
  for (let pad = 0xec; bytes.length < DATA_CODEWORDS; pad ^= 0xec ^ 0x11) {
    bytes.push(pad);
  }
  return bytes;
}

// ---------------------------------------------------------------------------
// Matrix construction.
// ---------------------------------------------------------------------------
function newMatrix() {
  const modules = [];
  const isFunction = [];
  for (let r = 0; r < SIZE; r++) {
    modules.push(new Array(SIZE).fill(false));
    isFunction.push(new Array(SIZE).fill(false));
  }
  return { modules, isFunction };
}

function setFunctionModule(m, row, col, dark) {
  m.modules[row][col] = dark;
  m.isFunction[row][col] = true;
}

function drawFinder(m, centerRow, centerCol) {
  for (let dr = -4; dr <= 4; dr++) {
    for (let dc = -4; dc <= 4; dc++) {
      const r = centerRow + dr;
      const c = centerCol + dc;
      if (r < 0 || r >= SIZE || c < 0 || c >= SIZE) continue;
      const dist = Math.max(Math.abs(dr), Math.abs(dc));
      setFunctionModule(m, r, c, dist !== 2 && dist !== 4);
    }
  }
}

function drawAlignment(m, centerRow, centerCol) {
  for (let dr = -2; dr <= 2; dr++) {
    for (let dc = -2; dc <= 2; dc++) {
      const dist = Math.max(Math.abs(dr), Math.abs(dc));
      setFunctionModule(m, centerRow + dr, centerCol + dc, dist !== 1);
    }
  }
}

function drawTiming(m) {
  for (let i = 0; i < SIZE; i++) {
    const dark = i % 2 === 0;
    if (!m.isFunction[6][i]) setFunctionModule(m, 6, i, dark);
    if (!m.isFunction[i][6]) setFunctionModule(m, i, 6, dark);
  }
}

// 15-bit BCH-protected format information for the given mask.
function formatBits(mask) {
  const data = (FORMAT_ECL_BITS << 3) | mask;
  let rem = data;
  for (let i = 0; i < 10; i++) {
    rem = (rem << 1) ^ ((rem >>> 9) * 0x537);
  }
  return ((data << 10) | rem) ^ 0x5412;
}

function drawFormatBits(m, mask) {
  const bits = formatBits(mask);

  for (let i = 0; i <= 5; i++) setFunctionModule(m, i, 8, getBit(bits, i));
  setFunctionModule(m, 7, 8, getBit(bits, 6));
  setFunctionModule(m, 8, 8, getBit(bits, 7));
  setFunctionModule(m, 8, 7, getBit(bits, 8));
  for (let i = 9; i < 15; i++) setFunctionModule(m, 8, 14 - i, getBit(bits, i));

  for (let i = 0; i < 8; i++) {
    setFunctionModule(m, 8, SIZE - 1 - i, getBit(bits, i)); // row 8, cols 24..17
  }
  for (let i = 8; i < 15; i++) {
    setFunctionModule(m, SIZE - 15 + i, 8, getBit(bits, i)); // col 8, rows 18..24
  }
  setFunctionModule(m, SIZE - 8, 8, true); // always-dark module at (17, 8)
}

function drawFunctionPatterns(m) {
  drawTiming(m);
  drawFinder(m, 3, 3);
  drawFinder(m, 3, SIZE - 4);
  drawFinder(m, SIZE - 4, 3);
  drawAlignment(m, 18, 18); // only non-overlapping alignment center for V2
  drawFormatBits(m, 0); // reserve format region (real bits drawn per mask)
}

function drawCodewords(m, allCodewords) {
  let bitIndex = 0;
  const totalBits = allCodewords.length * 8;

  for (let right = SIZE - 1; right >= 1; right -= 2) {
    if (right === 6) right = 5; // skip the vertical timing column
    for (let vert = 0; vert < SIZE; vert++) {
      for (let j = 0; j < 2; j++) {
        const col = right - j;
        const upward = ((right + 1) & 2) === 0;
        const row = upward ? SIZE - 1 - vert : vert;
        if (m.isFunction[row][col] || bitIndex >= totalBits) continue;
        const cw = allCodewords[bitIndex >>> 3];
        m.modules[row][col] = getBit(cw, 7 - (bitIndex & 7));
        bitIndex++;
      }
    }
  }
}

function maskFn(mask, row, col) {
  switch (mask) {
    case 0:
      return (row + col) % 2 === 0;
    case 1:
      return row % 2 === 0;
    case 2:
      return col % 3 === 0;
    case 3:
      return (row + col) % 3 === 0;
    case 4:
      return (Math.floor(row / 2) + Math.floor(col / 3)) % 2 === 0;
    case 5:
      return ((row * col) % 2) + ((row * col) % 3) === 0;
    case 6:
      return (((row * col) % 2) + ((row * col) % 3)) % 2 === 0;
    case 7:
      return (((row + col) % 2) + ((row * col) % 3)) % 2 === 0;
    default:
      throw new Error("qr: invalid mask");
  }
}

function applyMask(m, mask) {
  for (let row = 0; row < SIZE; row++) {
    for (let col = 0; col < SIZE; col++) {
      if (!m.isFunction[row][col] && maskFn(mask, row, col)) {
        m.modules[row][col] = !m.modules[row][col];
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Penalty scoring (ISO/IEC 18004 §8.8.2) to pick the lowest-penalty mask.
// ---------------------------------------------------------------------------
const PENALTY_N1 = 3;
const PENALTY_N2 = 3;
const PENALTY_N3 = 40;
const PENALTY_N4 = 10;

function finderPenaltyAddHistory(runLength, history) {
  if (history[0] === 0) runLength += SIZE; // light border before the first run
  history.pop();
  history.unshift(runLength);
}

function finderPenaltyCountPatterns(history) {
  const n = history[1];
  const core =
    n > 0 &&
    history[2] === n &&
    history[3] === n * 3 &&
    history[4] === n &&
    history[5] === n;
  return (
    (core && history[0] >= n * 4 && history[6] >= n ? 1 : 0) +
    (core && history[6] >= n * 4 && history[0] >= n ? 1 : 0)
  );
}

function finderPenaltyTerminateAndCount(runColor, runLength, history) {
  if (runColor) {
    finderPenaltyAddHistory(runLength, history);
    runLength = 0;
  }
  runLength += SIZE; // light border after the last run
  finderPenaltyAddHistory(runLength, history);
  return finderPenaltyCountPatterns(history);
}

function penaltyScore(m) {
  let result = 0;
  const mod = m.modules;

  // Rule 1 + 3: rows.
  for (let row = 0; row < SIZE; row++) {
    let runColor = false;
    let runLength = 0;
    const history = [0, 0, 0, 0, 0, 0, 0];
    for (let col = 0; col < SIZE; col++) {
      if (mod[row][col] === runColor) {
        runLength++;
        if (runLength === 5) result += PENALTY_N1;
        else if (runLength > 5) result++;
      } else {
        finderPenaltyAddHistory(runLength, history);
        if (!runColor) result += finderPenaltyCountPatterns(history) * PENALTY_N3;
        runColor = mod[row][col];
        runLength = 1;
      }
    }
    result += finderPenaltyTerminateAndCount(runColor, runLength, history) * PENALTY_N3;
  }

  // Rule 1 + 3: columns.
  for (let col = 0; col < SIZE; col++) {
    let runColor = false;
    let runLength = 0;
    const history = [0, 0, 0, 0, 0, 0, 0];
    for (let row = 0; row < SIZE; row++) {
      if (mod[row][col] === runColor) {
        runLength++;
        if (runLength === 5) result += PENALTY_N1;
        else if (runLength > 5) result++;
      } else {
        finderPenaltyAddHistory(runLength, history);
        if (!runColor) result += finderPenaltyCountPatterns(history) * PENALTY_N3;
        runColor = mod[row][col];
        runLength = 1;
      }
    }
    result += finderPenaltyTerminateAndCount(runColor, runLength, history) * PENALTY_N3;
  }

  // Rule 2: 2x2 blocks of one color.
  for (let row = 0; row < SIZE - 1; row++) {
    for (let col = 0; col < SIZE - 1; col++) {
      const color = mod[row][col];
      if (
        color === mod[row][col + 1] &&
        color === mod[row + 1][col] &&
        color === mod[row + 1][col + 1]
      ) {
        result += PENALTY_N2;
      }
    }
  }

  // Rule 4: dark/light balance.
  let dark = 0;
  for (let row = 0; row < SIZE; row++) {
    for (let col = 0; col < SIZE; col++) {
      if (mod[row][col]) dark++;
    }
  }
  const total = SIZE * SIZE;
  const k = Math.ceil(Math.abs(dark * 20 - total * 10) / total) - 1;
  result += k * PENALTY_N4;

  return result;
}

// ---------------------------------------------------------------------------
// Public API.
// ---------------------------------------------------------------------------

/**
 * Encode a digit-only string as a QR Version 2 / ECC-M matrix.
 * @param {string} digits - decimal digits only, up to 63 characters
 * @returns {boolean[][]} 25x25 matrix; true = dark module
 */
export function encodeNumericQr(digits) {
  const dataCodewords = numericDataCodewords(digits);
  const ecCodewords = rsRemainder(dataCodewords, EC_CODEWORDS);
  const allCodewords = dataCodewords.concat(ecCodewords);

  const m = newMatrix();
  drawFunctionPatterns(m);
  drawCodewords(m, allCodewords);

  // Choose the mask with the lowest penalty (apply, score, revert).
  let bestMask = 0;
  let bestPenalty = Infinity;
  for (let mask = 0; mask < 8; mask++) {
    applyMask(m, mask);
    drawFormatBits(m, mask);
    const penalty = penaltyScore(m);
    if (penalty < bestPenalty) {
      bestPenalty = penalty;
      bestMask = mask;
    }
    applyMask(m, mask); // revert (mask is its own inverse)
  }

  applyMask(m, bestMask);
  drawFormatBits(m, bestMask);
  return m.modules;
}

/**
 * Render a digit-only string as a crisp, scalable QR SVG string.
 *
 * The SVG is built from primitives we fully control (no external markup), so it
 * is safe to assign via innerHTML. A quiet zone of 4 modules is included per
 * spec for reliable scanning.
 *
 * @param {string} digits - decimal digits only, up to 63 characters
 * @param {Object} [opts]
 * @param {number} [opts.quiet=4] - quiet-zone width in modules
 * @param {string} [opts.title] - accessible <title> text
 * @returns {string} SVG markup
 */
export function renderQrSvg(digits, opts = {}) {
  const quiet = Number.isInteger(opts.quiet) ? opts.quiet : 4;
  const matrix = encodeNumericQr(digits);
  const dim = SIZE + quiet * 2;

  let path = "";
  for (let row = 0; row < SIZE; row++) {
    for (let col = 0; col < SIZE; col++) {
      if (matrix[row][col]) {
        path += `M${col + quiet} ${row + quiet}h1v1h-1z`;
      }
    }
  }

  const title = opts.title
    ? `<title>${String(opts.title).replace(/[<>&]/g, "")}</title>`
    : "";

  return (
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${dim} ${dim}" ` +
    `shape-rendering="crispEdges" role="img" aria-label="QR code">` +
    title +
    `<rect width="${dim}" height="${dim}" fill="#ffffff"/>` +
    `<path d="${path}" fill="#000000"/>` +
    `</svg>`
  );
}
