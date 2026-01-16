let dictionaryCache = null;
let dictionaryArrayCache = null;
let dictionaryLoading = false;
let dictionaryCallbacks = [];
let definitionsCache = null;
let definitionsLoading = false;
let definitionsCallbacks = [];
let urbanCache = null;
let urbanLoading = false;
let urbanCallbacks = [];
let activeInstanceCount = 0;

function clearGlobalCaches() {
  dictionaryCache = null;
  dictionaryArrayCache = null;
  definitionsCache = null;
  urbanCache = null;
  dictionaryLoading = false;
  definitionsLoading = false;
  urbanLoading = false;
  dictionaryCallbacks = [];
  definitionsCallbacks = [];
  urbanCallbacks = [];
}

async function loadDictionary() {
  if (dictionaryCache) return dictionaryCache;
  
  if (dictionaryLoading) {
    return new Promise((resolve) => {
      dictionaryCallbacks.push(resolve);
    });
  }
  
  dictionaryLoading = true;
  
  try {
    const response = await fetch("/dictionary/en-words.json");
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const words = await response.json();
    dictionaryCache = new Set(words);
    dictionaryArrayCache = words;
    dictionaryLoading = false;
    
    dictionaryCallbacks.forEach(cb => cb(dictionaryCache));
    dictionaryCallbacks = [];
    
    return dictionaryCache;
  } catch (e) {
    console.warn("Failed to load spell check dictionary:", e);
    dictionaryLoading = false;
    dictionaryCallbacks.forEach(cb => cb(null));
    dictionaryCallbacks = [];
    return null;
  }
}

async function loadDefinitions() {
  if (definitionsCache) return definitionsCache;
  
  if (definitionsLoading) {
    return new Promise((resolve) => {
      definitionsCallbacks.push(resolve);
    });
  }
  
  definitionsLoading = true;
  
  try {
    const response = await fetch("/dictionary/en-definitions.json");
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    definitionsCache = await response.json();
    definitionsLoading = false;
    
    definitionsCallbacks.forEach(cb => cb(definitionsCache));
    definitionsCallbacks = [];
    
    return definitionsCache;
  } catch (e) {
    console.warn("Failed to load definitions dictionary:", e);
    definitionsLoading = false;
    definitionsCallbacks.forEach(cb => cb(null));
    definitionsCallbacks = [];
    return null;
  }
}

async function loadUrbanDictionary() {
  if (urbanCache) return urbanCache;
  
  if (urbanLoading) {
    return new Promise((resolve) => {
      urbanCallbacks.push(resolve);
    });
  }
  
  urbanLoading = true;
  
  try {
    const response = await fetch("/dictionary/en-urban.json");
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    urbanCache = await response.json();
    urbanLoading = false;
    
    urbanCallbacks.forEach(cb => cb(urbanCache));
    urbanCallbacks = [];
    
    return urbanCache;
  } catch (e) {
    console.warn("Failed to load urban dictionary:", e);
    urbanLoading = false;
    urbanCallbacks.forEach(cb => cb(null));
    urbanCallbacks = [];
    return null;
  }
}

function isUrbanWord(word) {
  if (!urbanCache) return false;
  return urbanCache.hasOwnProperty(word.toLowerCase());
}

function getDefinition(word) {
  if (!dictionaryCache) return null;
  const lowerWord = word.toLowerCase();
  if (!dictionaryCache.has(lowerWord)) return null;
  
  if (urbanCache && urbanCache[lowerWord]) {
    return { defs: urbanCache[lowerWord], source: "urban" };
  }
  if (definitionsCache && definitionsCache[lowerWord]) {
    return { defs: definitionsCache[lowerWord], source: "standard" };
  }
  return null;
}

function damerauLevenshtein(a, b) {
  const lenA = a.length;
  const lenB = b.length;
  
  if (lenA === 0) return lenB;
  if (lenB === 0) return lenA;
  
  const d = Array.from({ length: lenA + 1 }, () => Array(lenB + 1).fill(0));
  
  for (let i = 0; i <= lenA; i++) d[i][0] = i;
  for (let j = 0; j <= lenB; j++) d[0][j] = j;
  
  for (let i = 1; i <= lenA; i++) {
    for (let j = 1; j <= lenB; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      
      d[i][j] = Math.min(
        d[i - 1][j] + 1,
        d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost
      );
      
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + cost);
      }
    }
  }
  
  return d[lenA][lenB];
}

function sortedChars(word) {
  return word.split('').sort().join('');
}

const COMMON_WORDS = new Set([
  'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i',
  'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at',
  'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she',
  'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what',
  'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me',
  'when', 'make', 'can', 'like', 'time', 'no', 'just', 'him', 'know', 'take',
  'people', 'into', 'year', 'your', 'good', 'some', 'could', 'them', 'see', 'other',
  'than', 'then', 'now', 'look', 'only', 'come', 'its', 'over', 'think', 'also',
  'back', 'after', 'use', 'two', 'how', 'our', 'work', 'first', 'well', 'way',
  'even', 'new', 'want', 'because', 'any', 'these', 'give', 'day', 'most', 'us',
  'great', 'very', 'really', 'much', 'before', 'being', 'through', 'where', 'right', 'still'
]);

function computeSimilarityScore(misspelled, candidate) {
  const distance = damerauLevenshtein(misspelled, candidate);
  
  let score = distance * 100;
  
  if (sortedChars(misspelled) === sortedChars(candidate)) {
    score -= 50;
  }
  
  if (misspelled[0] === candidate[0]) {
    score -= 20;
  }
  
  if (misspelled.length === candidate.length) {
    score -= 10;
  }
  
  if (COMMON_WORDS.has(candidate)) {
    score -= 15;
  }
  
  return score;
}

function findSpellingSuggestions(word, maxSuggestions = 3) {
  if (!dictionaryArrayCache || !word) return [];
  
  const lowerWord = word.toLowerCase();
  const wordLen = lowerWord.length;
  const candidates = [];
  
  for (const dictWord of dictionaryArrayCache) {
    if (Math.abs(dictWord.length - wordLen) > 2) continue;
    if (dictWord.length < 2) continue;
    if (isUrbanWord(dictWord)) continue;
    
    const distance = damerauLevenshtein(lowerWord, dictWord);
    
    if (distance <= 2 && distance > 0) {
      const score = computeSimilarityScore(lowerWord, dictWord);
      candidates.push({ word: dictWord, distance, score });
    }
  }
  
  candidates.sort((a, b) => a.score - b.score);
  
  return candidates.slice(0, maxSuggestions).map(s => s.word);
}

const AutoResize = {
  mounted() {
    activeInstanceCount++;
    this.el.style.boxSizing = "border-box";
    this.offset = this.el.offsetHeight - this.el.clientHeight;
    this.isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    this.keyboardOpen = false;
    this.initialViewportHeight = window.visualViewport?.height || window.innerHeight;
    this.lastHeight = null;
    this.resizeScheduled = false;
    this.lastCursorScreenY = null;
    
    this.resize();
    
    this.handleInput = () => {
      if (!this.resizeScheduled) {
        this.resizeScheduled = true;
        requestAnimationFrame(() => {
          this.resizeScheduled = false;
          this.resize();
          this.scrollCursorIntoView();
          this.scheduleSpellCheck();
        });
      }
    };
    this.el.addEventListener("input", this.handleInput);

    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "characterData" || mutation.type === "childList") {
          if (document.activeElement === this.el && this.savedSelectionStart !== undefined) {
            this.el.selectionStart = this.savedSelectionStart;
            this.el.selectionEnd = this.savedSelectionEnd;
          }
        }
      }
    });
    this.observer.observe(this.el, { characterData: true, childList: true, subtree: true });

    this.handleSelectionChange = () => {
      if (document.activeElement === this.el) {
        this.savedSelectionStart = this.el.selectionStart;
        this.savedSelectionEnd = this.el.selectionEnd;
        this.savedScrollTop = window.scrollY;
      }
    };
    document.addEventListener("selectionchange", this.handleSelectionChange);
    
    if (this.isIOS && window.visualViewport) {
      this.handleViewportResize = () => {
        const currentHeight = window.visualViewport.height;
        const heightDiff = this.initialViewportHeight - currentHeight;
        this.keyboardOpen = heightDiff > 100;
        this.resize();
      };
      
      window.visualViewport.addEventListener("resize", this.handleViewportResize);
    }
    
    this.handleFocus = () => {
      this.initCursorPosition();
      if (this.isIOS) {
        this.keyboardOpen = true;
        requestAnimationFrame(() => this.resize());
      }
    };
    
    this.handleBlur = () => {
      this.lastCursorScreenY = null;
      if (this.isIOS) {
        this.keyboardOpen = false;
        this.resize();
      }
    };
    
    this.el.addEventListener("focus", this.handleFocus);
    this.el.addEventListener("blur", this.handleBlur);

    this.initSpellChecker();
  },

  destroyed() {
    this.el.removeEventListener("input", this.handleInput);
    this.el.removeEventListener("focus", this.handleFocus);
    this.el.removeEventListener("blur", this.handleBlur);
    document.removeEventListener("selectionchange", this.handleSelectionChange);
    if (this.observer) {
      this.observer.disconnect();
    }
    
    if (this.isIOS && window.visualViewport) {
      window.visualViewport.removeEventListener("resize", this.handleViewportResize);
    }

    if (this._measureClone) {
      this._measureClone = null;
    }

    if (this._cursorMirror) {
      this._cursorMirror = null;
    }

    this.destroySpellChecker();

    activeInstanceCount--;
    if (activeInstanceCount === 0) {
      clearGlobalCaches();
    }
  },

  getFooterHeight() {
    const footer = document.querySelector("footer.fixed.bottom-0");
    return footer ? footer.offsetHeight : 0;
  },
  
  getVisibleHeight() {
    if (this.isIOS && window.visualViewport) {
      return window.visualViewport.height;
    }
    return window.innerHeight;
  },

  getOrCreateMeasureClone() {
    if (!this._measureClone) {
      this._measureClone = document.createElement("textarea");
      this._measureClone.style.position = "absolute";
      this._measureClone.style.visibility = "hidden";
      this._measureClone.style.height = "auto";
      this._measureClone.style.overflow = "hidden";
      this._measureClone.style.pointerEvents = "none";
      this._measureClone.setAttribute("aria-hidden", "true");
      this._measureClone.setAttribute("tabindex", "-1");
    }
    return this._measureClone;
  },

  measureContentHeight() {
    const el = this.el;
    const clone = this.getOrCreateMeasureClone();
    const style = getComputedStyle(el);
    
    clone.style.width = el.offsetWidth + "px";
    clone.style.font = style.font;
    clone.style.fontSize = style.fontSize;
    clone.style.fontFamily = style.fontFamily;
    clone.style.lineHeight = style.lineHeight;
    clone.style.padding = style.padding;
    clone.style.border = style.border;
    clone.style.boxSizing = style.boxSizing;
    clone.style.letterSpacing = style.letterSpacing;
    clone.style.wordWrap = style.wordWrap;
    clone.style.whiteSpace = style.whiteSpace;
    clone.value = el.value;
    
    document.body.appendChild(clone);
    const height = clone.scrollHeight + this.offset;
    document.body.removeChild(clone);
    return height;
  },

  resize() {
    const el = this.el;
    const savedScrollY = window.scrollY;
    const savedSelStart = el.selectionStart;
    const savedSelEnd = el.selectionEnd;
    
    if (this.isIOS) {
      const currentHeight = el.offsetHeight;
      const currentScrollHeight = el.scrollHeight;
      
      if (currentScrollHeight > currentHeight) {
        el.style.height = (currentScrollHeight + this.offset) + "px";
      } else if (this.lastHeight !== null && currentScrollHeight < this.lastHeight - 20) {
        const newHeight = this.measureContentHeight();
        el.style.height = newHeight + "px";
      }
      
      this.lastHeight = el.scrollHeight;
    } else {
      const currentScrollHeight = el.scrollHeight;
      const currentSetHeight = parseFloat(el.style.height) || el.offsetHeight;
      
      if (currentScrollHeight + this.offset > currentSetHeight) {
        el.style.height = (currentScrollHeight + this.offset) + "px";
      } else {
        const newHeight = this.measureContentHeight();
        if (Math.abs(newHeight - currentSetHeight) > 1) {
          el.style.height = newHeight + "px";
        }
      }
      el.style.overflowY = "hidden";
    }
    
    if (document.activeElement === el) {
      el.selectionStart = savedSelStart;
      el.selectionEnd = savedSelEnd;
      if (window.scrollY !== savedScrollY) {
        window.scrollTo({ top: savedScrollY, behavior: "instant" });
      }
    }
  },

  getOrCreateCursorMirror() {
    if (!this._cursorMirror) {
      this._cursorMirror = document.createElement("div");
      this._cursorMirror.style.position = "absolute";
      this._cursorMirror.style.visibility = "hidden";
      this._cursorMirror.style.whiteSpace = "pre-wrap";
      this._cursorMirror.style.wordWrap = "break-word";
      this._cursorMirror.style.pointerEvents = "none";
      this._cursorMirror.setAttribute("aria-hidden", "true");
    }
    return this._cursorMirror;
  },

  getCursorCoordinates() {
    const el = this.el;
    if (el.selectionStart === undefined) return null;

    const mirror = this.getOrCreateCursorMirror();
    const style = getComputedStyle(el);
    
    mirror.style.width = style.width;
    mirror.style.font = style.font;
    mirror.style.fontSize = style.fontSize;
    mirror.style.fontFamily = style.fontFamily;
    mirror.style.lineHeight = style.lineHeight;
    mirror.style.padding = style.padding;
    mirror.style.border = style.border;
    mirror.style.boxSizing = style.boxSizing;
    mirror.style.letterSpacing = style.letterSpacing;
    
    const textBeforeCursor = el.value.substring(0, el.selectionStart);
    mirror.textContent = textBeforeCursor;
    
    const marker = document.createElement("span");
    marker.textContent = "|";
    mirror.appendChild(marker);
    
    document.body.appendChild(mirror);
    
    const markerRect = marker.getBoundingClientRect();
    const mirrorRect = mirror.getBoundingClientRect();
    
    const cursorY = markerRect.top - mirrorRect.top;
    
    document.body.removeChild(mirror);
    mirror.textContent = "";
    
    return cursorY;
  },

  scrollCursorIntoView() {
    const el = this.el;
    if (el.selectionStart === undefined) return;
    
    const cursorY = this.getCursorCoordinates();
    if (cursorY === null) return;
    
    const style = getComputedStyle(el);
    const lineHeight = parseFloat(style.lineHeight) || 28;
    const rect = el.getBoundingClientRect();
    const cursorScreenY = rect.top + cursorY;
    
    const footerHeight = this.getFooterHeight();
    const visibleHeight = this.getVisibleHeight();
    const bottomThreshold = visibleHeight - footerHeight - lineHeight * 2;
    
    if (cursorScreenY > bottomThreshold) {
      const scrollAmount = cursorScreenY - bottomThreshold + lineHeight;
      window.scrollBy({ top: scrollAmount, behavior: "instant" });
    }
    
    const finalRect = el.getBoundingClientRect();
    this.lastCursorScreenY = finalRect.top + cursorY;
  },

  initCursorPosition() {
    const el = this.el;
    if (el.selectionStart === undefined) return;
    
    const cursorY = this.getCursorCoordinates();
    if (cursorY === null) return;
    
    const rect = el.getBoundingClientRect();
    this.lastCursorScreenY = rect.top + cursorY;
  },

  async initSpellChecker() {
    this.el.setAttribute("spellcheck", "false");
    this.dictionary = null;
    this.spellIgnoredWords = new Set();
    this.misspelledWords = new Map();
    this.spellCheckTimeout = null;
    
    this.loadSpellIgnoredWords();
    this.createSpellOverlay();
    this.createSpellContextMenu();
    this.createDefinitionPopup();

    this.dictionary = await loadDictionary();
    this.definitions = await loadDefinitions();
    this.urban = await loadUrbanDictionary();
    
    if (this.dictionary) {
      this.runSpellCheck();
    }

    this.handleSpellContextMenu = (e) => {
      const wordInfo = this.getWordAtPosition(e.clientX, e.clientY);
      if (wordInfo && wordInfo.word.length >= 1) {
        const isMisspelled = this.isWordMisspelled(wordInfo.word);
        this.showSpellContextMenu(e, wordInfo.word, isMisspelled, wordInfo);
      }
    };
    this.el.addEventListener("contextmenu", this.handleSpellContextMenu);

    this.handleTouchStart = (e) => {
      if (e.touches.length !== 1) return;
      this.touchStartTime = Date.now();
      this.touchStartPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
      this.longPressTimer = setTimeout(() => {
        const wordInfo = this.getWordAtPosition(this.touchStartPos.x, this.touchStartPos.y);
        if (wordInfo && wordInfo.word.length >= 1) {
          const isMisspelled = this.isWordMisspelled(wordInfo.word);
          const fakeEvent = {
            preventDefault: () => {},
            clientX: this.touchStartPos.x,
            clientY: this.touchStartPos.y
          };
          this.showSpellContextMenu(fakeEvent, wordInfo.word, isMisspelled, wordInfo);
        }
      }, 500);
    };
    
    this.handleTouchEnd = () => {
      if (this.longPressTimer) {
        clearTimeout(this.longPressTimer);
        this.longPressTimer = null;
      }
    };
    
    this.handleTouchMove = (e) => {
      if (this.longPressTimer && this.touchStartPos) {
        const dx = Math.abs(e.touches[0].clientX - this.touchStartPos.x);
        const dy = Math.abs(e.touches[0].clientY - this.touchStartPos.y);
        if (dx > 10 || dy > 10) {
          clearTimeout(this.longPressTimer);
          this.longPressTimer = null;
        }
      }
    };
    
    this.el.addEventListener("touchstart", this.handleTouchStart, { passive: true });
    this.el.addEventListener("touchend", this.handleTouchEnd, { passive: true });
    this.el.addEventListener("touchcancel", this.handleTouchEnd, { passive: true });
    this.el.addEventListener("touchmove", this.handleTouchMove, { passive: true });

    this.handleScroll = () => this.updateOverlayPosition();
    window.addEventListener("scroll", this.handleScroll, { passive: true });
    
    this.handleResize = () => {
      this.updateOverlayPosition();
      this.scheduleSpellCheck();
    };
    window.addEventListener("resize", this.handleResize, { passive: true });
  },

  destroySpellChecker() {
    if (this.spellContextMenu) {
      this.spellContextMenu.remove();
    }
    if (this.definitionPopup) {
      this.definitionPopup.remove();
    }
    if (this.spellOverlay) {
      this.spellOverlay.remove();
    }
    if (this.hideSpellContextMenuHandler) {
      document.removeEventListener("click", this.hideSpellContextMenuHandler);
      document.removeEventListener("keydown", this.hideSpellContextMenuHandler);
    }
    if (this.hideDefinitionPopupHandler) {
      document.removeEventListener("click", this.hideDefinitionPopupHandler);
      document.removeEventListener("keydown", this.hideDefinitionPopupHandler);
    }
    if (this.handleSpellContextMenu) {
      this.el.removeEventListener("contextmenu", this.handleSpellContextMenu);
    }
    if (this.handleTouchStart) {
      this.el.removeEventListener("touchstart", this.handleTouchStart);
      this.el.removeEventListener("touchend", this.handleTouchEnd);
      this.el.removeEventListener("touchcancel", this.handleTouchEnd);
      this.el.removeEventListener("touchmove", this.handleTouchMove);
    }
    if (this.longPressTimer) {
      clearTimeout(this.longPressTimer);
    }
    if (this.handleScroll) {
      window.removeEventListener("scroll", this.handleScroll);
    }
    if (this.handleResize) {
      window.removeEventListener("resize", this.handleResize);
    }
    if (this.spellCheckTimeout) {
      clearTimeout(this.spellCheckTimeout);
    }
  },

  loadSpellIgnoredWords() {
    try {
      const stored = sessionStorage.getItem("spellcheck_ignored");
      if (stored) {
        const parsed = JSON.parse(stored);
        if (Array.isArray(parsed) && parsed.every(w => typeof w === "string")) {
          this.spellIgnoredWords = new Set(parsed);
        }
      }
    } catch (e) {
      this.spellIgnoredWords = new Set();
    }
  },

  saveSpellIgnoredWords() {
    try {
      const data = JSON.stringify([...this.spellIgnoredWords]);
      const MAX_STORAGE_SIZE = 50 * 1024;
      if (data.length > MAX_STORAGE_SIZE) {
        console.warn("Spell check ignored words exceeded storage limit, clearing oldest entries");
        const words = [...this.spellIgnoredWords];
        this.spellIgnoredWords = new Set(words.slice(-500));
      }
      sessionStorage.setItem(
        "spellcheck_ignored",
        JSON.stringify([...this.spellIgnoredWords])
      );
    } catch (e) {
      console.warn("Failed to save spell check ignored words:", e);
    }
  },

  createSpellOverlay() {
    const container = this.el.parentElement;
    container.style.position = "relative";
    
    this.spellOverlay = document.createElement("div");
    this.spellOverlay.className = "spell-check-overlay";
    this.spellOverlay.setAttribute("aria-hidden", "true");
    
    container.appendChild(this.spellOverlay);
    
    this.el.style.position = "relative";
    this.el.style.zIndex = "1";
    this.el.style.background = "transparent";
    
    this.updateOverlayPosition();
  },

  updateOverlayPosition() {
    if (!this.spellOverlay) return;
    
    const style = getComputedStyle(this.el);
    const rect = this.el.getBoundingClientRect();
    const containerRect = this.el.parentElement.getBoundingClientRect();
    
    this.spellOverlay.style.position = "absolute";
    this.spellOverlay.style.top = (rect.top - containerRect.top) + "px";
    this.spellOverlay.style.left = (rect.left - containerRect.left) + "px";
    this.spellOverlay.style.width = style.width;
    this.spellOverlay.style.height = this.el.scrollHeight + "px";
    this.spellOverlay.style.padding = style.padding;
    this.spellOverlay.style.font = style.font;
    this.spellOverlay.style.fontSize = style.fontSize;
    this.spellOverlay.style.fontFamily = style.fontFamily;
    this.spellOverlay.style.lineHeight = style.lineHeight;
    this.spellOverlay.style.letterSpacing = style.letterSpacing;
    this.spellOverlay.style.whiteSpace = "pre-wrap";
    this.spellOverlay.style.wordWrap = "break-word";
    this.spellOverlay.style.overflowWrap = "break-word";
    this.spellOverlay.style.pointerEvents = "none";
    this.spellOverlay.style.zIndex = "0";
    this.spellOverlay.style.color = "transparent";
    this.spellOverlay.style.boxSizing = style.boxSizing;
    this.spellOverlay.style.border = style.border;
    this.spellOverlay.style.borderColor = "transparent";
  },

  createSpellContextMenu() {
    this.spellContextMenu = document.createElement("div");
    this.spellContextMenu.className = "spell-context-menu";
    this.spellContextMenu.setAttribute("role", "dialog");
    this.spellContextMenu.setAttribute("aria-label", "Spelling suggestions");
    this.spellContextMenu.hidden = true;
    document.body.appendChild(this.spellContextMenu);

    this.hideSpellContextMenuHandler = (e) => {
      if (e.type === "keydown" && e.key === "Escape") {
        this.spellContextMenu.hidden = true;
        return;
      }
      if (e.type === "click" && !this.spellContextMenu.contains(e.target)) {
        this.spellContextMenu.hidden = true;
      }
    };

    document.addEventListener("click", this.hideSpellContextMenuHandler);
    document.addEventListener("keydown", this.hideSpellContextMenuHandler);
  },

  scheduleSpellCheck() {
    if (this.spellCheckTimeout) {
      clearTimeout(this.spellCheckTimeout);
    }
    this.spellCheckTimeout = setTimeout(() => this.runSpellCheck(), 300);
  },

  isWordMisspelled(word) {
    if (!this.dictionary) return false;
    if (!word || word.length < 2) return false;
    
    const lowerWord = word.toLowerCase();
    
    if (this.spellIgnoredWords.has(lowerWord)) return false;
    
    if (/^\d+$/.test(word)) return false;
    if (/^[A-Z]+$/.test(word) && word.length <= 4) return false;
    if (/^[A-Z][a-z]+$/.test(word) && this.dictionary.has(lowerWord)) return false;
    
    return !this.dictionary.has(lowerWord);
  },

  runSpellCheck() {
    if (!this.dictionary || !this.spellOverlay) return;
    
    const text = this.el.value;
    
    this.misspelledWords.clear();
    
    const fragment = document.createDocumentFragment();
    let lastIndex = 0;
    
    const wordRegex = /[a-zA-Z']+/g;
    let match;
    
    while ((match = wordRegex.exec(text)) !== null) {
      const word = match[0].replace(/^'+|'+$/g, "");
      const startIndex = match.index;
      const endIndex = match.index + match[0].length;
      
      if (lastIndex < startIndex) {
        fragment.appendChild(document.createTextNode(text.slice(lastIndex, startIndex)));
      }
      
      if (word.length > 1 && this.isWordMisspelled(word)) {
        this.misspelledWords.set(startIndex, { word, start: startIndex, end: endIndex });
        const span = document.createElement("span");
        span.className = "spell-error";
        span.textContent = match[0];
        fragment.appendChild(span);
      } else {
        fragment.appendChild(document.createTextNode(match[0]));
      }
      
      lastIndex = endIndex;
    }
    
    if (lastIndex < text.length) {
      fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
    }
    
    this.spellOverlay.textContent = "";
    this.spellOverlay.appendChild(fragment);
    this.updateOverlayPosition();
  },

  getWordAtPosition(clientX, clientY) {
    const rect = this.el.getBoundingClientRect();
    const style = getComputedStyle(this.el);
    const paddingLeft = parseFloat(style.paddingLeft);
    const paddingTop = parseFloat(style.paddingTop);
    
    const x = clientX - rect.left - paddingLeft;
    const y = clientY - rect.top - paddingTop + this.el.scrollTop;
    
    const pos = this.el.selectionStart;
    const text = this.el.value;
    
    let start = pos;
    let end = pos;
    
    while (start > 0 && /[a-zA-Z']/.test(text[start - 1])) {
      start--;
    }
    while (end < text.length && /[a-zA-Z']/.test(text[end])) {
      end++;
    }
    
    const word = text.slice(start, end).replace(/^'+|'+$/g, "");
    if (word.length >= 1) {
      return { word, start, end };
    }
    return null;
  },

  buildMenuHeader(word, isMisspelled, isIgnored) {
    const header = document.createElement("div");
    header.className = "spell-menu-header";
    
    const wordSpan = document.createElement("span");
    wordSpan.className = "spell-menu-word";
    wordSpan.textContent = word;
    header.appendChild(wordSpan);
    
    if (isMisspelled && !isIgnored) {
      const badge = document.createElement("span");
      badge.className = "spell-menu-badge";
      badge.textContent = "Not in dictionary";
      header.appendChild(badge);
    } else if (isIgnored) {
      const badge = document.createElement("span");
      badge.className = "spell-menu-badge spell-menu-badge-ignored";
      badge.textContent = "Ignored";
      header.appendChild(badge);
    }
    
    return header;
  },

  buildMenuButton(iconPath, label, action, extraData = {}) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "spell-menu-item";
    if (action === "replace") btn.className += " spell-menu-suggestion";
    btn.dataset.action = action;
    Object.entries(extraData).forEach(([key, val]) => btn.dataset[key] = val);
    
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", "spell-menu-icon");
    svg.setAttribute("viewBox", "0 0 20 20");
    svg.setAttribute("fill", "currentColor");
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", iconPath);
    svg.appendChild(path);
    btn.appendChild(svg);
    
    const span = document.createElement("span");
    span.textContent = label;
    btn.appendChild(span);
    
    return btn;
  },

  showSpellContextMenu(e, word, isMisspelled, wordInfo = null) {
    e.preventDefault();

    const lowerWord = word.toLowerCase();
    const isIgnored = this.spellIgnoredWords.has(lowerWord);
    const suggestions = isMisspelled && !isIgnored ? findSpellingSuggestions(word) : [];
    const definition = getDefinition(word);

    const fragment = document.createDocumentFragment();
    
    fragment.appendChild(this.buildMenuHeader(word, isMisspelled, isIgnored));
    
    const divider1 = document.createElement("div");
    divider1.className = "spell-menu-divider";
    fragment.appendChild(divider1);

    if (isMisspelled && !isIgnored && suggestions.length > 0) {
      const label = document.createElement("div");
      label.className = "spell-menu-suggestions-label";
      label.textContent = "Suggestions";
      fragment.appendChild(label);
      
      suggestions.forEach(suggestion => {
        const btn = this.buildMenuButton(
          "M7.793 2.232a.75.75 0 01-.025 1.06L3.622 7.25h10.003a5.375 5.375 0 010 10.75H10.75a.75.75 0 010-1.5h2.875a3.875 3.875 0 000-7.75H3.622l4.146 3.957a.75.75 0 01-1.036 1.085l-5.5-5.25a.75.75 0 010-1.085l5.5-5.25a.75.75 0 011.06.025z",
          suggestion,
          "replace",
          { suggestion }
        );
        fragment.appendChild(btn);
      });
      
      const divider2 = document.createElement("div");
      divider2.className = "spell-menu-divider";
      fragment.appendChild(divider2);
    }

    if (definition) {
      fragment.appendChild(this.buildMenuButton(
        "M10.75 16.82A7.462 7.462 0 0115 15.5c.71 0 1.396.098 2.046.282A.75.75 0 0018 15.06v-11a.75.75 0 00-.546-.721A9.006 9.006 0 0015 3a8.963 8.963 0 00-4.25 1.065V16.82zM9.25 4.065A8.963 8.963 0 005 3c-.85 0-1.673.118-2.454.339A.75.75 0 002 4.06v11a.75.75 0 00.954.721A7.506 7.506 0 015 15.5c1.579 0 3.042.487 4.25 1.32V4.065z",
        "Define",
        "define",
        { word }
      ));
    }

    if (isMisspelled || isIgnored) {
      const iconPath = isIgnored 
        ? "M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
        : "M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z";
      const label = isIgnored ? "Stop ignoring" : "Ignore for this session";
      fragment.appendChild(this.buildMenuButton(iconPath, label, isIgnored ? "unignore" : "ignore"));
    } else {
      const info = document.createElement("div");
      info.className = "spell-menu-info";
      
      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("class", "spell-menu-icon");
      svg.setAttribute("viewBox", "0 0 20 20");
      svg.setAttribute("fill", "currentColor");
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("fill-rule", "evenodd");
      path.setAttribute("clip-rule", "evenodd");
      path.setAttribute("d", "M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z");
      svg.appendChild(path);
      info.appendChild(svg);
      
      const span = document.createElement("span");
      span.textContent = "Word is spelled correctly";
      info.appendChild(span);
      
      fragment.appendChild(info);
    }

    this.spellContextMenu.textContent = "";
    this.spellContextMenu.appendChild(fragment);

    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;
    
    this.spellContextMenu.hidden = false;
    this.spellContextMenu.style.visibility = "hidden";
    
    const menuRect = this.spellContextMenu.getBoundingClientRect();
    const menuWidth = menuRect.width;
    const menuHeight = menuRect.height;

    let x = e.clientX;
    let y = e.clientY + 8;

    if (x + menuWidth > viewportWidth - 16) {
      x = viewportWidth - menuWidth - 16;
    }
    if (x < 16) {
      x = 16;
    }
    if (y + menuHeight > viewportHeight - 16) {
      y = e.clientY - menuHeight - 8;
    }

    this.spellContextMenu.style.left = `${x}px`;
    this.spellContextMenu.style.top = `${y}px`;
    this.spellContextMenu.style.visibility = "visible";

    this.spellContextMenu.querySelectorAll(".spell-menu-item").forEach(btn => {
      btn.addEventListener(
        "click",
        (clickEvent) => {
          clickEvent.stopPropagation();
          const action = btn.dataset.action;
          if (action === "ignore") {
            this.ignoreSpellWord(word);
          } else if (action === "unignore") {
            this.unignoreSpellWord(word);
          } else if (action === "replace") {
            const suggestion = btn.dataset.suggestion;
            if (wordInfo) {
              this.replaceWord(wordInfo, suggestion);
            }
          } else if (action === "define") {
            const defWord = btn.dataset.word;
            this.showDefinitionPopup(defWord);
          }
          this.spellContextMenu.hidden = true;
          this.runSpellCheck();
        },
        { once: true }
      );
    });
  },

  replaceWord(wordInfo, replacement) {
    const text = this.el.value;
    const before = text.slice(0, wordInfo.start);
    const after = text.slice(wordInfo.end);
    
    const originalWord = text.slice(wordInfo.start, wordInfo.end);
    let finalReplacement = replacement;
    
    if (originalWord[0] === originalWord[0].toUpperCase()) {
      finalReplacement = replacement.charAt(0).toUpperCase() + replacement.slice(1);
    }
    
    this.el.value = before + finalReplacement + after;
    
    const newCursorPos = wordInfo.start + finalReplacement.length;
    this.el.selectionStart = newCursorPos;
    this.el.selectionEnd = newCursorPos;
    
    this.el.dispatchEvent(new Event("input", { bubbles: true }));
    this.el.focus();
  },

  ignoreSpellWord(word) {
    const MAX_IGNORED_WORDS = 1000;
    if (this.spellIgnoredWords.size >= MAX_IGNORED_WORDS) {
      const firstWord = this.spellIgnoredWords.values().next().value;
      this.spellIgnoredWords.delete(firstWord);
    }
    this.spellIgnoredWords.add(word.toLowerCase());
    this.saveSpellIgnoredWords();
  },

  unignoreSpellWord(word) {
    this.spellIgnoredWords.delete(word.toLowerCase());
    this.saveSpellIgnoredWords();
  },

  createDefinitionPopup() {
    this.definitionPopup = document.createElement("div");
    this.definitionPopup.className = "definition-popup";
    this.definitionPopup.setAttribute("role", "dialog");
    this.definitionPopup.setAttribute("aria-label", "Word definition");
    this.definitionPopup.hidden = true;
    document.body.appendChild(this.definitionPopup);

    this.hideDefinitionPopupHandler = (e) => {
      if (e.type === "keydown" && e.key === "Escape") {
        this.definitionPopup.hidden = true;
        return;
      }
      if (e.type === "click" && !this.definitionPopup.contains(e.target)) {
        this.definitionPopup.hidden = true;
      }
    };

    document.addEventListener("click", this.hideDefinitionPopupHandler);
    document.addEventListener("keydown", this.hideDefinitionPopupHandler);
  },

  showDefinitionPopup(word) {
    const result = getDefinition(word);
    if (!result || !result.defs || !Array.isArray(result.defs) || result.defs.length === 0) return;
    
    const definitions = result.defs;
    const isUrban = result.source === "urban";

    const fragment = document.createDocumentFragment();
    
    const header = document.createElement("div");
    header.className = "definition-popup-header";
    
    const wordSpan = document.createElement("span");
    wordSpan.className = "definition-popup-word";
    wordSpan.textContent = word;
    header.appendChild(wordSpan);
    
    if (isUrban) {
      const urbanBadge = document.createElement("span");
      urbanBadge.className = "definition-popup-urban-badge";
      urbanBadge.textContent = "Urban Dictionary";
      header.appendChild(urbanBadge);
    }
    
    const closeBtn = document.createElement("button");
    closeBtn.type = "button";
    closeBtn.className = "definition-popup-close";
    closeBtn.setAttribute("aria-label", "Close");
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 20 20");
    svg.setAttribute("fill", "currentColor");
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", "M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z");
    svg.appendChild(path);
    closeBtn.appendChild(svg);
    header.appendChild(closeBtn);
    
    fragment.appendChild(header);
    
    const content = document.createElement("div");
    content.className = "definition-popup-content";
    content.setAttribute("tabindex", "0");
    
    definitions.forEach((entry, index) => {
      const defItem = document.createElement("div");
      defItem.className = "definition-popup-item";
      
      if (entry.pos) {
        const posSpan = document.createElement("span");
        posSpan.className = "definition-popup-pos";
        posSpan.textContent = entry.pos;
        defItem.appendChild(posSpan);
      }
      
      const defText = document.createElement("span");
      defText.className = "definition-popup-def";
      defText.textContent = entry.def;
      defItem.appendChild(defText);
      
      content.appendChild(defItem);
    });
    
    fragment.appendChild(content);

    this.definitionPopup.textContent = "";
    this.definitionPopup.appendChild(fragment);

    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    this.definitionPopup.hidden = false;
    this.definitionPopup.style.visibility = "hidden";

    const popupRect = this.definitionPopup.getBoundingClientRect();
    const popupWidth = popupRect.width;
    const popupHeight = popupRect.height;

    let x = (viewportWidth - popupWidth) / 2;
    let y = (viewportHeight - popupHeight) / 2;

    this.definitionPopup.style.left = `${Math.max(16, x)}px`;
    this.definitionPopup.style.top = `${Math.max(16, y)}px`;
    this.definitionPopup.style.visibility = "visible";

    closeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      this.definitionPopup.hidden = true;
    }, { once: true });
  },

};

export default AutoResize;
